import AppKit
import CryptoKit
import SwiftUI

// HarvestApp — SwiftUI views, the app delegate, and the @main entry point.
// Logic lives in HarvestCore.swift (same module in the app build).

struct EntryRow: View {
    let e: Entry
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(projColor(e.project)).frame(width: 7, height: 7)
            Text(e.span).font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                .frame(width: 168, alignment: .leading)
            Text(e.project).font(.system(size: 12, weight: .medium))
            Text(e.task).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 8)
            Text(hrs(e.hours)).font(.system(size: 12, weight: .semibold).monospacedDigit())
        }.padding(.vertical, 2)
    }
}

struct DayBlock: View {
    let day: Day
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(day.name).font(.system(size: 12.5, weight: .semibold))
                // Today, mid-week, is shown at its full daily target rather than the hours logged
                // so far — this tag says so. It's recalculated on every refresh up to the Friday post.
                if day.projected == true {
                    Text("projected")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Web.primary)
                        .padding(.horizontal, 6).padding(.vertical, 1.5)
                        .background(Capsule().fill(Web.primary.opacity(0.12)))
                }
                Spacer()
                if let t = day.total {
                    Text(hrs(t)).font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            if let note = day.note {
                Text(note).font(.system(size: 12)).foregroundStyle(.tertiary).padding(.leading, 2)
            } else {
                ForEach(day.entries) { EntryRow(e: $0) }
            }
        }.padding(.vertical, 9)
    }
}

struct IssueRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.system(size: 12))
            Text(text).font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

struct MainWindow: View {
    @ObservedObject var model: WeekModel
    var render = false
    var s: Summary? {
        model.summary
    }

    var issues: [String] {
        s?.issues ?? []
    }

    var body: some View {
        let st = statusFor(s?.state ?? "")
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                if let img = NSImage(contentsOfFile: P.icon) {
                    Image(nsImage: img).resizable().frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        // The mockup marks the "this week" status with an 8px dot (size-2); other
                        // states keep their SF Symbol (check / warning / clock).
                        if st.symbol == "circle.fill" {
                            Circle().fill(st.color).frame(width: 8, height: 8)
                        } else {
                            Image(systemName: st.symbol).foregroundStyle(st.color).font(.system(size: 13))
                        }
                        Text(st.text).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(st.color)
                    }
                    Text(s.map(\.detailLine) ?? "No data yet — refreshing…")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                if model.refreshing {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 14)
            Divider()

            if let s, !s.days.isEmpty {
                let list = VStack(spacing: 0) {
                    ForEach(Array(s.days.enumerated()), id: \.offset) { i, day in
                        DayBlock(day: day)
                        if i < s.days.count - 1 {
                            Divider().opacity(0.5)
                        }
                    }
                }.padding(.horizontal, 18).padding(.vertical, 4)
                if render {
                    list
                } else {
                    ScrollView { list }.frame(maxHeight: 680)
                }
            } else {
                Text("Run a preview to see this week.").font(.system(size: 13)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
            }

            if !issues.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 5) {
                    Text("Needs your attention").font(.system(size: 11, weight: .semibold)).foregroundStyle(.orange).textCase(.uppercase)
                    ForEach(issues, id: \.self) { IssueRow(text: $0) }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 18).padding(.vertical, 10)
            }

            Divider()
            HStack(spacing: 10) {
                // Auto-refreshes every 15 minutes; the mockup's footer line replaces the manual Refresh.
                Text("Logs to Harvest every Friday").font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                HelpIcon(text: "Logs this week to Harvest now, without waiting for the automatic Friday run. Safe to click twice — days already on your timesheet are skipped.")
                Button { model.logNow() } label: { Text("Log this week") }
                    .primaryProminent().controlSize(.large).disabled(model.refreshing)
            }.padding(.horizontal, 18).padding(.vertical, 14)
        }
        .frame(width: 470)
        // Solid site card colour in both render and the running app, matching the mockup.
        .background(Web.card)
    }
}

let LBL: CGFloat = 190
extension View {
    // Frosted content card: legible over the window's material, modern layered depth.
    // (True Liquid Glass is reserved for floating controls — see primaryProminent — per HIG.)
    func glassBG(_ radius: CGFloat = 12, render: Bool = false) -> some View {
        // In a static ImageRenderer capture, `.thinMaterial` rasterizes approximately and
        // OS-version-dependently, so a screenshot of it drifts between the machine that generated
        // the baseline and the CI runner. Fall back to the solid `Web.section` surface in render
        // mode so the baseline is deterministic; the running app still gets the frosted material.
        background(
            render ? AnyShapeStyle(Web.section) : AnyShapeStyle(.thinMaterial),
            in: RoundedRectangle(cornerRadius: radius, style: .continuous),
        )
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.primary.opacity(0.06)))
    }

    func primaryProminent() -> some View {
        buttonStyle(MockupPrimaryStyle())
    }
}

// The site's primary button: solid --primary fill, --primary-foreground text, --radius-md
// corners (circular, matching CSS border-radius, not a squircle). Replaces the system-accent
// glass/bordered style so every primary button matches the marketing mockup exactly.
struct MockupPrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Styled(configuration: configuration)
    }

    // Nested so it can read the environment's isEnabled and dim a disabled button — a bare
    // ButtonStyle can't, which previously left disabled primary buttons looking active.
    struct Styled: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Web.primaryForeground)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 8.4).fill(Web.primary))
                .contentShape(RoundedRectangle(cornerRadius: 8.4))
                .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
        }
    }
}

struct CodeBox: View {
    let code: String
    @State private var copied = false
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(highlightJS(code)).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                    .padding(12).padding(.trailing, 46)
            }
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.25)))
            Button {
                NSPasteboard.general.clearContents(); NSPasteboard.general.setString(code, forType: .string); copied = true
            } label: { Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc").font(.system(size: 10)) }
                .buttonStyle(.borderless).padding(8)
        }
    }
}

struct Step: View {
    let n: Int; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(n)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                .frame(width: 17, height: 17).background(Circle().fill(Web.primary))
            Text(text).font(.system(size: 11.5)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

struct TestStatusView: View {
    let state: TestState
    var body: some View {
        switch state {
        case .idle: EmptyView()
        case .testing: HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…").font(.system(size: 12)).foregroundStyle(.secondary) }
        case let .ok(m): Label(m, systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(.green).fixedSize(horizontal: false, vertical: true)
        case let .fail(m): Label(m, systemImage: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct CalendarTestRow: View {
    @ObservedObject var prefs: Prefs
    var body: some View {
        HStack(spacing: 12) {
            Button { prefs.testCalendar() } label: { Label("Test connection", systemImage: "bolt.horizontal.circle") }
                .disabled(prefs.calUrl.isEmpty || prefs.calSecret.isEmpty || prefs.calTest == .testing)
            TestStatusView(state: prefs.calTest)
            Spacer(minLength: 0)
        }
    }
}

struct CalendarHelp: View {
    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Step(n: 1, text: CALENDAR_SETUP_STEPS[0])
                Step(n: 2, text: CALENDAR_SETUP_STEPS[1])
                CodeBox(code: doGetCode)
                Step(n: 3, text: CALENDAR_SETUP_STEPS[2])
                Step(n: 4, text: CALENDAR_SETUP_STEPS[3])
                Step(n: 5, text: CALENDAR_SETUP_STEPS[4])
                Text("The script runs as your own Google account, so there's no OAuth to configure. Your calendar stays private — the tool reads only each event's time, title, and your RSVP.")
                    .font(.system(size: 10.5)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
            }.padding(.top, 8)
        } label: { Label("How to connect Google Calendar — step by step", systemImage: "questionmark.circle").font(.system(size: 11.5)) }
    }
}

func invalidBorder(_ valid: Bool) -> some View {
    RoundedRectangle(cornerRadius: 6).stroke(valid ? Color.clear : Color.red.opacity(0.75), lineWidth: 1)
}

// Trailing status: green check when the field is valid AND filled, red ! when invalid,
// reserved blank space otherwise so rows don't shift.
struct ValidMark: View {
    let valid: Bool; let filled: Bool
    var body: some View {
        Group {
            if !valid {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
            } else if filled {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Color.clear
            }
        }.font(.system(size: 12)).frame(width: 14, height: 14)
    }
}

// A small "?" that reveals its explanation in a popover on click (SwiftUI's `.help()` hover
// tooltip is unreliable on macOS, so click is the primary affordance; `.help()` stays as a
// hover bonus where it works). Keeps the form uncluttered instead of a line of grey text per row.
struct HelpIcon: View {
    let text: String
    @State private var show = false
    var body: some View {
        Button { show.toggle() } label: {
            Image(systemName: "questionmark.circle").font(.system(size: 12)).foregroundStyle(.tertiary)
        }
        .buttonStyle(.borderless)
        .help(text)
        .popover(isPresented: $show, arrowEdge: .bottom) {
            Text(text)
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 260)
                .padding(12)
        }
    }
}

struct Field: View {
    let label: String; @Binding var text: String; var hint = ""; var valid = true; var help = ""
    var body: some View {
        HStack(spacing: 8) {
            Text(label).frame(width: LBL, alignment: .leading).font(.system(size: 12))
            TextField(hint, text: $text).textFieldStyle(.roundedBorder).overlay(invalidBorder(valid))
            ValidMark(valid: valid, filled: !text.isEmpty)
            if !help.isEmpty {
                HelpIcon(text: help)
            }
        }
    }
}

struct Secret: View {
    let label: String; @Binding var text: String; @Binding var reveal: Bool; var valid = true; var help = ""
    var body: some View {
        HStack(spacing: 8) {
            Text(label).frame(width: LBL, alignment: .leading).font(.system(size: 12))
            Group {
                if reveal {
                    TextField("", text: $text)
                } else {
                    SecureField("", text: $text)
                }
            }
            .textFieldStyle(.roundedBorder).overlay(invalidBorder(valid))
            Button { reveal.toggle() } label: { Image(systemName: reveal ? "eye.slash" : "eye") }
                .buttonStyle(.borderless).help(reveal ? "Hide" : "Reveal")
            ValidMark(valid: valid, filled: !text.isEmpty)
            if !help.isEmpty {
                HelpIcon(text: help)
            }
        }
    }
}

struct MultiSelect: View {
    let label: String; let options: [String]; @Binding var csv: String; var valid = true; var help = ""
    var selected: Set<String> {
        Set(csv.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    func toggle(_ o: String) {
        var s = selected; if s.contains(o) {
            s.remove(o)
        } else {
            s.insert(o)
        }; csv = s.sorted().joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label).frame(width: LBL, alignment: .leading).font(.system(size: 12))
            Menu {
                if options.isEmpty {
                    Text("Loading from your accounts…").disabled(true)
                }
                ForEach(options, id: \.self) { o in
                    Toggle(o, isOn: Binding(get: { selected.contains(o) }, set: { _ in toggle(o) }))
                }
            } label: { Text(csv.isEmpty ? "None selected" : csv).lineLimit(1) }
                .frame(maxWidth: .infinity, alignment: .leading).overlay(invalidBorder(valid))
            ValidMark(valid: valid, filled: !csv.isEmpty)
            if !help.isEmpty {
                HelpIcon(text: help)
            }
        }
    }
}

struct SingleSelect: View {
    let label: String; let options: [String]; @Binding var value: String
    var placeholder = "Select"; var valid = true; var help = ""
    var body: some View {
        HStack(spacing: 8) {
            Text(label).frame(width: LBL, alignment: .leading).font(.system(size: 12))
            Menu {
                ForEach(options, id: \.self) { o in Button(o) { value = o } }
            } label: { Text(value.isEmpty ? placeholder : value).lineLimit(1) }
                .frame(maxWidth: .infinity, alignment: .leading).overlay(invalidBorder(valid))
            ValidMark(valid: valid, filled: !value.isEmpty)
            if !help.isEmpty {
                HelpIcon(text: help)
            }
        }
    }
}

struct NumRow: View {
    let label: String; @Binding var value: Double; var width: CGFloat = 60; var valid = true; var trailing = ""; var help = ""
    var body: some View {
        HStack(spacing: 8) {
            Text(label).frame(width: LBL, alignment: .leading).font(.system(size: 12))
            TextField("", value: $value, format: .number).frame(width: width).textFieldStyle(.roundedBorder).overlay(invalidBorder(valid))
            if !trailing.isEmpty {
                Text(trailing).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ValidMark(valid: valid, filled: true)
            if !help.isEmpty {
                HelpIcon(text: help)
            }
            Spacer()
        }
    }
}

// One end of a work-hours range: an hour field plus a :00 / :30 minute picker, bound to a single
// Double (e.g. 9.5). The picker constrains minutes to half-hour boundaries; the hour field takes
// the whole-hour part and keeps the current minute.
struct HourMinutePicker: View {
    @Binding var value: Double
    var valid = true
    private var hour: Binding<Int> {
        Binding(get: { Int(value.rounded(.down)) },
                set: { value = Double($0) + (value - value.rounded(.down)) })
    }

    private var minutes: Binding<Int> {
        Binding(get: { value - value.rounded(.down) >= 0.5 ? 30 : 0 },
                set: { value = value.rounded(.down) + ($0 == 30 ? 0.5 : 0) })
    }

    var body: some View {
        HStack(spacing: 4) {
            TextField("", value: hour, format: .number)
                .frame(width: 38).textFieldStyle(.roundedBorder).overlay(invalidBorder(valid))
            Picker("", selection: minutes) {
                Text(":00").tag(0)
                Text(":30").tag(30)
            }.labelsHidden().frame(width: 58)
        }
    }
}

struct PrefCard<C: View>: View {
    let title: String; @ViewBuilder let content: () -> C
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        // Solid raised surface + hairline border, so sections read clearly against the card window
        // (the old .thinMaterial went nearly invisible over the now-solid background).
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Web.section))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.07)))
    }
}

