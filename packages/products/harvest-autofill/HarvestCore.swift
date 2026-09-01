import AppKit
import CryptoKit
import SwiftUI

// HarvestCore — testable logic (models, paths, Prefs, Updater, WeekModel, helpers).
// Built as a library target for the test suite; compiled together with HarvestApp.swift
// into a single module for the shipped app (see build.sh / Package.swift).

enum P {
    // Data (config + secrets + logs) is per-user under Application Support, so the app
    // itself can live in /Applications and anyone can use it. Scripts ship in the bundle.
    static let dataDir: String = {
        // Override for isolated testing / demo first-run; defaults to the real per-user path.
        if let override = ProcessInfo.processInfo.environment["HARVEST_DATA_DIR"], !override.isEmpty {
            try? FileManager.default.createDirectory(atPath: override + "/logs", withIntermediateDirectories: true)
            return override
        }
        let base = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.path)
            ?? (NSHomeDirectory() + "/Library/Application Support")
        let d = base + "/HarvestAutoFill"
        try? FileManager.default.createDirectory(atPath: d + "/logs", withIntermediateDirectories: true)
        return d
    }()

    static var res: String {
        Bundle.main.resourcePath ?? dataDir
    }

    static var summary: String {
        dataDir + "/logs/summary.json"
    }

    static var config: String {
        dataDir + "/config.json"
    }

    static var configDefault: String {
        res + "/config.default.json"
    }

    static var engine: String {
        res + "/engine.sh"
    }

    static var discover: String {
        res + "/discover.py"
    }

    static var icon: String {
        Bundle.main.path(forResource: "icon", ofType: "png") ?? (res + "/icon.png")
    }

    static var setupMarker: String {
        dataDir + "/.setup_complete"
    }

    static var harvestEnv: String {
        dataDir + "/harvest.env"
    }

    static var calEnv: String {
        dataDir + "/calendar.env"
    }

    static var adoEnv: String {
        dataDir + "/ado.env"
    }

    static var githubEnv: String {
        dataDir + "/github.env"
    }

    // Bundled, relocatable Python (so no system python3 is needed); falls back to python3 on PATH.
    static var python: String {
        let b = res + "/python/bin/python3"
        return FileManager.default.isExecutableFile(atPath: b) ? b : "python3"
    }
}

// ============================================================ Model
struct Entry: Codable, Identifiable {
    let id = UUID(); let span: String; let project: String; let task: String; let hours: Double
    enum CodingKeys: String, CodingKey { case span, project, task, hours }
}

struct Day: Codable, Identifiable {
    let id = UUID(); let name: String; let total: Double?; let note: String?; let entries: [Entry]
    enum CodingKeys: String, CodingKey { case name, total, note, entries }
}

struct Summary: Codable {
    let state: String; let week: String; let total: Double; let daysWorked: Int
    let days: [Day]; let flags: [String]; let issues: [String]?; let message: String
}

func hrs(_ v: Double) -> String {
    (v == v.rounded() ? String(Int(v)) : String(format: "%g", v)) + "h"
}

// Per-project dot colors, matched exactly to the website's WindowMockup.
func projColor(_ p: String) -> Color {
    switch p {
    case "Website": Color(red: 0.949, green: 0.463, blue: 0.165) // #f2762a
    case "Design": Color(red: 0.302, green: 0.729, blue: 0.420) // #4dba6b
    case "Mobile App": Color(red: 0.133, green: 0.686, blue: 0.627) // #22afa0
    case "Internal": Color(red: 0.420, green: 0.471, blue: 0.965) // #6b78f6
    default: .gray
    }
}

// Website palette (oklch tokens from the site's global.css, converted to sRGB) so the app
// matches the marketing site exactly.
enum Web {
    static let primary = Color(red: 0.980, green: 0.433, blue: 0.112) // --primary dark  #fa6e1d
    static let cardDark = Color(red: 0.091, green: 0.091, blue: 0.091) // --card dark      #171717
}

