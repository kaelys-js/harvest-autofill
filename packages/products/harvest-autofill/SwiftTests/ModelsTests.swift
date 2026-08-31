import Foundation
@testable import HarvestCore
import Testing

struct ModelsTests {
    // The engine writes summary.json in exactly this shape; the app decodes it.
    let json = """
    {
      "state": "dryrun",
      "week": "Aug 24–28",
      "total": 18.0,
      "daysWorked": 2,
      "days": [
        {"name": "Mon Aug 24", "total": 9.0, "note": null, "entries": [
          {"span": "9:00 AM–9:30 AM", "project": "ITC", "task": "Client Meetings", "hours": 0.5},
          {"span": "9:45 AM–6:00 PM", "project": "ITC", "task": "Development", "hours": 8.5}
        ]},
        {"name": "Wed Aug 26", "total": null, "note": "holiday · skipped", "entries": []}
      ],
      "flags": ["per-day timeline split"],
      "issues": null,
      "message": ""
    }
    """

    @Test func `decodes engine summary`() throws {
        let s = try JSONDecoder().decode(Summary.self, from: Data(json.utf8))
        #expect(s.state == "dryrun")
        #expect(s.total == 18.0)
        #expect(s.daysWorked == 2)
        #expect(s.days.count == 2)
        let mon = s.days[0]
        #expect(mon.total == 9.0)
        #expect(mon.entries.count == 2)
        #expect(mon.entries[0].project == "ITC")
        #expect(mon.entries[0].hours == 0.5)
        let holiday = s.days[1]
        #expect(holiday.total == nil)
        #expect(holiday.note == "holiday · skipped")
        #expect(holiday.entries.isEmpty)
    }

    @Test func `entry and day are identifiable`() {
        let e = Entry(span: "9–10", project: "ITC", task: "Development", hours: 1)
        let d = Day(name: "Mon", total: 1, note: nil, entries: [e])
        #expect(d.entries.first?.id != nil)
        #expect(d.id != d.id ? false : true) // stable within the instance
    }
}