struct AccountsContent: View {
    @ObservedObject var prefs: Prefs
    var body: some View {
        VStack(spacing: 14) {
            Text("Connect the accounts the app reads from. Only Harvest is required — the others are optional and add more of your week automatically.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            PrefCard(title: "Harvest") {
                Text("Where your hours are written — the only account the app needs.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Field(label: "Account ID", text: $prefs.harvestAccount, hint: "e.g. 123456", valid: prefs.accountValid,
                      help: "The number in your Harvest web address — id.getharvest.com shows it under Settings.")
                Secret(label: "Access token", text: $prefs.harvestToken, reveal: $prefs.showToken, valid: prefs.tokenValid,
                       help: HARVEST_TOKEN_HELP)
                HStack { Text("User ID").frame(width: LBL, alignment: .leading).font(.system(size: 12))
                    Text(prefs.harvestUser.isEmpty ? "—" : prefs.harvestUser).font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer(); Button { prefs.discover() } label: { Label("Scan my accounts", systemImage: "sparkles") }
                }
                Text("This reads your connected accounts and fills in your user ID, projects, orgs, and repos automatically — so you never type an ID by hand.")
                    .font(.system(size: 10.5)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
                if !prefs.projectsList.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Projects mapped").font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.secondary).padding(.top, 3)
                        ForEach(prefs.projectsList, id: \.0) { name, id in
                            HStack { Text(name).font(.system(size: 11)).lineLimit(1)
                                Spacer(); Text(id).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            PrefCard(title: "Calendar — Google") {
                Text("Optional. Adds your meetings as hours. The step-by-step below sets up the small script that shares them.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Field(label: "Web-app URL", text: $prefs.calUrl, hint: "https://script.google.com/macros/s/…/exec", valid: prefs.calUrlValid,
                      help: "The web-app link the setup script gives you (it ends in /exec).")
                Secret(label: "Shared secret", text: $prefs.calSecret, reveal: $prefs.showSecret, valid: prefs.calSecretValid,
                       help: "The secret word you chose during the setup, so only this app can read your calendar.")
                CalendarTestRow(prefs: prefs)
                CalendarHelp()
            }
            PrefCard(title: "GitHub") {
                Text("Optional but recommended. Turns your commits into development hours.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if prefs.ghSignedIn {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.system(size: 12))
                        Text("Signed in\(prefs.ghLogin.isEmpty ? "" : " as @\(prefs.ghLogin)") through the GitHub CLI (gh) — no username or token needed.")
                            .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                } else {
                    Field(label: "Username", text: $prefs.ghLogin, hint: "your-username", valid: prefs.ghLoginValid,
                          help: "The GitHub account whose commits count toward your time.")
                    Secret(label: "Access token", text: $prefs.ghToken, reveal: $prefs.showGHToken, valid: true,
                           help: GITHUB_TOKEN_HELP)
                }
                MultiSelect(label: "Organizations", options: prefs.ghOrgsAvailable, csv: $prefs.ghOrgs, valid: prefs.ghOrgsValid,
                            help: "Tick the organizations whose commits count toward your time — loaded automatically from your GitHub.")
            }
            PrefCard(title: "Azure DevOps — optional") {
                Text("Turn on to count your Azure DevOps commits and pushes alongside GitHub.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Toggle("Enabled", isOn: $prefs.adoEnabled).font(.system(size: 12)).toggleStyle(.switch)
                if prefs.adoEnabled {
                    Field(label: "Organization", text: $prefs.adoOrg, valid: !prefs.adoOrg.isEmpty,
                          help: "Your Azure DevOps organization — the name in dev.azure.com/<organization>.")
                    if prefs.adoProjectsAvailable.isEmpty {
                        Field(label: "Project", text: $prefs.adoProject, valid: !prefs.adoProject.isEmpty,
                              help: "The project holding your repos. Fill in Organization and the token, then Scan to load projects here as a dropdown.")
                    } else {
                        SingleSelect(label: "Project", options: prefs.adoProjectsAvailable, value: $prefs.adoProject,
                                     placeholder: "Select a project", valid: !prefs.adoProject.isEmpty,
                                     help: "The project holding the repos to scan — loaded from your Organization.")
                    }
                    MultiSelect(label: "Repos", options: prefs.adoReposAvailable, csv: $prefs.adoRepos, valid: !prefs.adoRepos.trimmingCharacters(in: .whitespaces).isEmpty,
                                help: "Tick the repos to scan for your commits and pushes — loaded automatically once Organization, Project, and the token are set.")
                    Field(label: "Author (email)", text: $prefs.adoAuthor, hint: "you@org.com", valid: !prefs.adoAuthor.isEmpty,
                          help: "Your commit-author email in Azure DevOps.")
                    Secret(label: "Access token", text: $prefs.adoPAT, reveal: $prefs.showPAT, valid: !prefs.adoPAT.isEmpty,
                           help: ADO_TOKEN_HELP)
                }
            }
        }
    }
}

struct AllocationContent: View {
    @ObservedObject var prefs: Prefs
    var body: some View {
        VStack(spacing: 14) {
            Text("These settings shape how your week becomes hours — how much each day should add up to, and how that time is divided between projects.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            PrefCard(title: "Your workday") {
                Text("How full each worked day should be, and the hours your work counts from.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                NumRow(label: "Daily target", value: $prefs.dailyTarget, width: 60, valid: prefs.targetValid, trailing: "hours",
                       help: "The total logged for each weekday you worked — meetings plus development. Usually 8–9.")
                HStack(spacing: 8) {
                    Text("Work hours").frame(width: LBL, alignment: .leading).font(.system(size: 12))
                    HourMinutePicker(value: $prefs.workStart, valid: prefs.workHoursValid)
                    Text("to").foregroundStyle(.secondary)
                    HourMinutePicker(value: $prefs.workEnd, valid: prefs.workHoursValid)
                    if !prefs.workHoursValid {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).font(.system(size: 11))
                    }
                    HelpIcon(text: "Only commits made inside these hours count — work before or after (like overnight automation) is left out.")
                    Spacer()
                }
            }
            PrefCard(title: "Timeline split") {
                Text("How a day's hours are split between projects. The app sorts your commits by time and credits the stretch before each one to that commit's project — so a long run on one project earns more of the day than a quick fix elsewhere.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                NumRow(label: "Gap cap", value: $prefs.gapCap, width: 56, valid: prefs.gapValid, trailing: "min",
                       help: "The most a single gap between two commits can be worth — keeps a long lunch or meeting from inflating one project.")
                NumRow(label: "Lead-in", value: $prefs.leadIn, width: 56, valid: prefs.gapValid, trailing: "min",
                       help: "Time credited before your very first commit of a block, for the thinking and setup you did before committing.")
            }
            PrefCard(title: "Holidays") {
                Text("Public holidays for your region are skipped automatically and left blank.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text("Region").frame(width: LBL, alignment: .leading).font(.system(size: 12))
                    Picker("", selection: $prefs.holidayRegion) {
                        ForEach(SUPPORTED_REGIONS, id: \.self) { Text(regionName($0)).tag($0) }
                    }.labelsHidden().frame(width: 220)
                        // The pop-up button's bezel is inset from its frame origin, so it starts a
                        // little right of the text-field column above; pull it back to line up.
                        .padding(.leading, -11)
                    Spacer()
                }
            }
        }
    }
}

// Second, stronger confirmation for the destructive reset: type-to-confirm (GitHub-style).
struct ResetConfirmSheet: View {
    @Binding var typed: String
    var onCancel: () -> Void = {}
    var onConfirm: () -> Void = {}
    var match: Bool {
        typed.trimmingCharacters(in: .whitespaces).uppercased() == "RESET"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Label("Delete everything and restart setup", systemImage: "trash.fill").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(.red)
            Text(RESET_WARNING)
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 5) {
                Text("Type RESET to confirm").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary)
                TextField("RESET", text: $typed).textFieldStyle(.roundedBorder).frame(width: 240)
            }
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }.controlSize(.large).keyboardShortcut(.cancelAction)
                Button(role: .destructive) { onConfirm() } label: { Text("Delete everything").frame(minWidth: 120) }
                    .controlSize(.large).tint(.red).disabled(!match)
            }
        }.padding(22).frame(width: 400)
    }
}