struct Status { let text: String; let color: Color; let symbol: String }
func statusFor(_ s: String) -> Status {
    switch s {
    case "written": Status(text: "Recorded to Harvest", color: .green, symbol: "checkmark.circle.fill")
    case "dryrun": Status(text: "This week, so far", color: Web.primary, symbol: "circle.fill")
    case "dedup": Status(text: "Already filled", color: .secondary, symbol: "info.circle.fill")
    case "fail": Status(text: "Needs a look", color: .orange, symbol: "exclamationmark.triangle.fill")
    default: Status(text: "Harvest", color: .secondary, symbol: "clock")
    }
}

// ============================================================ Auto-update (GitHub Releases + Ed25519)
let UPDATE_REPO = "kaelys-js/harvest-autofill-releases"
let UPDATE_REPO_URL = "https://github.com/kaelys-js/harvest-autofill-releases"
let WEBSITE_URL = "https://kaelys-js.github.io/harvest-autofill-releases/"
// Raw 32-byte Ed25519 public key (base64). Private key lives only on the release machine.
let UPDATE_PUBKEY_B64 = "QwrTC2P5Xh/A+Eq92spnRGHFESWTxfiX7Hqwk0waays="

struct UpdateInfo: Equatable { let build: Int; let version: String; let sha256: String; let notes: String; let zip: URL }
struct WhatsNew: Equatable { let version: String; let notes: String; let date: String; let url: String }
enum UpdaterState: Equatable { case idle, checking, upToDate, downloading, ready(UpdateInfo), failed(String) }
struct UpdErr: Error, LocalizedError { let m: String; var errorDescription: String? {
    m
} }

