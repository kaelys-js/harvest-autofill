import Foundation
@testable import HarvestCore
import Testing

// Intercepts URLSession.shared so the network methods (release fetch, credential tests) can be
// exercised against canned responses.
final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var routes: [(String, Int, Data)] = []

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let url = request.url?.absoluteString ?? ""
        let (status, data) = MockURLProtocol.routes.first { url.contains($0.0) }.map { ($0.1, $0.2) } ?? (404, Data())
        let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func set(_ routes: [(String, Int, Any)]) {
        Self.routes = routes.map { ($0.0, $0.1, ($0.2 as? String)?.data(using: .utf8) ?? (try! JSONSerialization.data(withJSONObject: $0.2))) }
    }
}

@MainActor
@Suite(.serialized)
struct NetworkTests {
    init() {
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    func poll(_ get: @escaping () -> TestState) async -> TestState {
        for _ in 0 ..< 100 {
            let s = get()
            if case .ok = s {
                return s
            }
            if case .fail = s {
                return s
            }
            try? await Task.sleep(nanoseconds: 15_000_000)
        }
        return get()
    }

    @Test func `load releases maps the release list`() async {
        MockURLProtocol.set([(
            "/releases?per_page",
            200,
            [
                ["tag_name": "v2.17", "body": "Newest", "published_at": "2026-08-31T00:00:00Z", "html_url": "u1"],
                ["tag_name": "v2.16", "body": "Older", "published_at": "2026-08-30T00:00:00Z", "html_url": "u2"],
                ["tag_name": "v2.15", "draft": true, "body": "Draft"], // dropped
            ] as [[String: Any]],
        )])
        let out = await Updater.shared.loadReleases()
        #expect(out.map(\.version) == ["2.17", "2.16"]) // draft excluded, newest first
        #expect(out.first?.notes == "Newest")
    }

    @Test func `release for tag maps one release`() async throws {
        MockURLProtocol.set([(
            "/releases/tags/v2.17",
            200,
            ["tag_name": "v2.17", "body": "Notes here", "published_at": "2026-08-31T00:00:00Z", "html_url": "u"] as [String: Any],
        )])
        let wn = try await Updater.shared.release(forTag: "v2.17")
        #expect(wn.version == "2.17")
        #expect(wn.notes == "Notes here")
        #expect(wn.date.contains("2026"))
    }

    @Test func `show whats new now populates history from the list`() async {
        MockURLProtocol.set([(
            "/releases?per_page",
            200,
            [["tag_name": "v2.17", "body": "x", "published_at": "2026-08-31T00:00:00Z", "html_url": "u"]] as [[String: Any]],
        )])
        Updater.shared.showWhatsNewNow()
        for _ in 0 ..< 100 where Updater.shared.releases.isEmpty {
            try? await Task.sleep(nanoseconds: 15_000_000)
        }
        #expect(Updater.shared.whatsNewManual) // opened from About
        #expect(Updater.shared.releases.first?.version == "2.17")
    }

    @Test func `maybe show whats new pops after A build bump`() async {
        MockURLProtocol.set([(
            "/releases?per_page",
            200,
            [["tag_name": "v9.9", "body": "notes", "published_at": "2026-08-31T00:00:00Z", "html_url": "u"]] as [[String: Any]],
        )])
        // Pretend we last saw an older build so the post-update popup should fire.
        UserDefaults.standard.set(Updater.shared.currentBuild - 1, forKey: "seenBuild")
        Updater.shared.whatsNew = nil
        Updater.shared.maybeShowWhatsNew()
        for _ in 0 ..< 100 where Updater.shared.whatsNew == nil {
            try? await Task.sleep(nanoseconds: 15_000_000)
        }
        #expect(!Updater.shared.whatsNewManual) // post-update: shows "Continue"
    }

    @Test func `harvest succeeds with valid credentials`() async {
        let p = Prefs()
        p.harvestAccount = "12345"
        p.harvestToken = "tok"
        MockURLProtocol.set([("/users/me", 200, ["first_name": "Test", "last_name": "User", "email": "t@e.com"] as [String: Any])])
        p.testHarvest()
        let s = await poll { p.harvestTest }
        if case let .ok(msg) = s {
            #expect(msg.contains("Test User"))
        } else {
            Issue.record("expected .ok, got \(s)")
        }
    }

    @Test func `harvest reports rejected credentials`() async {
        let p = Prefs()
        p.harvestAccount = "12345"
        p.harvestToken = "bad"
        MockURLProtocol.set([("/users/me", 401, ["error": "nope"] as [String: Any])])
        p.testHarvest()
        let s = await poll { p.harvestTest }
        if case let .fail(msg) = s {
            #expect(msg.contains("rejected"))
        } else {
            Issue.record("expected .fail, got \(s)")
        }
    }

    @Test func `calendar succeeds when the script returns events`() async {
        let p = Prefs()
        p.calUrl = "https://script.google.com/macros/s/abc/exec"
        p.calSecret = "secret"
        MockURLProtocol.set([("script.google.com", 200, ["events": [["title": "x"]]] as [String: Any])])
        p.testCalendar()
        let s = await poll { p.calTest }
        if case let .ok(msg) = s {
            #expect(msg.contains("1 event"))
        } else {
            Issue.record("expected .ok, got \(s)")
        }
    }

    @Test func `calendar rejects A bad secret`() async {
        let p = Prefs()
        p.calUrl = "https://script.google.com/macros/s/abc/exec"
        p.calSecret = "wrong"
        MockURLProtocol.set([("script.google.com", 200, ["error": "unauthorized"] as [String: Any])])
        p.testCalendar()
        let s = await poll { p.calTest }
        if case let .fail(msg) = s {
            #expect(msg.contains("secret"))
        } else {
            Issue.record("expected .fail, got \(s)")
        }
    }
}