struct ResetCard: View {
    @ObservedObject var prefs: Prefs
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    @State private var confirm1 = false
    @State private var typeSheet = false
    @State private var typed = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Reset app", systemImage: "exclamationmark.triangle.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(.red).textCase(.uppercase)
            Text("Reset deletes your account, access tokens, and settings from this Mac and takes you back to setup — useful for handing the app to someone else or starting clean.")
                .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button(role: .destructive) { confirm1 = true } label: { Label("Reset", systemImage: "trash") }.controlSize(.large).tint(.red)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.red.opacity(0.28)))
        .alert("Reset Harvest Auto-Fill?", isPresented: $confirm1) {
            Button("Cancel", role: .cancel) {}
            Button("Reset…", role: .destructive) { typed = ""; typeSheet = true }
        } message: {
            Text(RESET_WARNING)
        }
        .sheet(isPresented: $typeSheet) {
            ResetConfirmSheet(typed: $typed,
                              onCancel: { typeSheet = false },
                              onConfirm: {
                                  prefs.resetAll(); typeSheet = false
                                  dismissWindow(id: "prefs"); openWindow(id: "welcome"); NSApp.activate(ignoringOtherApps: true)
                              })
        }
    }
}

struct GeneralContent: View {
    @ObservedObject var prefs: Prefs
    var body: some View {
        VStack(spacing: 14) {
            Text("How the app behaves day to day — when it logs your week, and where it lives on your Mac.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            PrefCard(title: "Automatic logging") {
                Text("Choose whether the app logs your finished week for you, or waits until you say so.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Toggle("Log the finished week to Harvest every Friday at 6:00 PM", isOn: $prefs.autoRecord).font(.system(size: 12.5)).toggleStyle(.switch)
                    HelpIcon(text: AUTO_LOG_HELP)
                }
            }
            PrefCard(title: "Dock icon") {
                HStack(spacing: 8) {
                    Toggle("Show the app icon in the Dock", isOn: $prefs.showDockIcon).font(.system(size: 12.5)).toggleStyle(.switch)
                        .onChange(of: prefs.showDockIcon) { _, on in
                            prefs.writeAll()
                            NSApp.setActivationPolicy(on ? .regular : .accessory)
                            if on {
                                NSApp.activate(ignoringOtherApps: true)
                            }
                        }
                    HelpIcon(text: "Off — the app lives only in the menu bar. On — it also appears in the Dock and the ⌘-Tab app switcher.")
                }
            }
            PrefCard(title: "How it works") {
                Label("Always current — your hours update in the background every 15 minutes, so the menu-bar total stays live.", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
                Label("Hands-off Fridays — the finished week is logged to Harvest at 6:00 PM on its own, even if the app is closed (turn off automatic logging above).", systemImage: "calendar.badge.checkmark")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
                Label("Private by design — everything you connect stays on this Mac and is never sent anywhere but the services you connect.", systemImage: "lock.shield")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            ResetCard(prefs: prefs)
        }
    }
}

struct ChangelogView: View {
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()), id: \.offset) { _, raw in
                let t = String(raw).trimmingCharacters(in: .whitespaces)
                if t.isEmpty {
                    Spacer().frame(height: 3)
                } else if t.hasPrefix("### ") {
                    Text(String(t.dropFirst(4))).font(.system(size: 12.5, weight: .semibold)).padding(.top, 2)
                } else if t.hasPrefix("## ") {
                    Text(String(t.dropFirst(3))).font(.system(size: 14, weight: .bold)).padding(.top, 3)
                } else if t.hasPrefix("# ") {
                    Text(String(t.dropFirst(2))).font(.system(size: 15, weight: .bold)).padding(.top, 3)
                } else if t.hasPrefix("- ") || t.hasPrefix("* ") {
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(.secondary).frame(width: 4, height: 4).padding(.top, 6)
                        Text(inlineMD(String(t.dropFirst(2)))).font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                } else {
                    Text(inlineMD(t)).font(.system(size: 12.5)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct WhatsNewView: View {
    @ObservedObject var updater = Updater.shared
    @Environment(\.dismissWindow) var dismissWindow
    var render = false
    var wn: WhatsNew? {
        updater.whatsNew
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                if let img = NSImage(contentsOfFile: P.icon) {
                    Image(nsImage: img).resizable().frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)).shadow(color: .black.opacity(0.18), radius: 4, y: 1)
                }
                Text("What's New").font(.system(size: 22, weight: .bold))
                HStack(spacing: 8) {
                    Text("Version \(wn?.version ?? updater.currentVersion)")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Web.primary)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Capsule().fill(Web.primary.opacity(0.14)))
                    if let d = wn?.date, !d.isEmpty {
                        Text(d).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }.padding(.top, 30).padding(.bottom, 18).frame(maxWidth: .infinity)
                .background(Web.card)

            Divider()

            Group {
                if render {
                    ChangelogView(text: wn?.notes ?? "").frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ChangelogView(text: wn?.notes ?? "").frame(maxWidth: .infinity, alignment: .leading)
                            let earlier = updater.releases.filter { $0.version != wn?.version }
                            if !earlier.isEmpty {
                                Divider()
                                Text("Earlier releases").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                                ForEach(Array(earlier.enumerated()), id: \.offset) { _, r in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text("Version \(r.version)")
                                                .font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Web.primary)
                                                .padding(.horizontal, 8).padding(.vertical, 2)
                                                .background(Capsule().fill(Web.primary.opacity(0.14)))
                                            if !r.date.isEmpty {
                                                Text(r.date).font(.system(size: 10.5)).foregroundStyle(.secondary)
                                            }
                                        }
                                        ChangelogView(text: r.notes).frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 340)
                }
            }.padding(20)

            Divider()

            HStack {
                Button { NSWorkspace.shared.open(URL(string: UPDATE_REPO_URL + "/releases")!) } label: {
                    Label("All releases on GitHub", systemImage: "arrow.up.right.square")
                }.buttonStyle(.plain).foregroundStyle(Web.primary).font(.system(size: 12))
                Spacer()
                // "Got It" is a post-update acknowledgement; when browsing from About the
                // window is just closed via its title bar, so no button is shown.
                if !updater.whatsNewManual {
                    Button("Got It") { updater.whatsNew = nil; updater.releases = []; dismissWindow(id: "whatsnew") }
                        .primaryProminent().controlSize(.large).keyboardShortcut(.defaultAction)
                }
            }.padding(.horizontal, 20).padding(.vertical, 14)
        }
        .frame(width: 460)
        .background(Web.card)
        .onAppear {
            // Opened from the Window menu (nothing populated it) — load the current release
            // notes so the window isn't blank.
            if !render, updater.whatsNew == nil {
                updater.showWhatsNewNow()
            }
        }
    }
}

struct UpdateCard: View {
    @ObservedObject var prefs: Prefs
    @ObservedObject var updater = Updater.shared
    var busy: Bool {
        if case .checking = updater.state {
            return true
        }; if case .downloading = updater.state {
            return true
        }; return false
    }