@MainActor final class Updater: ObservableObject {
    static let shared = Updater()
    @Published var state: UpdaterState = .idle
    @Published var readyAppPath: String?
    @Published var whatsNew: WhatsNew? // set to trigger the "What's new" window
    @Published var releases: [WhatsNew] = [] // full history shown under the newest notes
    @Published var whatsNewManual = false // opened from About (no "Continue") vs post-update
    @Published var loadingWhatsNew = false
    var timer: Timer?
    var currentBuild: Int {
        Int((Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0") ?? 0
    }

    var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }

    // On the first launch after an update, show What's New — newest release on top, history below.
    func maybeShowWhatsNew() {
        let seen = UserDefaults.standard.integer(forKey: "seenBuild")
        let cur = currentBuild
        if seen == 0 {
            UserDefaults.standard.set(cur, forKey: "seenBuild"); return
        } // fresh install: nothing to show
        if cur > seen {
            Task {
                let list = await loadReleases()
                let head = list.first { $0.version == currentVersion } ?? list.first
                if let wn = head, !wn.notes.isEmpty {
                    self.releases = list
                    self.whatsNewManual = false // post-update: show "Continue"
                    self.whatsNew = wn
                }
                UserDefaults.standard.set(cur, forKey: "seenBuild")
            }
        }
    }

    // Open What's New on demand (from the About button): newest release plus the full history.
    func showWhatsNewNow() {
        loadingWhatsNew = true
        Task {
            let list = await loadReleases()
            loadingWhatsNew = false
            self.releases = list
            self.whatsNewManual = true // browsing from About: no "Continue"
            self.whatsNew = list.first ?? WhatsNew(version: currentVersion, notes: "No release notes were found for this version.", date: "", url: UPDATE_REPO_URL)
        }
    }

    // The published releases, newest first, mapped to WhatsNew. Drops drafts.
    func loadReleases() async -> [WhatsNew] {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(UPDATE_REPO)/releases?per_page=30")!)
        req.setValue("harvest-fill-updater", forHTTPHeaderField: "User-Agent"); req.timeoutInterval = 15
        guard let (d, _) = try? await URLSession.shared.data(for: req),
              let arr = (try? JSONSerialization.jsonObject(with: d)) as? [[String: Any]] else { return [] }
        return arr.compactMap { o in
            guard (o["draft"] as? Bool) != true, let tag = o["tag_name"] as? String else { return nil }
            let ver = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            return WhatsNew(version: ver, notes: o["body"] as? String ?? "",
                            date: Self.pretty(o["published_at"] as? String ?? ""),
                            url: o["html_url"] as? String ?? UPDATE_REPO_URL)
        }
    }

    func release(forTag tag: String) async throws -> WhatsNew {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(UPDATE_REPO)/releases/tags/\(tag)")!)
        req.setValue("harvest-fill-updater", forHTTPHeaderField: "User-Agent"); req.timeoutInterval = 15
        let (d, _) = try await URLSession.shared.data(for: req)
        let o = ((try? JSONSerialization.jsonObject(with: d)) as? [String: Any]) ?? [:]
        let ver = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        return WhatsNew(version: ver, notes: o["body"] as? String ?? "",
                        date: Self.pretty(o["published_at"] as? String ?? ""),
                        url: o["html_url"] as? String ?? UPDATE_REPO_URL)
    }

    static func pretty(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        guard let d = f.date(from: iso) else { return "" }
        let out = DateFormatter(); out.dateStyle = .long; out.timeStyle = .none
        return out.string(from: d)
    }

    func fetchLatest() async throws -> UpdateInfo {
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(UPDATE_REPO)/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("harvest-fill-updater", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assets = o["assets"] as? [[String: Any]] else { throw UpdErr(m: "No updates available yet") }
        func assetURL(_ name: String) -> URL? {
            assets.first { ($0["name"] as? String) == name }
                .flatMap { ($0["browser_download_url"] as? String).flatMap(URL.init(string:)) }
        }
        guard let mURL = assetURL("manifest.json"), let sURL = assetURL("manifest.json.sig"), let zURL = assetURL("HarvestAutoFill.zip")
        else { throw UpdErr(m: "This release is missing its update files") }
        let (mData, _) = try await URLSession.shared.data(from: mURL)
        let (sData, _) = try await URLSession.shared.data(from: sURL)
        guard let pub = Data(base64Encoded: UPDATE_PUBKEY_B64),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: pub),
              let sigStr = String(data: sData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let sig = Data(base64Encoded: sigStr),
              key.isValidSignature(sig, for: mData) else { throw UpdErr(m: "This update couldn't be verified as genuine, so it wasn't installed") }
        guard let m = try? JSONSerialization.jsonObject(with: mData) as? [String: Any],
              let build = m["build"] as? Int, let version = m["version"] as? String, let sha = m["sha256"] as? String
        else { throw UpdErr(m: "The update information couldn't be read") }
        return UpdateInfo(build: build, version: version, sha256: sha.lowercased(), notes: m["notes"] as? String ?? "", zip: zURL)
    }
}

// ============================================================ Breakdown views (shared)
enum TestState: Equatable {
    case idle, testing, ok(String), fail(String)
    var isOK: Bool {
        if case .ok = self {
            return true
        }; return false
    }
}

@MainActor
final class Prefs: ObservableObject {
    @Published var dailyTarget = 9.0
    @Published var workStart = 9
    @Published var workEnd = 17
    @Published var gapCap = 90.0
    @Published var leadIn = 45.0
    @Published var ghLogin = ""
    @Published var ghOrgs = ""
    @Published var autoRecord = true
    @Published var autoUpdate = false
    @Published var showDockIcon = false
    @Published var adoEnabled = true
    @Published var adoOrg = ""
    @Published var adoProject = ""
    @Published var adoRepos = ""
    @Published var adoAuthor = ""
    @Published var holidayRegion = "CA-BC"
    @Published var harvestAccount = ""
    @Published var harvestUser = ""
    @Published var projectsInfo = ""
    // secrets (written to .env)
    @Published var harvestToken = ""
    @Published var calUrl = ""
    @Published var calSecret = ""
    @Published var adoPAT = ""
    @Published var ghToken = ""
    @Published var showGHToken = false
    @Published var status = ""
    // discovered option lists (for dropdowns) + reveal toggles
    @Published var ghOrgsAvailable: [String] = []
    @Published var adoReposAvailable: [String] = []
    @Published var projectsList: [(String, String)] = []
    @Published var showToken = false
    @Published var showSecret = false
    @Published var showPAT = false

    // ---- validation ----
    var accountValid: Bool {
        !harvestAccount.isEmpty && harvestAccount.allSatisfy(\.isNumber)
    }

    var tokenValid: Bool {
        !harvestToken.isEmpty
    }

    var calUsed: Bool {
        !calUrl.isEmpty || !calSecret.isEmpty
    }

    var calUrlValid: Bool {
        !calUsed || calUrl.hasPrefix("https://script.google.com/macros/")
    }

    var calSecretValid: Bool {
        !calUsed || !calSecret.isEmpty
    }

    var ghLoginValid: Bool {
        !ghLogin.isEmpty
    }

    var ghOrgsValid: Bool {
        !ghOrgs.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var targetValid: Bool {
        dailyTarget >= 1 && dailyTarget <= 24
    }

    var workHoursValid: Bool {
        workStart >= 0 && workEnd > workStart && workEnd <= 24
    }

    var gapValid: Bool {
        gapCap > 0 && leadIn >= 0
    }

    var regionValid: Bool {
        SUPPORTED_REGIONS.contains(holidayRegion)
    }

    var adoValid: Bool {
        !adoEnabled || (![adoOrg, adoProject, adoAuthor, adoPAT].contains(where: \.isEmpty) && !adoRepos.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var canSave: Bool {
        accountValid && tokenValid && calUrlValid && calSecretValid && ghLoginValid && ghOrgsValid && targetValid && workHoursValid && gapValid && regionValid && adoValid
    }

    // Change tracking: a signature over every persisted field, compared to the value at the
    // last load/write, so the Save button appears only when there is something to save.
    @Published var savedSig = ""
    var changeSig: String {
        ([autoRecord, autoUpdate, showDockIcon, adoEnabled].map(String.init)
            + [String(dailyTarget), String(workStart), String(workEnd), String(gapCap), String(leadIn),
               ghLogin, ghOrgs, adoOrg, adoProject, adoRepos, adoAuthor, holidayRegion,
               harvestAccount, harvestToken, calUrl, calSecret, adoPAT, ghToken]).joined(separator: "\u{1}")
    }

    var hasChanges: Bool {
        changeSig != savedSig
    }

    // Dependency self-check: the engine needs Python (bundled) + curl (system). No install required.
    var pythonReady: Bool {
        FileManager.default.isExecutableFile(atPath: P.res + "/python/bin/python3")
    }

    var curlReady: Bool {
        FileManager.default.isExecutableFile(atPath: "/usr/bin/curl")
    }

    init() {
        load()
    }

    func cfg() -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: P.config)))) as? [String: Any] ?? [:]
    }

