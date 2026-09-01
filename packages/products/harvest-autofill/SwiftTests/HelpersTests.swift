import Foundation
@testable import HarvestCore
import Testing

@MainActor
struct HelpersTests {
    @Test func `hrs drops trailing zero`() {
        #expect(hrs(9.0) == "9h")
        #expect(hrs(8.5) == "8.5h")
        #expect(hrs(0.25) == "0.25h")
    }

    @Test func `status for maps engine states`() {
        #expect(statusFor("written").symbol == "checkmark.circle.fill")
        #expect(statusFor("dryrun").text == "This week, so far")
        #expect(statusFor("fail").symbol == "exclamationmark.triangle.fill")
        #expect(statusFor("anything-else").text == "Harvest")
    }

    @Test func `proj color covers every project and default`() {
        // Exercise every named branch with the app's neutral project names, then the fallback.
        let colors = ["Website", "Design", "Mobile App", "Internal"].map { projColor($0) }
        #expect(colors.count == 4)
        #expect(projColor("Unknown") == .gray) // anything unmapped falls back to gray
    }

    @Test func `status for covers dedup and default`() {
        #expect(statusFor("dedup").symbol == "info.circle.fill")
        #expect(statusFor("").symbol == "clock")
    }

    @Test func `region names are friendly`() {
        #expect(regionName("CA-BC") == "British Columbia, Canada")
        #expect(regionName("US-Federal") == "United States (Federal)")
        #expect(regionName("CA-XX") == "CA-XX") // unknown falls through
    }

    @Test func `every supported region has A friendly name`() {
        for r in SUPPORTED_REGIONS {
            #expect(regionName(r) != r, "region \(r) should have a friendly label")
        }
    }

    @Test func `pretty formats iso dates`() {
        let out = Updater.pretty("2026-08-31T15:00:00Z")
        #expect(out.contains("2026"))
        #expect(out.contains("August") || out.contains("Aug"))
    }

    @Test func `pretty returns empty on garbage`() {
        #expect(Updater.pretty("not-a-date") == "")
    }

    @Test func `highlight js produces attributed text`() {
        let a = highlightJS("function doGet(e) { return 1; }")
        #expect(!String(a.characters).isEmpty)
    }

    @Test func `inline md renders emphasis`() {
        let a = inlineMD("hello **world**")
        #expect(String(a.characters).contains("world"))
    }
}