    var body: some View {
        PrefCard(title: "Software updates") {
            HStack(spacing: 12) {
                Button { updater.check(manual: true) } label: { Label("Check for updates", systemImage: "arrow.triangle.2.circlepath") }
                    .disabled(busy)
                status
                Spacer(minLength: 0)
            }
            if case let .ready(info) = updater.state {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Text("Version \(info.version) is ready to install").font(.system(size: 12.5, weight: .semibold))
                    }
                    if !info.notes.isEmpty {
                        ScrollView { ChangelogView(text: info.notes) }.frame(maxHeight: 150)
                            .padding(12).glassBG(10)
                    }
                    Button { updater.installAndRelaunch() } label: { Label("Update now & relaunch", systemImage: "arrow.down.circle.fill") }
                        .primaryProminent().controlSize(.large)
                }
            }
            Toggle("Keep this app up to date automatically", isOn: $prefs.autoUpdate).font(.system(size: 12)).toggleStyle(.switch)
                .onChange(of: prefs.autoUpdate) { _, _ in prefs.writeAll() }
            Text("Every update is verified as genuine before it installs. Checks happen quietly on launch and once a day. When this is on, updates install and relaunch on their own; when off, the app holds them here until you're ready.")
                .font(.system(size: 10.5)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder var status: some View {
        switch updater.state {
        case .idle: EmptyView()
        case .checking: HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Looking for updates…").font(.system(size: 12)).foregroundStyle(.secondary) }
        case .upToDate: Label("You're on the latest version", systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(.green)
        case .downloading: HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Getting the update ready…").font(.system(size: 12)).foregroundStyle(.secondary) }
        case .ready: Label("Update ready", systemImage: "sparkles").font(.system(size: 12)).foregroundStyle(.blue)
        case let .failed(m): Label(m, systemImage: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AboutContent: View {
    @ObservedObject var prefs: Prefs
    @ObservedObject var updater = Updater.shared
    // The running app shows its real bundle version; the render baseline passes a fixed value so
    // the About snapshot doesn't churn every release.
    var versionOverride: String?
    var version: String {
        versionOverride ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
    }

    var pyVersion: String {
        let vf = P.res + "/python/lib/python3.12"
        return FileManager.default.fileExists(atPath: vf) ? "3.12" : "—"
    }

    func reveal(_ path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    func openLog() {
        let p = P.dataDir + "/logs/last.log"
        if FileManager.default.fileExists(atPath: p) {
            NSWorkspace.shared.open(URL(fileURLWithPath: p))
        } else {
            reveal(P.dataDir + "/logs")
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 9) {
                if let img = NSImage(contentsOfFile: P.icon) {
                    Image(nsImage: img).resizable().frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 5, y: 1)
                }
                Text("Harvest Auto-Fill").font(.system(size: 18, weight: .bold))
                Text("Version \(version)").font(.system(size: 11.5)).foregroundStyle(.secondary)
                Text("Fills your Harvest timesheet from the work you already did — commits, pushes, and meetings turned into hours, logged for you every Friday.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 8)
                HStack(spacing: 16) {
                    Button { NotificationCenter.default.post(name: .openWhatsNew, object: nil) } label: {
                        HStack(spacing: 4) {
                            if updater.loadingWhatsNew {
                                ProgressView().controlSize(.small)
                            }
                            Label("What's New", systemImage: "sparkles")
                        }
                    }.buttonStyle(.plain).foregroundStyle(Web.primary).font(.system(size: 12)).disabled(updater.loadingWhatsNew)
                    Button { NSWorkspace.shared.open(URL(string: WEBSITE_URL)!) } label: {
                        Label("Website", systemImage: "safari")
                    }.buttonStyle(.plain).foregroundStyle(Web.primary).font(.system(size: 12))
                    Button { NSWorkspace.shared.open(URL(string: UPDATE_REPO_URL)!) } label: {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                    }.buttonStyle(.plain).foregroundStyle(Web.primary).font(.system(size: 12))
                }.padding(.top, 2)
            }.frame(maxWidth: .infinity).padding(.top, 4)

            UpdateCard(prefs: prefs)
            PrefCard(title: "Your privacy") {
                Text("Everything you connect — Harvest, GitHub, Azure DevOps, your calendar — stays on this Mac, in a locked folder, and goes nowhere except those services themselves. No account, no cloud, no tracking.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button { reveal(P.dataDir) } label: { Label("Reveal data folder", systemImage: "folder") }
                    Button { openLog() } label: { Label("Open latest log", systemImage: "doc.text") }
                }
            }
        }
    }
}

let PREFS_TABS: [(name: String, icon: String)] = [
    ("General", "gearshape"), ("Accounts", "person.crop.circle"),
    ("Allocation", "chart.pie"), ("About", "info.circle"),
]

struct PreferencesView: View {
    @StateObject var prefs: Prefs
    @State private var tab: Int // 0 General, 1 Accounts, 2 Allocation, 3 About
    @Namespace private var tabPill // slides the active-tab highlight between tabs
    @ObservedObject private var nav = PrefsNav.shared
    var render: Bool

    // `demo` injects populated prefs for the render baselines (Accounts/Allocation tabs); the
    // interactive app leaves it nil and gets a fresh empty Prefs. `startTab` picks which tab the
    // render captures.
    init(render: Bool = false, startTab: Int = 0, demo: Prefs? = nil) {
        self.render = render
        _prefs = StateObject(wrappedValue: demo ?? Prefs())
        _tab = State(initialValue: startTab)
    }

    var footer: some View {
        HStack(spacing: 10) {
            if !prefs.status.isEmpty {
                Text(prefs.status).foregroundStyle(.secondary).font(.system(size: 11.5)).lineLimit(1)
            }
            Spacer()
            if !prefs.canSave {
                Label("Fix the highlighted fields", systemImage: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(.orange)
            }
            Button("Save") { prefs.save() }.primaryProminent().controlSize(.large).keyboardShortcut(.defaultAction).disabled(!prefs.canSave)
        }.padding(.horizontal, 20).padding(.vertical, 14)
    }

    // Custom tab bar matching the marketing mockup: icon-above-label pills, the active tab
    // tinted with the site primary. Shared by the interactive window and the render baseline.
    func tabBar(active: Int, tappable: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(PREFS_TABS.enumerated()), id: \.offset) { i, t in
                Button {
                    if tappable, i != tab {
                        withAnimation(.easeInOut(duration: 0.22)) { tab = i }
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon).font(.system(size: 15))
                        Text(t.name).font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 7)
                    .foregroundStyle(active == i ? Web.primary : Color.secondary)
                    // The highlight is a single pill that slides to the active tab (matched
                    // geometry), rather than appearing/disappearing per tab.
                    .background {
                        if active == i {
                            RoundedRectangle(cornerRadius: 8).fill(Web.primary.opacity(0.12))
                                .matchedGeometryEffect(id: "tabPill", in: tabPill)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
            }
        }.padding(.horizontal, 10).padding(.vertical, 8)
    }

    var body: some View {
        if render {
            // One baseline per tab: the tab bar (active tab tinted) above that tab's content, so
            // each Preferences surface — including the populated Accounts/Allocation states — is
            // covered on its own instead of stacked into a single shot.
            VStack(alignment: .leading, spacing: 0) {
                tabBar(active: tab, tappable: false)
                Divider()
                VStack(alignment: .leading, spacing: 16) {
                    switch tab {
                    case 0: GeneralContent(prefs: prefs)
                    case 1: AccountsContent(prefs: prefs)
                    case 2: AllocationContent(prefs: prefs)
                    default: AboutContent(prefs: prefs)
                    }
                    footer
                }.padding(20)
            }.frame(width: 560).background(Web.card)
        } else {
            VStack(spacing: 0) {
                tabBar(active: tab, tappable: true)
                Divider()
                ScrollView {
                    Group {
                        switch tab {
                        case 0: GeneralContent(prefs: prefs)
                        case 1: AccountsContent(prefs: prefs)
                        case 2: AllocationContent(prefs: prefs)
                        default: AboutContent(prefs: prefs)
                        }
                    }.padding(20)
                }
                // Save appears only when there's something to save, and never on the About tab.
                if tab != 3, prefs.hasChanges {
                    Divider(); footer
                }
            }.frame(width: 560, height: 600).background(Web.card)
                .onAppear {
                    if let t = nav.requestedTab {
                        tab = t; nav.requestedTab = nil
                    }
                    prefs.checkGhAuth() // hides the token field when gh is signed in
                    if prefs.ghOrgsAvailable.isEmpty, prefs.adoReposAvailable.isEmpty {
                        prefs.discover()
                    }
                }
                .onChange(of: nav.requestedTab) { _, new in
                    // Switch tabs when the window is already open (e.g. app-menu About).
                    if let t = new {
                        tab = t; nav.requestedTab = nil
                    }
                }
        }
    }
}

let ONB_STEPS = ["Welcome", "Harvest", "Discover", "Sources", "Workday", "Finish"]

struct OnbDots: View {
    let step: Int
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0 ..< ONB_STEPS.count, id: \.self) { i in
                Capsule().fill(i == step ? Web.primary : (i < step ? Web.primary.opacity(0.4) : Color.secondary.opacity(0.22)))
                    .frame(width: i == step ? 22 : 8, height: 8)
            }
        }
    }
}

struct ScanBullet: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Web.primary).frame(width: 14)
            Text(text).font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// Renders a Lucide icon from its exact SVG (the same icons the website mockup uses), as a
// tintable template image so it can be filled white inside the orange badge.
struct LucideIcon: View {
    let svg: String
    var body: some View {
        Image(nsImage: makeImage()).resizable().renderingMode(.template)
    }

    private func makeImage() -> NSImage {
        let img = NSImage(data: Data(svg.utf8)) ?? NSImage(size: NSSize(width: 24, height: 24))
        img.isTemplate = true
        return img
    }
}

private func lucideSVG(_ body: String) -> String {
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"#000\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\">\(body)</svg>"
}

// The exact Lucide icon nodes for onboarding steps 2–6 (KeyRound, Sparkles, Workflow,
// CalendarClock, BadgeCheck) — identical to the marketing site.
let LUCIDE_KEY = lucideSVG("<path d=\"M2.586 17.414A2 2 0 0 0 2 18.828V21a1 1 0 0 0 1 1h3a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h1a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1h.172a2 2 0 0 0 1.414-.586l.814-.814a6.5 6.5 0 1 0-4-4z\"/><circle cx=\"16.5\" cy=\"7.5\" r=\".5\" fill=\"#000\"/>")
let LUCIDE_SPARKLES = lucideSVG("<path d=\"M11.017 2.814a1 1 0 0 1 1.966 0l1.051 5.558a2 2 0 0 0 1.594 1.594l5.558 1.051a1 1 0 0 1 0 1.966l-5.558 1.051a2 2 0 0 0-1.594 1.594l-1.051 5.558a1 1 0 0 1-1.966 0l-1.051-5.558a2 2 0 0 0-1.594-1.594l-5.558-1.051a1 1 0 0 1 0-1.966l5.558-1.051a2 2 0 0 0 1.594-1.594z\"/><path d=\"M20 2v4\"/><path d=\"M22 4h-4\"/><circle cx=\"4\" cy=\"20\" r=\"2\"/>")
let LUCIDE_WORKFLOW = lucideSVG("<rect width=\"8\" height=\"8\" x=\"3\" y=\"3\" rx=\"2\"/><path d=\"M7 11v4a2 2 0 0 0 2 2h4\"/><rect width=\"8\" height=\"8\" x=\"13\" y=\"13\" rx=\"2\"/>")
let LUCIDE_CALENDAR_CLOCK = lucideSVG("<path d=\"M16 14v2.2l1.6 1\"/><path d=\"M16 2v3\"/><path d=\"M21 7.338V5a2 2 0 0 0-2-2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h2.338\"/><path d=\"M3 9h5.859\"/><path d=\"M8 2v3\"/><circle cx=\"16\" cy=\"16\" r=\"6\"/>")
let LUCIDE_BADGE_CHECK = lucideSVG("<path d=\"M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z\"/><path d=\"m16 9-5.5 5.5L8 12\"/>")

struct OnbHeader: View {
    let lucide: String; let title: String; let subtitle: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // White Lucide icon in the orange gradient badge — matches the website mockup and the
            // app-icon look of step 1.
            LucideIcon(svg: lucide)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .frame(width: 52, height: 52)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.965, green: 0.565, blue: 0.227),
                                 Color(red: 0.886, green: 0.329, blue: 0.122)],
                        startPoint: .topLeading, endPoint: .bottomTrailing,
                    ),
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 21, weight: .bold))
                Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ValueBullet: View {
    let icon: String; let title: String; let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Web.primary).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