    func envVal(_ path: String, _ key: String) -> String {
        guard let s = try? String(contentsOfFile: path, encoding: .utf8) else { return "" }
        for line in s.split(separator: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix(key + "=") else { continue }
            var v = String(t.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces)
            if let q = v.first, q == "\"" || q == "'" { // quoted -> take content between quotes (ignore trailing comment)
                v.removeFirst()
                if let end = v.firstIndex(of: q) {
                    v = String(v[v.startIndex ..< end])
                }
            } else if let hash = v.firstIndex(of: "#") { // unquoted -> strip inline comment
                v = String(v[v.startIndex ..< hash]).trimmingCharacters(in: .whitespaces)
            }
            return v
        }
        return ""
    }

    func load() {
        let c = cfg()
        autoRecord = c["auto_record"] as? Bool ?? true
        autoUpdate = c["auto_update"] as? Bool ?? false
        showDockIcon = c["show_dock_icon"] as? Bool ?? false
        dailyTarget = c["daily_target_hours"] as? Double ?? 9.0
        if let w = c["work_hours"] as? [String: Any] {
            workStart = w["start"] as? Int ?? 9; workEnd = w["end"] as? Int ?? 17
        }
        if let t = c["timeline"] as? [String: Any] {
            gapCap = (t["gap_cap_min"] as? NSNumber)?.doubleValue ?? 90; leadIn = (t["lead_in_min"] as? NSNumber)?.doubleValue ?? 45
        }
        if let g = c["github"] as? [String: Any] {
            ghLogin = g["login"] as? String ?? ""; ghOrgs = (g["orgs"] as? [String] ?? []).joined(separator: ", ")
        }
        if let a = c["azure_devops"] as? [String: Any] {
            adoEnabled = a["enabled"] as? Bool ?? true; adoOrg = a["org"] as? String ?? ""
            adoProject = a["project"] as? String ?? ""; adoRepos = (a["repos"] as? [String] ?? []).joined(separator: ", ")
            adoAuthor = a["author"] as? String ?? ""
        }
        if let h = c["holidays"] as? [String: Any] {
            holidayRegion = h["region"] as? String ?? "CA-BC"
        }
        if let hv = c["harvest"] as? [String: Any] {
            harvestUser = String(describing: hv["user_id"] ?? "")
        }
        if let projs = c["projects"] as? [String: Any] {
            projectsList = projs.compactMap { k, v in (v as? [String: Any]).map { (k, String(describing: $0["project_id"] ?? "")) } }.sorted { $0.0 < $1.0 }
        }
        harvestAccount = envVal(P.harvestEnv, "HARVEST_ACCOUNT_ID")
        harvestToken = envVal(P.harvestEnv, "HARVEST_ACCESS_TOKEN")
        calUrl = envVal(P.calEnv, "APPS_SCRIPT_URL")
        calSecret = envVal(P.calEnv, "APPS_SCRIPT_SECRET")
        adoPAT = envVal(P.adoEnv, "ADO_PAT")
        ghToken = envVal(P.githubEnv, "GITHUB_TOKEN")
        savedSig = changeSig
    }

