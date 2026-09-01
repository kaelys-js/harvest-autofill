import Foundation
@testable import HarvestCore
import Testing

// Drives the load()/writeAll() branches that only run with a populated configuration
// (GitHub orgs, Azure DevOps, project map, holidays) plus the secret env files.
@MainActor
@Suite(.serialized)
struct ConfigIOTests {
    let richConfig = """
    {
      "timezone": "America/Vancouver",
      "daily_target_hours": 8.0,
      "anchor_start": "9:00am",
      "work_hours": { "start": 8, "end": 18 },
      "timeline": { "gap_cap_min": 120, "lead_in_min": 30 },
      "harvest": { "user_id": 4242, "user_agent": "ua" },
      "projects": {
        "Website": { "project_id": 100, "meeting_task": 111, "dev_task": 112 },
        "Mobile App": { "project_id": 400, "meeting_task": 411, "dev_task": 412 }
      },
      "github": { "login": "gito", "orgs": ["orgA", "orgB"] },
      "azure_devops": { "enabled": true, "org": "o", "project": "p", "repos": ["r1", "r2"], "author": "a@b" },
      "holidays": { "region": "CA-ON", "dates": ["2026-12-25"] },
      "auto_record": false,
      "auto_update": true,
      "show_dock_icon": true
    }
    """

    @Test func `load reads A full configuration`() throws {
        try richConfig.write(toFile: P.config, atomically: true, encoding: .utf8)
        let p = Prefs()
        #expect(p.dailyTarget == 8.0)
        #expect(p.workStart == 8 && p.workEnd == 18)
        #expect(p.gapCap == 120 && p.leadIn == 30)
        #expect(p.ghLogin == "gito")
        #expect(p.ghOrgs == "orgA, orgB")
        #expect(p.adoEnabled && p.adoOrg == "o" && p.adoRepos == "r1, r2")
        #expect(p.holidayRegion == "CA-ON")
        #expect(p.harvestUser == "4242")
        #expect(p.projectsList.contains { $0.0 == "Website" })
        #expect(p.autoUpdate && p.showDockIcon && !p.autoRecord)
    }

    @Test func `write all persists config and secret env files`() throws {
        let p = Prefs()
        p.harvestAccount = "999"
        p.harvestToken = "htok"
        p.calUrl = "https://script.google.com/macros/s/x/exec"
        p.calSecret = "csec"
        p.adoEnabled = true
        p.adoPAT = "adopat"
        p.ghToken = "ghtok"
        p.holidayRegion = "CA-AB"
        p.writeAll()

        // config.json carries the non-secret settings
        let cfg = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: P.config))) as? [String: Any])
        let hol = try #require(cfg["holidays"] as? [String: Any])
        #expect(hol["region"] as? String == "CA-AB")

        // secrets went to their env files, not the config
        let harvestEnv = try String(contentsOfFile: P.harvestEnv, encoding: .utf8)
        #expect(harvestEnv.contains("HARVEST_ACCESS_TOKEN='htok'"))
        #expect(FileManager.default.fileExists(atPath: P.githubEnv))
        #expect(try !String(contentsOfFile: P.config, encoding: .utf8).contains("htok"))
    }

    @Test func `static readers see the persisted flags`() {
        let p = Prefs()
        p.autoUpdate = true
        p.showDockIcon = true
        p.writeAll()
        #expect(Prefs.autoUpdateEnabled())
        #expect(Prefs.dockIconEnabled())
    }
}