struct CheckRow: View {
    let ok: Bool; let text: String; var detail: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 9) {
                Image(systemName: ok ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(ok ? .green : .secondary).font(.system(size: 13))
                Text(text).font(.system(size: 12.5)).foregroundStyle(ok ? .primary : .secondary)
                Spacer(minLength: 0)
            }
            if !detail.isEmpty {
                Text(detail).font(.system(size: 11)).foregroundStyle(.tertiary)
                    .padding(.leading, 22).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OnbWelcome: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                if let img = NSImage(contentsOfFile: P.icon) {
                    Image(nsImage: img).resizable().frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 1)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to Harvest Auto-Fill").font(.system(size: 21, weight: .bold))
                    Text("Your timesheet, filled from the work you already did.").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                ValueBullet(icon: "calendar.badge.checkmark", title: "Logs itself every Friday",
                            detail: "Your finished week is logged to Harvest automatically at 6:00 PM — even if the app is closed.")
                ValueBullet(icon: "chart.bar.doc.horizontal", title: "Built from your activity",
                            detail: "Your commits, pushes, and meetings become hours, split across the right projects by when you did the work.")
                ValueBullet(icon: "lock.shield", title: "Private by design",
                            detail: "Every token stays on this Mac in a locked file and is never sent anywhere but the services you connect.")
            }
            Text("Setup takes about two minutes. You can change anything later in Settings.")
                .font(.system(size: 12)).foregroundStyle(.tertiary)
        }
    }
}

struct OnbHarvest: View {
    @ObservedObject var prefs: Prefs
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnbHeader(lucide: LUCIDE_KEY, title: "Connect your Harvest account",
                      subtitle: "The only account the app needs — where your hours are written.")
            VStack(spacing: 12) {
                Field(label: "Account ID", text: $prefs.harvestAccount, hint: "e.g. 123456", valid: prefs.harvestAccount.isEmpty || prefs.accountValid,
                      help: "The number in your Harvest web address — id.getharvest.com shows it under Settings.")
                Secret(label: "Access token", text: $prefs.harvestToken, reveal: $prefs.showToken, valid: true,
                       help: HARVEST_TOKEN_HELP)
            }
            HStack(spacing: 12) {
                Button { prefs.testHarvest() } label: { Label("Test connection", systemImage: "bolt.horizontal.circle") }
                    .controlSize(.large).disabled(!(prefs.accountValid && prefs.tokenValid) || prefs.harvestTest == .testing)
                switch prefs.harvestTest {
                case .idle: Text("The app checks the connection before moving on.").font(.system(size: 11.5)).foregroundStyle(.tertiary)
                case .testing: HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Checking…").font(.system(size: 12)).foregroundStyle(.secondary) }
                case let .ok(who): Label("Connected as \(who)", systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(.green)
                case let .fail(why): Label(why, systemImage: "exclamationmark.triangle.fill").font(.system(size: 12)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct OnbDiscover: View {
    @ObservedObject var prefs: Prefs
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnbHeader(lucide: LUCIDE_SPARKLES, title: "Find your projects automatically",
                      subtitle: "It scans your connected accounts so you never type a project number by hand.")
            if prefs.discovering {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Scanning your Harvest, GitHub, and Azure DevOps…").font(.system(size: 12.5)).foregroundStyle(.secondary) }
            } else if prefs.discovered {
                VStack(alignment: .leading, spacing: 9) {
                    CheckRow(ok: !prefs.harvestUser.isEmpty,
                             text: prefs.harvestName.isEmpty
                                 ? "Harvest user #\(prefs.harvestUser) found"
                                 : "Harvest user \(prefs.harvestName) (#\(prefs.harvestUser)) found")
                    CheckRow(ok: !prefs.projectsList.isEmpty,
                             text: "\(prefs.projectsList.count) Harvest project\(prefs.projectsList.count == 1 ? "" : "s") mapped",
                             detail: prefs.projectsList.map(\.0).joined(separator: ", "))
                    CheckRow(ok: !prefs.ghLogin.isEmpty,
                             text: prefs.ghLogin.isEmpty
                                 ? "No GitHub account found"
                                 : "GitHub @\(prefs.ghLogin)\(prefs.ghOrgsAvailable.isEmpty ? "" : " · \(prefs.ghOrgsAvailable.joined(separator: ", "))")")
                    if !prefs.adoReposAvailable.isEmpty {
                        CheckRow(ok: true,
                                 text: "\(prefs.adoReposAvailable.count) Azure DevOps repo\(prefs.adoReposAvailable.count == 1 ? "" : "s") found",
                                 detail: prefs.adoReposAvailable.joined(separator: ", "))
                    }
                }
                Text("You'll pick which of these to include on the next screen.").font(.system(size: 12)).foregroundStyle(.tertiary)
                Button { prefs.discover() } label: { Label("Scan again", systemImage: "arrow.clockwise") }.controlSize(.small)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("It reads a few things, so you never type an ID by hand:")
                        .font(.system(size: 12.5)).foregroundStyle(.secondary)
                    ScanBullet(text: "Your Harvest user — who the hours are logged as.")
                    ScanBullet(text: "Your Harvest projects — the list your time is split across.")
                    ScanBullet(text: "Your GitHub login and organizations — where your commits come from.")
                    ScanBullet(text: "Your Azure DevOps repositories — once you add a token, on the next step.")
                    Text("Everything here is read-only. Nothing is ever written.")
                        .font(.system(size: 11.5)).foregroundStyle(.tertiary).padding(.top, 2)
                }.fixedSize(horizontal: false, vertical: true)
                Button { prefs.discover() } label: { Label("Scan my accounts", systemImage: "sparkles") }.controlSize(.large).primaryProminent()
            }
        }
        .onAppear {
            if !prefs.discovered, !prefs.discovering {
                prefs.discover()
            }
        }
    }
}

struct OnbSources: View {
    @ObservedObject var prefs: Prefs
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            OnbHeader(lucide: LUCIDE_WORKFLOW, title: "Where your work lives",
                      subtitle: "Choose what the app turns into hours. GitHub is the main one; the rest are optional.")
            PrefCard(title: "GitHub") {
                if prefs.ghSignedIn {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.system(size: 12))
                        Text("Signed in\(prefs.ghLogin.isEmpty ? "" : " as @\(prefs.ghLogin)") through the GitHub CLI (gh) — no username or token needed.")
                            .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                } else {
                    Field(label: "Username", text: $prefs.ghLogin, hint: "your-username", valid: prefs.ghLogin.isEmpty || prefs.ghLoginValid,
                          help: "The GitHub account whose commits count toward your time.")
                    Secret(label: "Access token", text: $prefs.ghToken, reveal: $prefs.showGHToken, valid: true,
                           help: GITHUB_TOKEN_HELP + " Then Scan again to load your organizations.")
                }
                MultiSelect(label: "Organizations", options: prefs.ghOrgsAvailable, csv: $prefs.ghOrgs, valid: true,
                            help: "Tick the organizations whose commits count — loaded from your GitHub above.")
            }
            PrefCard(title: "Azure DevOps — optional") {
                Toggle("Also include Azure DevOps", isOn: $prefs.adoEnabled).font(.system(size: 12.5)).toggleStyle(.switch)
                if prefs.adoEnabled {
                    Field(label: "Organization", text: $prefs.adoOrg, valid: true)
                    if prefs.adoProjectsAvailable.isEmpty {
                        Field(label: "Project", text: $prefs.adoProject, valid: true)
                    } else {
                        SingleSelect(label: "Project", options: prefs.adoProjectsAvailable, value: $prefs.adoProject,
                                     placeholder: "Select a project", valid: !prefs.adoProject.isEmpty)
                    }
                    Field(label: "Author (email)", text: $prefs.adoAuthor, hint: "you@org.com", valid: true,
                          help: "Your commit-author email in Azure DevOps.")
                    Secret(label: "Access token", text: $prefs.adoPAT, reveal: $prefs.showPAT, valid: true,
                           help: ADO_TOKEN_HELP + " Then Scan again on the previous step to load repos.")
                    MultiSelect(label: "Repos", options: prefs.adoReposAvailable, csv: $prefs.adoRepos, valid: true,
                                help: "Tick the repos to scan for your commits and pushes.")
                }
            }
            PrefCard(title: "Google Calendar — optional") {
                Text("Adds your meetings as hours. Skip it and only your commits and pushes count.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Field(label: "Web-app URL", text: $prefs.calUrl, hint: "https://script.google.com/macros/s/…/exec", valid: prefs.calUrlValid,
                      help: "The web-app link the setup below gives you (it ends in /exec).")
                Secret(label: "Shared secret", text: $prefs.calSecret, reveal: $prefs.showSecret, valid: prefs.calSecretValid)
                CalendarTestRow(prefs: prefs)
                CalendarHelp()
            }
        }
        .onAppear { prefs.checkGhAuth() } // hides the token field when gh is signed in
    }
}