    func writeEnv(_ path: String, _ kv: [(String, String)]) {
        let body = kv.map { "\($0.0)='\($0.1)'" }.joined(separator: "\n") + "\n"
        try? body.write(toFile: path, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    }

    // writeAll writes config + env files but does NOT mark setup complete — so the
    // onboarding preview can save-then-dry-run without prematurely finishing first-run.
    func writeAll() {
        var c = cfg()
        c["auto_record"] = autoRecord
        c["auto_update"] = autoUpdate
        c["show_dock_icon"] = showDockIcon
        c["daily_target_hours"] = dailyTarget
        c["work_hours"] = ["start": workStart, "end": workEnd]
        c["timeline"] = ["gap_cap_min": gapCap, "lead_in_min": leadIn]
        var g = c["github"] as? [String: Any] ?? [:]
        g["login"] = ghLogin; g["orgs"] = ghOrgs.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        c["github"] = g
        var a = c["azure_devops"] as? [String: Any] ?? [:]
        a["enabled"] = adoEnabled; a["org"] = adoOrg; a["project"] = adoProject
        a["repos"] = adoRepos.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }; a["author"] = adoAuthor
        c["azure_devops"] = a
        var h = c["holidays"] as? [String: Any] ?? [:]; h["region"] = holidayRegion; c["holidays"] = h
        if let d = try? JSONSerialization.data(withJSONObject: c, options: [.prettyPrinted]) {
            try? d.write(to: URL(fileURLWithPath: P.config))
        }
        writeEnv(P.harvestEnv, [("HARVEST_ACCOUNT_ID", harvestAccount), ("HARVEST_ACCESS_TOKEN", harvestToken),
                                ("HARVEST_PROJECT_MAP", "{}")])
        writeEnv(P.calEnv, [("APPS_SCRIPT_URL", calUrl), ("APPS_SCRIPT_SECRET", calSecret)])
        if !adoPAT.isEmpty {
            writeEnv(P.adoEnv, [("ADO_PAT", adoPAT)])
        }
        if !ghToken.isEmpty {
            writeEnv(P.githubEnv, [("GITHUB_TOKEN", ghToken)])
        } else {
            try? FileManager.default.removeItem(atPath: P.githubEnv)
        }
        savedSig = changeSig
    }

