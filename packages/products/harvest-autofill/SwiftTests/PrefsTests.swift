import Foundation
@testable import HarvestCore
import Testing

// Prefs owns the validation + change-tracking logic behind the Save button. These run on the
// main actor (Prefs is an ObservableObject) and against an isolated HARVEST_DATA_DIR so no
// real config is touched.
@MainActor
@Suite(.serialized)
struct PrefsTests {
    func fresh() -> Prefs {
        let p = Prefs()
        // A fully-valid, single-project, no-ADO configuration.
        p.harvestAccount = "123456"
        p.harvestToken = "pat-token"
        p.ghLogin = "someone"
        p.ghOrgs = "org1, org2"
        p.dailyTarget = 9
        p.workStart = 9
        p.workEnd = 17
        p.gapCap = 90
        p.leadIn = 45
        p.holidayRegion = "CA-BC"
        p.adoEnabled = false
        // Clear ADO fields so the test is hermetic regardless of any config left by other tests.
        p.adoOrg = ""
        p.adoProject = ""
        p.adoAuthor = ""
        p.adoPAT = ""
        p.adoRepos = ""
        return p
    }

    @Test func `a fully filled config can save`() {
        #expect(fresh().canSave)
    }

    @Test func `harvest account must be numeric`() {
        let p = fresh()
        p.harvestAccount = "abc"
        #expect(!p.accountValid)
        #expect(!p.canSave)
    }

    @Test func `empty token blocks save`() {
        let p = fresh()
        p.harvestToken = ""
        #expect(!p.tokenValid)
        #expect(!p.canSave)
    }

    @Test func `calendar url must be an apps script url when used`() {
        let p = fresh()
        p.calUrl = "https://example.com/x"
        p.calSecret = "s"
        #expect(!p.calUrlValid)
        p.calUrl = "https://script.google.com/macros/s/abc/exec"
        #expect(p.calUrlValid)
    }

    @Test func `target and work hours have bounds`() {
        let p = fresh()
        p.dailyTarget = 0
        #expect(!p.targetValid)
        p.dailyTarget = 9
        p.workEnd = 8 // end <= start
        #expect(!p.workHoursValid)
    }

    @Test func `ado requires every field when enabled`() {
        let p = fresh()
        p.adoEnabled = true
        #expect(!p.adoValid) // no ADO fields set
        p.adoOrg = "o"
        p.adoProject = "pr"
        p.adoAuthor = "a"
        p.adoPAT = "pat"
        p.adoRepos = "r1, r2"
        #expect(p.adoValid)
    }

    @Test func `unsupported region is invalid`() {
        let p = fresh()
        p.holidayRegion = "XX-YY"
        #expect(!p.regionValid)
    }

    // ---- change tracking (drives Save visibility) ----
    @Test func `no changes right after load`() {
        let p = Prefs() // load() sets savedSig from the loaded values
        #expect(!p.hasChanges)
    }

    @Test func `editing A field marks changes saving clears it`() {
        let p = Prefs()
        #expect(!p.hasChanges)
        p.ghLogin = p.ghLogin + "-edit"
        #expect(p.hasChanges)
        p.writeAll() // writeAll re-baselines savedSig
        #expect(!p.hasChanges)
    }

    @Test func `write then load round trips persisted fields`() {
        let p = Prefs()
        p.dailyTarget = 7.5
        p.workStart = 8
        p.holidayRegion = "CA-ON"
        p.ghLogin = "round-trip-user"
        p.writeAll()

        let p2 = Prefs() // reads the config just written
        #expect(p2.dailyTarget == 7.5)
        #expect(p2.workStart == 8)
        #expect(p2.holidayRegion == "CA-ON")
        #expect(p2.ghLogin == "round-trip-user")
    }
}