struct OnbWorkday: View {
    @ObservedObject var prefs: Prefs
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            OnbHeader(lucide: LUCIDE_CALENDAR_CLOCK, title: "Your workday",
                      subtitle: "Defaults are filled in — adjust only if yours differ, then continue.")
            PrefCard(title: "Hours") {
                NumRow(label: "Daily target", value: $prefs.dailyTarget, width: 60, valid: prefs.targetValid, trailing: "hours",
                       help: "Hours logged per worked weekday — meetings plus development. Usually 8–9.")
                HStack(spacing: 8) {
                    Text("Work hours").frame(width: LBL, alignment: .leading).font(.system(size: 12))
                    HourMinutePicker(value: $prefs.workStart, valid: prefs.workHoursValid)
                    Text("to").foregroundStyle(.secondary)
                    HourMinutePicker(value: $prefs.workEnd, valid: prefs.workHoursValid)
                    if !prefs.workHoursValid {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).font(.system(size: 11))
                    }
                    HelpIcon(text: "Only commits made inside these hours count — work before or after (like overnight automation) is left out.")
                    Spacer()
                }
            }
            PrefCard(title: "Holidays") {
                HStack(spacing: 8) {
                    Text("Region").frame(width: LBL, alignment: .leading).font(.system(size: 12))
                    Picker("", selection: $prefs.holidayRegion) {
                        ForEach(SUPPORTED_REGIONS, id: \.self) { Text(regionName($0)).tag($0) }
                    }.labelsHidden().frame(width: 220)
                        .padding(.leading, -11) // match the input column (pop-up bezel inset)
                    HelpIcon(text: "Public holidays for this region are skipped automatically and left blank on your timesheet.")
                    Spacer()
                }
            }
            PrefCard(title: "Timeline split") {
                NumRow(label: "Gap cap", value: $prefs.gapCap, width: 56, valid: prefs.gapValid, trailing: "min",
                       help: "The most time credited to a single stretch between two commits — caps long gaps like lunch.")
                NumRow(label: "Lead-in", value: $prefs.leadIn, width: 56, valid: prefs.gapValid, trailing: "min",
                       help: "Time credited before your first commit of a working block.")
            }
        }
    }
}

struct OnbFinish: View {
    @ObservedObject var prefs: Prefs
    var render = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnbHeader(lucide: LUCIDE_BADGE_CHECK, title: "Here's your week",
                      subtitle: "A live preview from everything you connected — nothing is logged yet.")
            if prefs.previewing || prefs.logging {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text(prefs.logging ? "Logging to Harvest…" : "Building this week's preview…").font(.system(size: 12.5)).foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 20)
            } else if let s = prefs.preview, !s.days.isEmpty {
                let st = statusFor(s.state)
                HStack(spacing: 6) {
                    Image(systemName: st.symbol).foregroundStyle(st.color).font(.system(size: 12))
                    Text("\(s.week) · \(hrs(s.actualTotal)) · \(s.actualDaysWorked) day\(s.actualDaysWorked == 1 ? "" : "s")\(s.projectedTotal > 0 ? " · \(hrs(s.projectedTotal)) projected" : "")").font(.system(size: 12.5, weight: .semibold))
                }
                VStack(spacing: 0) {
                    ForEach(Array(s.days.enumerated()), id: \.offset) { i, day in
                        DayBlock(day: day)
                        if i < s.days.count - 1 {
                            Divider().opacity(0.5)
                        }
                    }
                }.padding(.vertical, 4).padding(.horizontal, 14).glassBG(12, render: render)
            } else {
                Text("No preview yet — that's fine. Once you've committed or had meetings this week, the menu-bar total fills in. You can finish now.")
                    .font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            PrefCard(title: "Automatic logging") {
                Toggle("Log the finished week to Harvest every Friday at 6:00 PM", isOn: $prefs.autoRecord).font(.system(size: 12.5)).toggleStyle(.switch)
                Text(AUTO_LOG_HELP)
                    .font(.system(size: 10.5)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OnboardingView: View {
    @ObservedObject var prefs: Prefs
    @State private var step: Int
    var render = false
    var onDone: () -> Void

    init(prefs: Prefs, startStep: Int = 0, render: Bool = false, onDone: @escaping () -> Void = {}) {
        self.prefs = prefs
        _step = State(initialValue: startStep)
        self.render = render
        self.onDone = onDone
    }

    var canAdvance: Bool {
        // The Harvest step normally waits for a passing connection test. But when onboarding is
        // re-opened with an account already saved, don't force a re-test — valid saved creds
        // are enough to move on.
        guard step == 1 else { return true }
        return prefs.harvestTest.isOK || (!prefs.harvestAccount.isEmpty && !prefs.harvestToken.isEmpty)
    }

    var primaryLabel: String {
        step == 0 ? "Get started" : (step == ONB_STEPS.count - 1 ? "Done" : "Continue")
    }

    @ViewBuilder var content: some View {
        switch step {
        case 0: OnbWelcome()
        case 1: OnbHarvest(prefs: prefs)
        case 2: OnbDiscover(prefs: prefs)
        case 3: OnbSources(prefs: prefs)
        case 4: OnbWorkday(prefs: prefs)
        default: OnbFinish(prefs: prefs, render: render)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                OnbDots(step: step)
                Spacer()
                Text("Step \(step + 1) of \(ONB_STEPS.count)").font(.system(size: 11)).foregroundStyle(.tertiary)
            }.padding(.horizontal, 26).padding(.top, 20).padding(.bottom, 16)

            Group {
                if render {
                    content.padding(.horizontal, 26)
                } else {
                    ScrollView { content.padding(.horizontal, 26).padding(.bottom, 8) }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()
            HStack(spacing: 10) {
                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }.controlSize(.large)
                }
                Spacer()
                if step == ONB_STEPS.count - 1, prefs.preview?.days.isEmpty == false {
                    Button { prefs.logThisWeek() } label: { Text("Log this week") }.controlSize(.large).disabled(prefs.logging || prefs.previewing)
                }
                Button(primaryLabel) {
                    if step < ONB_STEPS.count - 1 {
                        withAnimation { step += 1 }
                    } else {
                        prefs.markComplete(); prefs.syncAgents(); onDone()
                    }
                }.primaryProminent().controlSize(.large).keyboardShortcut(.defaultAction).disabled(!canAdvance)
            }.padding(.horizontal, 26).padding(.vertical, 16)
        }
        .frame(width: 560, height: 640)
        .background(Web.card)
    }
}

struct MenuContent: View {
    @ObservedObject var model: WeekModel
    @ObservedObject var updater = Updater.shared
    @Environment(\.openWindow) var openWindow
    var body: some View {
        // Order follows the macOS status-menu convention: status → primary actions → checks →
        // links → settings → quit. Ellipsis only where the command gathers more input first.
        if model.summary != nil {
            Text(model.menuHeadline).font(.system(size: 12, weight: .semibold))
            Text(model.menuDetail).font(.system(size: 11))
            Divider()
        }
        if case let .ready(info) = updater.state {
            Button { updater.installAndRelaunch() } label: {
                Label("Install update — version \(info.version) & relaunch", systemImage: "arrow.down.circle.fill")
            }
            Divider()
        }
        Button { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) } label: {
            Label("This Week", systemImage: "calendar")
        }
        Button { model.refresh() } label: {
            Label(model.refreshing ? "Recalculating…" : "Recalculate this week now", systemImage: "arrow.clockwise")
        }.disabled(model.refreshing)
        Divider()
        Button { updater.check(manual: true) } label: {
            Label(updater.state == .checking ? "Checking for updates…" : "Check for Updates…", systemImage: "arrow.down.circle")
        }.disabled(updater.state == .checking)
        Button { NotificationCenter.default.post(name: .openWhatsNew, object: nil) } label: {
            Label("What's New", systemImage: "sparkles")
        }
        Divider()
        Button { NSWorkspace.shared.open(URL(string: WEBSITE_URL)!) } label: {
            Label("Website", systemImage: "safari")
        }
        Button { NSWorkspace.shared.open(URL(string: UPDATE_REPO_URL)!) } label: {
            Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        Divider()
        Button { openWindow(id: "prefs"); NSApp.activate(ignoringOtherApps: true) } label: {
            Label("Settings…", systemImage: "gearshape")
        }
        Divider()
        Button { confirmQuit() } label: { Label("Quit", systemImage: "power") }
    }
}

// Menu-bar apps are easy to quit by accident; confirm, and be honest that the Friday
// auto-log keeps running on schedule (it's a launchd job, independent of the app).
func confirmQuit() {
    let a = NSAlert()
    a.messageText = "Quit Harvest Auto-Fill?"
    a.informativeText = "The menu-bar app will close. Your scheduled Friday auto-log still runs, and the app reopens at your next login."
    a.alertStyle = .warning
    a.addButton(withTitle: "Quit")
    a.addButton(withTitle: "Cancel")
    NSApp.activate(ignoringOtherApps: true)
    if a.runModal() == .alertFirstButtonReturn {
        NSApp.terminate(nil)
    }
}

struct MenuLabel: View {
    @ObservedObject var model: WeekModel
    @ObservedObject var updater = Updater.shared
    @Environment(\.openWindow) var openWindow
    var body: some View {
        HStack(spacing: 4) { Image(systemName: "clock.badge.checkmark"); Text(model.menuTitle) }
            .onChange(of: updater.whatsNew) { _, new in
                if new != nil {
                    openWindow(id: "whatsnew"); NSApp.activate(ignoringOtherApps: true)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openMainWindow)) { _ in
                openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                openWindow(id: "prefs"); NSApp.activate(ignoringOtherApps: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openOnboarding)) { _ in
                openWindow(id: "welcome"); NSApp.activate(ignoringOtherApps: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .openWhatsNew)) { _ in
                // Load the current notes and open the window directly, so it opens even when
                // whatsNew is already set (e.g. the window was closed by its close button).
                updater.showWhatsNewNow()
                openWindow(id: "whatsnew"); NSApp.activate(ignoringOtherApps: true)
            }
            .onAppear {
                if model.firstRun { // new user: run the onboarding wizard once
                    model.firstRun = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        openWindow(id: "welcome"); NSApp.activate(ignoringOtherApps: true)
                    }
                }
            }
    }
}

// Verification-only view: renders the two new pieces faithfully (no DisclosureGroup/Picker stand-ins)
struct VerifyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendar — How to connect (expanded)").font(.system(size: 13, weight: .bold))
            VStack(alignment: .leading, spacing: 10) {
                Step(n: 1, text: CALENDAR_SETUP_STEPS[0])
                Step(n: 2, text: CALENDAR_SETUP_STEPS[1])
                Text(highlightJS(doGetCode)).font(.system(size: 10, design: .monospaced)).padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.25)))
                Step(n: 3, text: CALENDAR_SETUP_STEPS[2])
                Step(n: 4, text: CALENDAR_SETUP_STEPS[3])
                Step(n: 5, text: CALENDAR_SETUP_STEPS[4])
            }
            Divider()
            Text("Holidays — Region dropdown labels").font(.system(size: 13, weight: .bold))
            VStack(alignment: .leading, spacing: 4) {
                ForEach(SUPPORTED_REGIONS, id: \.self) { c in
                    HStack(spacing: 8) {
                        Text(c).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                        Image(systemName: "arrow.right").font(.system(size: 9)).foregroundStyle(.tertiary)
                        Text(regionName(c)).font(.system(size: 12))
                    }
                }
            }
        }.padding(22).frame(width: 640).background(Web.card)
    }
}