    static func autoUpdateEnabled() -> Bool {
        guard let d = try? Data(contentsOf: URL(fileURLWithPath: P.config)),
              let c = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return false }
        return c["auto_update"] as? Bool ?? false
    }

    // Read at launch (before any Prefs instance exists) to set the Dock activation policy.
    static func dockIconEnabled() -> Bool {
        guard let d = try? Data(contentsOf: URL(fileURLWithPath: P.config)),
              let c = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return false }
        return c["show_dock_icon"] as? Bool ?? false
    }

    func markComplete() {
        FileManager.default.createFile(atPath: P.setupMarker, contents: Data())
    }

    // Destructive: wipe config + all secret env files + the setup marker, then re-seed a blank
    // template so the engine still has a config. Returns the app to first-run onboarding.

    // ---- launchd agents: Friday auto-write + launch-at-login, per-user, self-installing ----
    // Stable bundle-scoped labels so re-running is idempotent (bootout then bootstrap).
    static let weeklyLabel = "studio.harvestfill.weekly"
    static let loginLabel = "studio.harvestfill.menubar"

    // Install the login-launch agent always; the Friday agent only when auto-record is on.

    // ---- live connection test (onboarding: verify before advancing) ----
    @Published var harvestTest: TestState = .idle
    func testHarvest() {
        guard accountValid, tokenValid else { harvestTest = .fail("Enter your account ID and token first"); return }
        harvestTest = .testing
        Task.detached { [acct = harvestAccount, tok = harvestToken] in
            var req = URLRequest(url: URL(string: "https://api.harvestapp.com/v2/users/me")!)
            req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization")
            req.setValue(acct, forHTTPHeaderField: "Harvest-Account-Id")
            req.setValue("harvest-fill-onboarding", forHTTPHeaderField: "User-Agent")
            req.timeoutInterval = 20
            var result: TestState
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if code == 200, let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let name = ["first_name", "last_name"].compactMap { o[$0] as? String }.joined(separator: " ")
                    let email = o["email"] as? String ?? ""
                    result = .ok(name.isEmpty ? email : "\(name) · \(email)")
                } else if code == 401 || code == 403 {
                    result = .fail("Harvest rejected these credentials (HTTP \(code)) — check the token and account ID")
                } else {
                    result = .fail(code == 0 ? "Couldn't reach Harvest — check your connection" : "Harvest returned HTTP \(code)")
                }
            } catch { result = .fail(error.localizedDescription) }
            await MainActor.run { self.harvestTest = result }
        }
    }

    // ---- live Google-Calendar test: hit the deployed Apps Script and confirm it returns events ----
    @Published var calTest: TestState = .idle
    func testCalendar() {
        guard !calUrl.isEmpty, !calSecret.isEmpty else { calTest = .fail("Enter the web-app URL and secret first"); return }
        guard calUrl.hasPrefix("https://script.google.com/macros/") else { calTest = .fail("That doesn't look like an Apps Script /exec URL"); return }
        calTest = .testing
        Task.detached { [url = calUrl, secret = calSecret] in
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            let end = Date(); let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
            var comps = URLComponents(string: url)
            comps?.queryItems = [.init(name: "secret", value: secret),
                                 .init(name: "action", value: "events"), // richer scripts require it; the simple one ignores it
                                 .init(name: "start", value: fmt.string(from: start)),
                                 .init(name: "end", value: fmt.string(from: end))]
            var result: TestState = .fail("Couldn't build the request")
            if let u = comps?.url {
                do {
                    var req = URLRequest(url: u); req.timeoutInterval = 25
                    let (data, resp) = try await URLSession.shared.data(for: req)
                    let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    if let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let events = o["events"] as? [Any] {
                            result = .ok("Connected — \(events.count) event\(events.count == 1 ? "" : "s") in the last 7 days")
                        } else if (o["error"] as? String) == "unauthorized" {
                            result = .fail("Reached the script, but the secret doesn't match its APPS_SCRIPT_SECRET")
                        } else {
                            result = .fail("Reached the script, but it didn't return an events list")
                        }
                    } else {
                        result = .fail(code == 0 ? "Couldn't reach that URL — check it's the deployed /exec URL"
                            : "That URL didn't return JSON (HTTP \(code)) — redeploy as a Web app with access: Anyone")
                    }
                } catch { result = .fail(error.localizedDescription) }
            }
            await MainActor.run { self.calTest = result }
        }
    }

    // ---- live dry-run preview (onboarding finish: show value before commit) ----
    @Published var preview: Summary?
    @Published var previewing = false

    @Published var logging = false

    @Published var discovering = false
    @Published var discovered = false
}