extension Notification.Name {
    static let openMainWindow = Notification.Name("HarvestOpenMainWindow")
    static let openSettings = Notification.Name("HarvestOpenSettings")
    static let openWhatsNew = Notification.Name("HarvestOpenWhatsNew")
    static let openOnboarding = Notification.Name("HarvestOpenOnboarding")
}

// Lets the app menu ask Settings to open on a specific tab (e.g. About).
@MainActor final class PrefsNav: ObservableObject {
    static let shared = PrefsNav()
    @Published var requestedTab: Int?
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        let args = CommandLine.arguments
        // hidden self-test: exercise the real update-check path and print the terminal state
        if args.contains("--update-check") {
            Task { @MainActor in
                let u = Updater.shared; u.check(manual: true)
                for _ in 0 ..< 80 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    switch u.state {
                    case .upToDate: print("STATE=upToDate (current build \(u.currentBuild))"); NSApp.terminate(nil)
                    case let .ready(i): print("STATE=ready version \(i.version) build \(i.build) (current \(u.currentBuild))"); NSApp.terminate(nil)
                    case let .failed(m): print("STATE=failed \(m)"); NSApp.terminate(nil)
                    default: break
                    }
                }
                print("STATE=timeout"); NSApp.terminate(nil)
            }
            return
        }
        if args.contains("--prefs-selftest") { // exercise the Save-appears-only-on-change signal
            let p = Prefs()
            print("PREFS afterLoad hasChanges=\(p.hasChanges)") // expect false
            let old = p.ghLogin
            p.ghLogin = old + "-selftest"
            print("PREFS afterEdit hasChanges=\(p.hasChanges)") // expect true
            p.writeAll()
            print("PREFS afterSave hasChanges=\(p.hasChanges)") // expect false
            p.ghLogin = old; p.writeAll() // restore
            NSApp.terminate(nil); return
        }
        if args.contains("--self-update-now") { // check → download → install/relaunch
            Task { @MainActor in
                let u = Updater.shared; u.check(manual: true)
                for _ in 0 ..< 80 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if case .ready = u.state {
                        print("INSTALLING"); u.installAndRelaunch(); return
                    }
                    if case .upToDate = u.state {
                        print("UPTODATE"); NSApp.terminate(nil)
                    }
                    if case let .failed(m) = u.state {
                        print("FAILED \(m)"); NSApp.terminate(nil)
                    }
                }
                print("TIMEOUT"); NSApp.terminate(nil)
            }
            return
        }
        if args.contains("--whatsnew-test") { // force a post-update scenario and report
            UserDefaults.standard.set(Updater.shared.currentBuild - 1, forKey: "seenBuild")
            Task { @MainActor in
                Updater.shared.maybeShowWhatsNew()
                for _ in 0 ..< 30 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if let wn = Updater.shared.whatsNew {
                        let hist = Updater.shared.releases.map(\.version).joined(separator: ",")
                        print("WHATSNEW version=\(wn.version) date=\(wn.date) url=\(wn.url) notesChars=\(wn.notes.count) history=[\(hist)]"); NSApp.terminate(nil)
                    }
                }
                print("WHATSNEW none"); NSApp.terminate(nil)
            }
            return
        }
        if let i = args.firstIndex(of: "--render"), i + 2 < args.count {
            let which = args[i + 1], out = args[i + 2]
            let model = WeekModel()
            model.summary = Self.demoPrefs().preview // show the generic demo week, matching the site mockup
            model.refreshing = false // no spinner in a static render (ImageRenderer can't draw ProgressView)
            var view: any View = MainWindow(model: model, render: true)
            if which == "prefs" {
                view = PreferencesView(render: true)
            } else if which == "prefs-accounts" {
                // Capture the discovered/signed-in Accounts states (gh-CLI note instead of
                // username+token; ADO Project as a dropdown) — the branches onboarding's
                // manual-field baselines don't reach.
                let p = Self.demoPrefs()
                p.ghSignedIn = true
                p.adoProjectsAvailable = ["Platform", "Marketing Site", "Internal Tools"]
                view = PreferencesView(render: true, startTab: 1, demo: p)
            } else if which == "prefs-allocation" {
                view = PreferencesView(render: true, startTab: 2, demo: Self.demoPrefs())
            } else if which == "verify" {
                view = VerifyView()
            } else if which.hasPrefix("onb") {
                view = OnboardingView(prefs: Self.demoPrefs(), startStep: Int(which.dropFirst(3)) ?? 0, render: true)
            } else if which == "reset" {
                view = ResetConfirmSheet(typed: .constant("RESET")).background(Web.card)
            } else if which == "about" {
                view = AboutContent(prefs: Prefs(), versionOverride: "0.0.0").padding(22).frame(width: 480).background(Web.card)
            } else if which == "main-empty" {
                let m = WeekModel(); m.summary = nil; m.refreshing = false
                view = MainWindow(model: m, render: true)
            } else if which == "main-issues" {
                let s = Self.demoPrefs().preview!
                let withIssues = Summary(state: s.state, week: s.week, total: s.total, daysWorked: s.daysWorked,
                                         days: s.days, flags: s.flags,
                                         issues: [
                                             "Tuesday's meetings exceed the 9h daily target — nothing was logged for that day.",
                                             "Azure DevOps org isn't set — pushes won't be counted until you add it in Settings.",
                                         ], message: s.message)
                let m = WeekModel(); m.summary = withIssues; m.refreshing = false
                view = MainWindow(model: m, render: true)
            } else if which.hasPrefix("whatsnew") {
                Updater.shared.whatsNewManual = (which == "whatsnewmanual") // manual = no "Continue"
                Updater.shared.whatsNew = WhatsNew(version: "2.11", notes: """
                ## Auto-update
                - The app now checks GitHub for **signed** updates and installs them for you.
                - A new *What's New* screen shows the changelog after each update — and any time from About.

                ## Polish
                - Clearer wording across the whole update flow.
                - A green check now appears on every field you've filled in correctly.
                - The Friday auto-log moved from 4pm to **6pm**.
                """, date: "August 31, 2026", url: UPDATE_REPO_URL)
                view = WhatsNewView(render: true)
            }
            let renderer = ImageRenderer(content: AnyView(AnyView(view).tint(Web.primary))); renderer.scale = 2
            if let img = renderer.nsImage, let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:])
            {
                try? png.write(to: URL(fileURLWithPath: out))
            }
            NSApp.terminate(nil); return
        }
        // Menu-bar utility: no Dock icon by default, unless the user opted in (Settings → General).
        NSApp.setActivationPolicy(Prefs.dockIconEnabled() ? .regular : .accessory)
        Updater.shared.startAuto() // check GitHub for signed updates on launch + daily
        // seed a default config on first launch so the engine has something to read
        if !FileManager.default.fileExists(atPath: P.config), FileManager.default.fileExists(atPath: P.configDefault) {
            try? FileManager.default.copyItem(atPath: P.configDefault, toPath: P.config)
        }
        // first-run Preferences is handled by MenuLabel.onAppear (needs openWindow)
        // Fix up the Window menu's window list. SwiftUI adds one row per Window scene whether or
        // not it's open (so closed Welcome/What's New rows show) and never checks the active one.
        // It populates the list in its own menu delegate's menuNeedsUpdate, so a plain reconcile
        // is undone the instant the submenu is navigated to. Instead we insert ourselves as the
        // submenu's delegate — chaining to SwiftUI's original so its rows still build — and then
        // reconcile after it. The main menu bar posts didBeginTracking as the user clicks into it
        // (before any submenu draws), which is where we (re)install the chained delegate.
        NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main,
        ) { [weak self] note in
            guard let self, let bar = note.object as? NSMenu,
                  let windowMenu = bar.items.first(where: { $0.submenu?.title == "Window" })?.submenu
            else { return }
            MainActor.assumeIsolated {
                if windowMenu.delegate !== self {
                    self.swiftUIWindowMenuDelegate = windowMenu.delegate
                    windowMenu.delegate = self
                }
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { (NSApp.delegate as? AppDelegate)?.model?.refresh() }
        }
    }

    // Clicking the Dock icon brings existing windows forward; if none are open, it opens the
    // main "This Week" window (posted to MenuLabel, which holds the SwiftUI openWindow action).
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        if !hasVisibleWindows {
            NotificationCenter.default.post(name: .openMainWindow, object: nil)
        }
        return true
    }

    // Right-clicking the Dock icon lists the app's open windows (the active one checked); each
    // brings its window forward. With none open it offers to open the main window.
    private func appWindows() -> [NSWindow] {
        NSApp.windows.filter { $0.isVisible && $0.canBecomeMain && !$0.title.isEmpty }
    }

    func applicationDockMenu(_: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let windows = appWindows()
        if windows.isEmpty {
            let item = NSMenuItem(title: "This Week", action: #selector(openMainFromDock), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            return menu
        }
        for w in windows {
            let item = NSMenuItem(title: w.title, action: #selector(focusWindow(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = w
            if w == NSApp.keyWindow {
                item.state = .on
            }
            menu.addItem(item)
        }
        return menu
    }

    @objc private func focusWindow(_ sender: NSMenuItem) {
        (sender.representedObject as? NSWindow)?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openMainFromDock() {
        NotificationCenter.default.post(name: .openMainWindow, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // SwiftUI's own Window-menu delegate, which we chain to so its rows still build before we
    // reconcile them.
    private weak var swiftUIWindowMenuDelegate: NSMenuDelegate?

    // The titles SwiftUI gives the Window menu's per-scene rows (one per Window scene, shown even
    // when that window is closed). We reconcile only these rows, leaving the system's
    // Minimize/Zoom/tiling items alone.
    private static let sceneWindowTitles: Set<String> = [
        "Harvest — This Week", "Settings", "Welcome to Harvest Auto-Fill", "What's New",
    ]

    // As the Window submenu is about to display: let SwiftUI build its rows, then reconcile them —
    // hide rows whose window isn't open and check the active one, so the list reflects reality.
    // SwiftUI's rows are reused (their open/focus behaviour is intact); we only toggle visibility
    // and the checkmark.
    func menuNeedsUpdate(_ menu: NSMenu) {
        swiftUIWindowMenuDelegate?.menuNeedsUpdate?(menu)
        let openTitles = Set(appWindows().map(\.title))
        let keyTitle = NSApp.keyWindow?.title
        for item in menu.items where Self.sceneWindowTitles.contains(item.title) {
            let isOpen = openTitles.contains(item.title)
            item.isHidden = !isOpen
            item.state = isOpen && item.title == keyTitle ? .on : .off
        }
    }

    var model: WeekModel?

    // Populated Prefs for faithfully rendering each onboarding step in verification.
    @MainActor static func demoPrefs() -> Prefs {
        // All demo values are generic — no real client, account, or repo names ever render.
        let p = Prefs()
        p.harvestAccount = "123456"; p.harvestToken = "pat-xxxxxxxx"
        p.harvestTest = .ok("Alex Rivera · you@example.com")
        p.harvestUser = "654321"; p.harvestName = "Alex Carter"; p.discovered = true
        p.projectsList = [("Website", "100001"), ("Design", "100002"), ("Mobile App", "100003"), ("Internal", "100004")]
        p.ghLogin = "octocat"; p.ghOrgsAvailable = ["acme-inc", "acme-labs"]; p.ghOrgs = "acme-inc, acme-labs"
        p.adoEnabled = true; p.adoOrg = "acme"; p.adoProject = "Platform"
        p.adoAuthor = "you@example.com"; p.adoPAT = "ado-xxxx"
        p.adoReposAvailable = ["web-app", "mobile-app", "api", "infra"]; p.adoRepos = "web-app, mobile-app"
        p.preview = Summary(state: "dryrun", week: "Aug 31 – Sep 4", total: 36.0, daysWorked: 4,
                            days: [
                                Day(name: "Mon Aug 31", total: 9.0, note: nil, entries: [
                                    Entry(span: "9:00 AM–1:30 PM", project: "Website", task: "Development", hours: 4.5),
                                    Entry(span: "1:30 PM–5:00 PM", project: "Design", task: "Development", hours: 3.5),
                                    Entry(span: "11:00 AM–11:30 AM", project: "Website", task: "Client meeting", hours: 1.0),
                                ]),
                                Day(name: "Tue Sep 1", total: 9.0, note: nil, entries: [
                                    Entry(span: "9:00 AM–6:00 PM", project: "Mobile App", task: "Development", hours: 9.0),
                                ]),
                                Day(name: "Wed Sep 2", total: nil, note: "Public holiday — skipped", entries: []),
                                Day(name: "Thu Sep 3", total: 9.0, note: nil, entries: [
                                    Entry(span: "9:00 AM–5:00 PM", project: "Internal", task: "Development", hours: 8.0),
                                    Entry(span: "3:00 PM–4:00 PM", project: "Internal", task: "Internal meeting", hours: 1.0),
                                ]),
                                Day(name: "Fri Sep 4", total: 9.0, note: nil, entries: [
                                    Entry(span: "9:00 AM–6:00 PM", project: "Website", task: "Development", hours: 9.0),
                                ]),
                            ], flags: [], issues: nil, message: "")
        return p
    }
}

@main
struct HarvestMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var model = WeekModel()
    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model).onAppear { delegate.model = model; model.refresh() }.tint(Web.primary)
        } label: {
            MenuLabel(model: model)
        }
        Window("Harvest — This Week", id: "main") {
            MainWindow(model: model).onAppear { delegate.model = model; model.refreshIfStale() }.tint(Web.primary)
                .textSelection(.enabled)
        }.windowResizability(.contentSize).windowStyle(.hiddenTitleBar)
            .commands {
                // About opens Settings → About; add a real Settings item (⌘,), a This Week
                // entry, and route Quit through the same confirm dialog the menu-bar uses.
                CommandGroup(replacing: .appInfo) {
                    Button {
                        PrefsNav.shared.requestedTab = 3
                        NotificationCenter.default.post(name: .openSettings, object: nil)
                    } label: { Label("About Harvest Auto-Fill", systemImage: "info.circle") }
                }
                CommandGroup(replacing: .appSettings) {
                    Button { NotificationCenter.default.post(name: .openSettings, object: nil) } label: {
                        Label("Settings…", systemImage: "gearshape")
                    }
                    .keyboardShortcut(",", modifiers: .command)
                }
                CommandGroup(after: .appSettings) {
                    Button {
                        // Run the check and open Settings → About, where the result shows.
                        PrefsNav.shared.requestedTab = 3
                        Updater.shared.check(manual: true)
                        NotificationCenter.default.post(name: .openSettings, object: nil)
                    } label: { Label("Check for Updates…", systemImage: "arrow.down.circle") }
                    Button { NotificationCenter.default.post(name: .openMainWindow, object: nil) } label: {
                        Label("This Week", systemImage: "calendar")
                    }
                    Button { NotificationCenter.default.post(name: .openOnboarding, object: nil) } label: {
                        Label("Onboarding", systemImage: "figure.walk")
                    }
                }
                CommandGroup(replacing: .appTermination) {
                    Button { confirmQuit() } label: { Label("Quit Harvest Auto-Fill", systemImage: "power") }
                        .keyboardShortcut("q", modifiers: .command)
                }
                // Replace the dead "Harvest Auto-Fill Help" (there's no Apple Help book) with
                // links that work.
                CommandGroup(replacing: .help) {
                    Button { NSWorkspace.shared.open(URL(string: WEBSITE_URL)!) } label: {
                        Label("Harvest Auto-Fill Website", systemImage: "safari")
                    }
                    Button { NSWorkspace.shared.open(URL(string: UPDATE_REPO_URL)!) } label: {
                        Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
                // Drop SwiftUI's per-scene "open this window" entries from the Window menu; the
                // standard AppKit list below them already shows the open windows with the active
                // one checked.
                CommandGroup(replacing: .windowList) {}
            }
        Window("Settings", id: "prefs") {
            PreferencesView().onAppear { NSApp.activate(ignoringOtherApps: true) }.tint(Web.primary)
                .textSelection(.enabled)
        }.windowResizability(.contentSize).windowStyle(.hiddenTitleBar)
        Window("Welcome to Harvest Auto-Fill", id: "welcome") {
            OnboardingWindowHost().tint(Web.primary)
        }.windowResizability(.contentSize).windowStyle(.hiddenTitleBar)
        Window("What's New", id: "whatsnew") {
            WhatsNewView().onAppear { NSApp.activate(ignoringOtherApps: true) }.tint(Web.primary)
                .textSelection(.enabled)
        }.windowResizability(.contentSize).windowStyle(.hiddenTitleBar)
    }
}

struct OnboardingWindowHost: View {
    @StateObject private var prefs = Prefs()
    @Environment(\.dismissWindow) var dismissWindow
    @Environment(\.openWindow) var openWindow
    var body: some View {
        OnboardingView(prefs: prefs, onDone: {
            dismissWindow(id: "welcome")
            openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true)
        }).onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}