let SUPPORTED_REGIONS = ["CA-BC", "CA-ON", "CA-AB", "CA-QC", "US-Federal"]
func regionName(_ c: String) -> String {
    switch c {
    case "CA-BC": "British Columbia, Canada"
    case "CA-ON": "Ontario, Canada"
    case "CA-AB": "Alberta, Canada"
    case "CA-QC": "Québec, Canada"
    case "US-Federal": "United States (Federal)"
    default: c
    }
}

// macOS 26 Liquid Glass with a material fallback, so surfaces read as modern glass on this Mac.
let doGetCode = """
function doGet(e) {
  var need = PropertiesService.getScriptProperties()
    .getProperty('APPS_SCRIPT_SECRET');
  if (!e || !e.parameter || e.parameter.secret !== need)
    return ContentService
      .createTextOutput(JSON.stringify({ error: 'unauthorized' }))
      .setMimeType(ContentService.MimeType.JSON);
  var cal = CalendarApp.getDefaultCalendar();
  var events = cal
    .getEvents(new Date(e.parameter.start), new Date(e.parameter.end))
    .map(function (ev) {
      return {
        title:  ev.getTitle(),
        start:  ev.getStartTime().toISOString(),
        end:    ev.getEndTime().toISOString(),
        allDay: ev.isAllDayEvent(),
        status: String(ev.getMyStatus()),
        guests: ev.getGuestList().length
      };
    });
  return ContentService
    .createTextOutput(JSON.stringify({ events: events }))
    .setMimeType(ContentService.MimeType.JSON);
}
"""

// Lightweight JS syntax highlighter (keywords / strings / comments / numbers) for the setup snippet.
func highlightJS(_ src: String) -> AttributedString {
    let keywords: Set = ["function", "var", "let", "const", "return", "if", "else", "for", "while", "new", "typeof", "true", "false", "null"]
    let kw = Color(red: 0.79, green: 0.20, blue: 0.55)
    let str = Color(red: 0.80, green: 0.28, blue: 0.22)
    let com = Color.secondary
    let num = Color(red: 0.20, green: 0.42, blue: 0.86)
    var out = AttributedString("")
    func emit(_ s: String, _ c: Color?) {
        var a = AttributedString(s); if let c {
            a.foregroundColor = c
        }; out += a
    }
    func ident(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber || ch == "_" || ch == "$"
    }
    let ch = Array(src); var i = 0
    while i < ch.count {
        let c = ch[i]
        if c == "/", i + 1 < ch.count, ch[i + 1] == "/" {
            var j = i; while j < ch.count, ch[j] != "\n" {
                j += 1
            }
            emit(String(ch[i ..< j]), com); i = j
        } else if c == "'" || c == "\"" {
            let q = c; var j = i + 1; while j < ch.count, ch[j] != q {
                j += 1
            }; j = min(j + 1, ch.count)
            emit(String(ch[i ..< j]), str); i = j
        } else if c.isNumber {
            var j = i; while j < ch.count, ch[j].isNumber || ch[j] == "." {
                j += 1
            }
            emit(String(ch[i ..< j]), num); i = j
        } else if ident(c) {
            var j = i; while j < ch.count, ident(ch[j]) {
                j += 1
            }
            let w = String(ch[i ..< j]); emit(w, keywords.contains(w) ? kw : nil); i = j
        } else {
            emit(String(c), nil); i += 1
        }
    }
    return out
}

func inlineMD(_ s: String) -> AttributedString {
    (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
}

// Renders release notes as a tidy changelog: headings, bullets, and inline emphasis/links.
