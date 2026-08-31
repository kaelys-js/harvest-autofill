import AppKit
import CryptoKit
import SwiftUI

// HarvestApp — SwiftUI views, the app delegate, and the @main entry point.
// Logic lives in HarvestCore.swift (same module in the app build).

// ============================================================ Paths
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

// ============================================================ Main window
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
                        Image(systemName: st.symbol).foregroundStyle(st.color).font(.system(size: 13))
                        Text(st.text).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(st.color)
                    }
                    Text(s.map { "\($0.week)  ·  \(hrs($0.total))  ·  \($0.daysWorked) day\($0.daysWorked == 1 ? "" : "s")" } ?? "No data yet — refreshing…")
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
                Button { model.refresh() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .disabled(model.refreshing)
                if let lr = model.lastRefresh {
                    Text("updated \(lr.formatted(date: .omitted, time: .shortened))").font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                Spacer()
                Button { model.logNow() } label: { Text("Log this week to Harvest") }
                    .primaryProminent().controlSize(.large).disabled(model.refreshing)
            }.padding(.horizontal, 18).padding(.vertical, 14)
        }
        .frame(width: 470)
        .background(render ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.regularMaterial))
    }
}

// ============================================================ Preferences
let LBL: CGFloat = 190
extension View {
    // Frosted content card: legible over the window's material, modern layered depth.
    // (True Liquid Glass is reserved for floating controls — see primaryProminent — per HIG.)
    func glassBG(_ radius: CGFloat = 12) -> some View {
        background(.thinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(.primary.opacity(0.06)))
    }

    @ViewBuilder func primaryProminent() -> some View {
        if #available(macOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
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
                .frame(width: 17, height: 17).background(Circle().fill(Color.accentColor))
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
            Button { prefs.testCalendar() } label: { Label("Test calendar", systemImage: "bolt.horizontal.circle") }
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
                Step(n: 1, text: "Go to script.google.com (signed in as the Google account whose calendar you use) and create a New project.")
                Step(n: 2, text: "Replace everything in Code.gs with this — it checks a secret and returns your events as JSON:")
                CodeBox(code: doGetCode)
                Step(n: 3, text: "Click the gear (Project Settings) → Script Properties → Add script property. Name it APPS_SCRIPT_SECRET and set the value to a strong secret you choose.")
                Step(n: 4, text: "Deploy → New deployment → choose Web app. Set Execute as: Me and Who has access: Anyone. Click Deploy, then copy the Web-app URL (it ends in /exec).")
                Step(n: 5, text: "Paste that URL and the same secret into the two fields above.")
                Text("The script runs as your own Google account, so there's no OAuth to configure and your calendar can stay private — the tool only reads each event's time, title, and your RSVP.")
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

struct Help: View { let text: String; var body: some View {
    Text(text).font(.system(size: 10.5)).foregroundStyle(.tertiary).padding(.leading, LBL + 8).fixedSize(horizontal: false, vertical: true)
}}
struct Field: View {
    let label: String; @Binding var text: String; var hint = ""; var valid = true; var help = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(label).frame(width: LBL, alignment: .leading).font(.system(size: 12))
                TextField(hint, text: $text).textFieldStyle(.roundedBorder).overlay(invalidBorder(valid))
                ValidMark(valid: valid, filled: !text.isEmpty)
            }
            if !help.isEmpty {
                Help(text: help)
            }
        }
    }
}

struct Secret: View {
    let label: String; @Binding var text: String; @Binding var reveal: Bool; var valid = true; var help = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
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
            }
            if !help.isEmpty {
                Help(text: help)
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
        VStack(alignment: .leading, spacing: 3) {
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
            }
            if !help.isEmpty {
                Help(text: help)
            }
        }
    }
}

struct NumRow: View {
    let label: String; @Binding var value: Double; var width: CGFloat = 60; var valid = true; var trailing = ""; var help = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(label).frame(width: LBL, alignment: .leading).font(.system(size: 12))
                TextField("", value: $value, format: .number).frame(width: width).textFieldStyle(.roundedBorder).overlay(invalidBorder(valid))
                if !trailing.isEmpty {
                    Text(trailing).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                ValidMark(valid: valid, filled: true)
                Spacer()
            }
            if !help.isEmpty {
                Help(text: help)
            }
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
        .glassBG(12)
    }
}

struct AccountsContent: View {
    @ObservedObject var prefs: Prefs
    var body: some View {
        VStack(spacing: 14) {
            PrefCard(title: "Harvest") {
                Field(label: "Account ID", text: $prefs.harvestAccount, hint: "e.g. 582834", valid: prefs.accountValid,
                      help: "Your numeric Harvest account, sent as the Harvest-Account-Id request header.")
                Secret(label: "Access token", text: $prefs.harvestToken, reveal: $prefs.showToken, valid: prefs.tokenValid,
                       help: "From id.getharvest.com → Developers → Create New Personal Access Token.")
                HStack { Text("User ID").frame(width: LBL, alignment: .leading).font(.system(size: 12))
                    Text(prefs.harvestUser.isEmpty ? "—" : prefs.harvestUser).font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer(); Button { prefs.discover() } label: { Label("Discover from my accounts", systemImage: "sparkles") }
                }
                Text("Discover reads your Harvest, GitHub, and (when a PAT is set) Azure DevOps to auto-fill your user ID, project mappings, org list, and repo list — so you never type IDs by hand.")
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
            PrefCard(title: "Calendar — Google, via Apps Script") {
                Field(label: "Web-app URL", text: $prefs.calUrl, hint: "https://script.google.com/macros/s/…/exec", valid: prefs.calUrlValid,
                      help: "The /exec URL of your deployed Apps Script web app.")
                Secret(label: "Shared secret", text: $prefs.calSecret, reveal: $prefs.showSecret, valid: prefs.calSecretValid,
                       help: "The APPS_SCRIPT_SECRET you set as a Script Property.")
                CalendarTestRow(prefs: prefs)
                CalendarHelp()
            }
            PrefCard(title: "GitHub") {
                Field(label: "Login", text: $prefs.ghLogin, hint: "your-username", valid: prefs.ghLoginValid,
                      help: "The GitHub account whose commits count toward your time.")
                Secret(label: "Access token", text: $prefs.ghToken, reveal: $prefs.showGHToken, valid: true,
                       help: "Optional. A read-only token (github.com → Settings → Developer settings → Fine-grained tokens → Repository: read). Leave blank if the GitHub CLI (gh) is installed and signed in.")
                MultiSelect(label: "Orgs", options: prefs.ghOrgsAvailable, csv: $prefs.ghOrgs, valid: prefs.ghOrgsValid,
                            help: "Tick the orgs whose commits count toward your time — loaded automatically from your GitHub.")
            }
            PrefCard(title: "Azure DevOps — optional (Wheaton)") {
                Toggle("Enabled", isOn: $prefs.adoEnabled).font(.system(size: 12)).toggleStyle(.switch)
                if prefs.adoEnabled {
                    Field(label: "Org", text: $prefs.adoOrg, valid: !prefs.adoOrg.isEmpty)
                    Field(label: "Project", text: $prefs.adoProject, valid: !prefs.adoProject.isEmpty)
                    MultiSelect(label: "Repos", options: prefs.adoReposAvailable, csv: $prefs.adoRepos, valid: !prefs.adoRepos.trimmingCharacters(in: .whitespaces).isEmpty,
                                help: "Tick the repos to scan for your commits + pushes — loaded automatically once Org, Project, and PAT are set.")
                    Field(label: "Author (email)", text: $prefs.adoAuthor, hint: "you@org.com", valid: !prefs.adoAuthor.isEmpty,
                          help: "Your commit-author email in Azure DevOps.")
                    Secret(label: "Read PAT", text: $prefs.adoPAT, reveal: $prefs.showPAT, valid: !prefs.adoPAT.isEmpty,
                           help: "A read-only Code PAT: dev.azure.com → User settings → Personal access tokens → Code: Read.")
                }
            }
        }
    }
}

struct AllocationContent: View {
    @ObservedObject var prefs: Prefs
    var body: some View {
        VStack(spacing: 14) {
            PrefCard(title: "Your workday") {
                NumRow(label: "Daily target", value: $prefs.dailyTarget, width: 60, valid: prefs.targetValid, trailing: "hours",
                       help: "Hours logged per worked weekday — meetings plus development. Usually 8–9.")
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Work hours").frame(width: LBL, alignment: .leading).font(.system(size: 12))
                        TextField("", value: $prefs.workStart, format: .number).frame(width: 44).textFieldStyle(.roundedBorder).overlay(invalidBorder(prefs.workHoursValid))
                        Text("to").foregroundStyle(.secondary)
                        TextField("", value: $prefs.workEnd, format: .number).frame(width: 44).textFieldStyle(.roundedBorder).overlay(invalidBorder(prefs.workHoursValid))
                        Text(":00").foregroundStyle(.secondary)
                        if !prefs.workHoursValid {
                            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).font(.system(size: 11))
                        }
                        Spacer()
                    }
                    Help(text: "Only commits inside these hours count toward the split — before/after-hours work (e.g. overnight automation) is ignored.")
                }
            }
            PrefCard(title: "Timeline split") {
                NumRow(label: "Gap cap", value: $prefs.gapCap, width: 56, valid: prefs.gapValid, trailing: "min",
                       help: "The most time credited to a single stretch between two commits — caps long gaps like lunch or a meeting.")
                NumRow(label: "Lead-in", value: $prefs.leadIn, width: 56, valid: prefs.gapValid, trailing: "min",
                       help: "Time credited before your first commit of a working block, for setup you did before committing.")
                Text("How dev hours are split: your commit timestamps are sorted, and the (capped) time between each is credited to whichever project that commit belongs to — estimating real hours per project instead of counting commits.")
                    .font(.system(size: 10.5)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }
            PrefCard(title: "Holidays") {
                HStack(spacing: 8) {
                    Text("Region").frame(width: LBL, alignment: .leading).font(.system(size: 12))
                    Picker("", selection: $prefs.holidayRegion) {
                        ForEach(SUPPORTED_REGIONS, id: \.self) { Text(regionName($0)).tag($0) }
                    }.labelsHidden().frame(width: 220)
                    Spacer()
                }
                Help(text: "Statutory holidays for this region are computed automatically and left blank on your timesheet.")
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
            Text("This permanently removes your saved account, access tokens, and all settings from this Mac, then takes you back to setup. It can't be undone.")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 5) {
                Text("Type RESET to confirm").font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary)
                TextField("RESET", text: $typed).textFieldStyle(.roundedBorder).frame(width: 240)
            }
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel", role: .cancel) { onCancel() }.controlSize(.large).keyboardShortcut(.cancelAction)
                Button(role: .destructive) { onConfirm() } label: { Text("Delete everything").frame(minWidth: 120) }
                    .controlSize(.large).disabled(!match)
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
            Label("Danger zone", systemImage: "exclamationmark.triangle.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(.red).textCase(.uppercase)
            Text("Reset removes your account, tokens, and settings from this Mac and returns you to setup — useful for handing the app to someone else or starting clean.")
                .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button(role: .destructive) { confirm1 = true } label: { Label("Reset", systemImage: "trash") }.controlSize(.large)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.red.opacity(0.28)))
        .alert("Reset Harvest Auto-Fill?", isPresented: $confirm1) {
            Button("Cancel", role: .cancel) {}
            Button("Continue…", role: .destructive) { typed = ""; typeSheet = true }
        } message: {
            Text("This permanently deletes your saved account, access tokens, and all settings from this Mac, then restarts setup. This can't be undone.")
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
            PrefCard(title: "Automatic recording") {
                Toggle("Log the finished week to Harvest every Friday at 6pm", isOn: $prefs.autoRecord).font(.system(size: 12.5)).toggleStyle(.switch)
                Text("On — the app records your week for you every Friday evening and won't double-book if it already ran. Off — nothing reaches Harvest until you open the app and click \u{201C}Log this week.\u{201D}")
                    .font(.system(size: 10.5)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }
            PrefCard(title: "Dock icon") {
                Toggle("Show the app icon in the Dock", isOn: $prefs.showDockIcon).font(.system(size: 12.5)).toggleStyle(.switch)
                    .onChange(of: prefs.showDockIcon) { _, on in
                        prefs.writeAll()
                        NSApp.setActivationPolicy(on ? .regular : .accessory)
                        if on {
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                Text("Off — the app lives only in the menu bar. On — it also appears in the Dock and the \u{2318}-Tab app switcher.")
                    .font(.system(size: 10.5)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }
            PrefCard(title: "How it works") {
                Label("Always current — your week's hours recompute in the background every 15 minutes, so the menu-bar total is live.", systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
                Label("Hands-off Fridays — the finished week is filed to Harvest at 6pm on its own, even if the app is closed (turn this off above).", systemImage: "calendar.badge.checkmark")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
                Label("Yours alone — every token stays on this Mac and is never sent anywhere.", systemImage: "lock.shield")
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
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                    if let d = wn?.date, !d.isEmpty {
                        Text(d).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }.padding(.top, 30).padding(.bottom, 18).frame(maxWidth: .infinity)
                .background(render ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.regularMaterial))

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
                                                .font(.system(size: 10.5, weight: .semibold)).foregroundStyle(Color.accentColor)
                                                .padding(.horizontal, 8).padding(.vertical, 2)
                                                .background(Capsule().fill(Color.accentColor.opacity(0.14)))
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
                }.buttonStyle(.link).font(.system(size: 12))
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
        .background(render ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.regularMaterial))
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
            Text("Every update is signed and verified before it's installed. Checks happen quietly on launch and once a day. When this is on, updates install and relaunch on their own; when off, the app holds them here until you're ready.")
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
    var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
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
                Text("Fills your Harvest timesheet from the work you already did — commits, pushes, and meetings turned into hours, filed for you every Friday.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 8)
                HStack(spacing: 16) {
                    Button { updater.showWhatsNewNow() } label: {
                        HStack(spacing: 4) {
                            if updater.loadingWhatsNew {
                                ProgressView().controlSize(.small)
                            }
                            Label("What's new", systemImage: "sparkles")
                        }
                    }.buttonStyle(.link).font(.system(size: 12)).disabled(updater.loadingWhatsNew)
                    Button { NSWorkspace.shared.open(URL(string: WEBSITE_URL)!) } label: {
                        Label("Website", systemImage: "safari")
                    }.buttonStyle(.link).font(.system(size: 12))
                    Button { NSWorkspace.shared.open(URL(string: UPDATE_REPO_URL)!) } label: {
                        Label("View on GitHub", systemImage: "arrow.up.right.square")
                    }.buttonStyle(.link).font(.system(size: 12))
                }.padding(.top, 2)
            }.frame(maxWidth: .infinity).padding(.top, 4)

            UpdateCard(prefs: prefs)
            PrefCard(title: "Your privacy") {
                Text("Your Harvest, GitHub, Azure DevOps, and calendar tokens live only on this Mac, in a locked folder, and are sent to nowhere but those services themselves. No account, no cloud, no telemetry.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button { reveal(P.dataDir) } label: { Label("Reveal data folder", systemImage: "folder") }
                    Button { openLog() } label: { Label("Open latest log", systemImage: "doc.text") }
                }
            }
            PrefCard(title: "Included software") {
                Text("Python \(pyVersion) is bundled inside the app (python-build-standalone, PSF-licensed) so nothing needs installing. GitHub uses your token or the gh CLI; everything else is built in.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            PrefCard(title: "Sharing it") {
                Text("Copy the app to another Mac and it starts fresh with its own setup — none of your accounts come along. Made for the TTT team.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct PreferencesView: View {
    @StateObject var prefs = Prefs()
    @State private var tab = 0 // 0 General, 1 Accounts, 2 Allocation, 3 About
    var render = false
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

    var body: some View {
        if render {
            VStack(alignment: .leading, spacing: 16) {
                Text("Harvest Auto-Fill — Preferences").font(.system(size: 15, weight: .bold))
                GeneralContent(prefs: prefs); AccountsContent(prefs: prefs); AllocationContent(prefs: prefs)
                footer
            }.padding(20).frame(width: 560).background(Color(nsColor: .windowBackgroundColor))
        } else {
            VStack(spacing: 0) {
                TabView(selection: $tab) {
                    ScrollView { GeneralContent(prefs: prefs).padding(20) }.tabItem { Label("General", systemImage: "gearshape") }.tag(0)
                    ScrollView { AccountsContent(prefs: prefs).padding(20) }.tabItem { Label("Accounts", systemImage: "person.crop.circle") }.tag(1)
                    ScrollView { AllocationContent(prefs: prefs).padding(20) }.tabItem { Label("Allocation", systemImage: "chart.pie") }.tag(2)
                    ScrollView { AboutContent(prefs: prefs).padding(20) }.tabItem { Label("About", systemImage: "info.circle") }.tag(3)
                }
                // Save appears only when there's something to save, and never on the About tab.
                if tab != 3, prefs.hasChanges {
                    Divider(); footer
                }
            }.frame(width: 560, height: 600).background(.regularMaterial)
                .onAppear {
                    if prefs.ghOrgsAvailable.isEmpty, prefs.adoReposAvailable.isEmpty {
                        prefs.discover()
                    }
                }
        }
    }
}

// ============================================================ Onboarding (first-run wizard)
let ONB_STEPS = ["Welcome", "Harvest", "Discover", "Sources", "Workday", "Finish"]

struct OnbDots: View {
    let step: Int
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0 ..< ONB_STEPS.count, id: \.self) { i in
                Capsule().fill(i == step ? Color.accentColor : (i < step ? Color.accentColor.opacity(0.4) : Color.secondary.opacity(0.22)))
                    .frame(width: i == step ? 22 : 8, height: 8)
            }
        }
    }
}

struct OnbHeader: View {
    let icon: String; let title: String; let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(Color.accentColor)
            Text(title).font(.system(size: 21, weight: .bold))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ValueBullet: View {
    let icon: String; let title: String; let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 16)).foregroundStyle(Color.accentColor).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

struct CheckRow: View {
    let ok: Bool; let text: String
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle.dashed").foregroundStyle(ok ? .green : .secondary).font(.system(size: 13))
            Text(text).font(.system(size: 12.5)).foregroundStyle(ok ? .primary : .secondary)
            Spacer(minLength: 0)
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
                ValueBullet(icon: "calendar.badge.checkmark", title: "Fills itself every Friday",
                            detail: "Your finished week is logged to Harvest automatically at 6pm — even if the app is closed.")
                ValueBullet(icon: "chart.bar.doc.horizontal", title: "Built from real activity",
                            detail: "Your commits, pushes, and meetings become hours, split across the right projects by when you did the work.")
                ValueBullet(icon: "lock.shield", title: "Private by design",
                            detail: "Every token stays on this Mac in a locked file and is never sent anywhere but the services you connect.")
            }
            Text("Setup takes about two minutes. You can change anything later in Preferences.")
                .font(.system(size: 12)).foregroundStyle(.tertiary)
        }
    }
}

struct OnbHarvest: View {
    @ObservedObject var prefs: Prefs
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnbHeader(icon: "key.horizontal", title: "Connect your Harvest account",
                      subtitle: "This is the one account we truly need — it's where your hours get written.")
            VStack(spacing: 12) {
                Field(label: "Account ID", text: $prefs.harvestAccount, hint: "e.g. 582834", valid: prefs.harvestAccount.isEmpty || prefs.accountValid,
                      help: "Your numeric Harvest account, sent as the Harvest-Account-Id header.")
                Secret(label: "Access token", text: $prefs.harvestToken, reveal: $prefs.showToken, valid: true,
                       help: "Get one at id.getharvest.com → Developers → Create New Personal Access Token.")
            }
            HStack(spacing: 12) {
                Button { prefs.testHarvest() } label: { Label("Test connection", systemImage: "bolt.horizontal.circle") }
                    .controlSize(.large).disabled(!(prefs.accountValid && prefs.tokenValid) || prefs.harvestTest == .testing)
                switch prefs.harvestTest {
                case .idle: Text("We'll verify it works before moving on.").font(.system(size: 11.5)).foregroundStyle(.tertiary)
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
    var orgCount: Int {
        prefs.ghOrgs.split(separator: ",").count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnbHeader(icon: "sparkles", title: "Let's find your projects automatically",
                      subtitle: "Rather than typing IDs by hand, we'll read your accounts and fill them in.")
            if prefs.discovering {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Scanning your Harvest, GitHub, and Azure DevOps…").font(.system(size: 12.5)).foregroundStyle(.secondary) }
            } else if prefs.discovered {
                VStack(alignment: .leading, spacing: 9) {
                    CheckRow(ok: !prefs.harvestUser.isEmpty, text: "Harvest user \(prefs.harvestUser.isEmpty ? "" : "#\(prefs.harvestUser)") found")
                    CheckRow(ok: !prefs.projectsList.isEmpty, text: "\(prefs.projectsList.count) Harvest projects mapped")
                    CheckRow(ok: !prefs.ghLogin.isEmpty, text: prefs.ghLogin.isEmpty ? "No GitHub account found" : "GitHub @\(prefs.ghLogin) · \(orgCount) org\(orgCount == 1 ? "" : "s")")
                    if !prefs.adoReposAvailable.isEmpty {
                        CheckRow(ok: true, text: "\(prefs.adoReposAvailable.count) Azure DevOps repos found")
                    }
                }
                Text("You'll pick which of these to include on the next screen.").font(.system(size: 12)).foregroundStyle(.tertiary)
                Button { prefs.discover() } label: { Label("Scan again", systemImage: "arrow.clockwise") }.controlSize(.small)
            } else {
                Text("This reads your Harvest projects and IDs, your GitHub login and organizations, and — if you add an Azure DevOps token later — your repositories. Nothing is written; it only reads.")
                    .font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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
            OnbHeader(icon: "point.3.filled.connected.trianglepath.dotted", title: "Where your work lives",
                      subtitle: "Pick the sources we should turn into hours. GitHub is the main one; the rest are optional.")
            PrefCard(title: "GitHub") {
                Field(label: "Login", text: $prefs.ghLogin, hint: "your-username", valid: prefs.ghLogin.isEmpty || prefs.ghLoginValid,
                      help: "The GitHub account whose commits count toward your time.")
                Secret(label: "Access token", text: $prefs.ghToken, reveal: $prefs.showGHToken, valid: true,
                       help: "Optional read-only token (github.com → Settings → Developer settings → Fine-grained tokens → Repository: read). Skip it if the GitHub CLI (gh) is installed and signed in. Then Scan again to load orgs.")
                MultiSelect(label: "Orgs", options: prefs.ghOrgsAvailable, csv: $prefs.ghOrgs, valid: true,
                            help: "Tick the orgs whose commits count — loaded from your GitHub above.")
            }
            PrefCard(title: "Azure DevOps — optional") {
                Toggle("I also commit in Azure DevOps", isOn: $prefs.adoEnabled).font(.system(size: 12.5)).toggleStyle(.switch)
                if prefs.adoEnabled {
                    Field(label: "Org", text: $prefs.adoOrg, valid: true)
                    Field(label: "Project", text: $prefs.adoProject, valid: true)
                    Field(label: "Author (email)", text: $prefs.adoAuthor, hint: "you@org.com", valid: true,
                          help: "Your commit-author email in Azure DevOps.")
                    Secret(label: "Read PAT", text: $prefs.adoPAT, reveal: $prefs.showPAT, valid: true,
                           help: "A read-only Code PAT: dev.azure.com → User settings → Personal access tokens → Code: Read. Then Scan again on the previous step to load repos.")
                    MultiSelect(label: "Repos", options: prefs.adoReposAvailable, csv: $prefs.adoRepos, valid: true,
                                help: "Tick the repos to scan for your commits and pushes.")
                }
            }
            PrefCard(title: "Google Calendar — optional") {
                Text("Adds meeting hours from your calendar. Skip it and only commits/pushes count.")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Field(label: "Web-app URL", text: $prefs.calUrl, hint: "https://script.google.com/macros/s/…/exec", valid: prefs.calUrlValid,
                      help: "The /exec URL of your deployed Apps Script web app.")
                Secret(label: "Shared secret", text: $prefs.calSecret, reveal: $prefs.showSecret, valid: prefs.calSecretValid)
                CalendarTestRow(prefs: prefs)
                CalendarHelp()
            }
        }
    }
}

struct OnbWorkday: View {
    @ObservedObject var prefs: Prefs
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            OnbHeader(icon: "clock.badge", title: "Your workday",
                      subtitle: "Sensible defaults are already set — adjust only if yours differ, then continue.")
            PrefCard(title: "Hours") {
                NumRow(label: "Daily target", value: $prefs.dailyTarget, width: 60, valid: prefs.targetValid, trailing: "hours",
                       help: "Hours logged per worked weekday — meetings plus development. Usually 8–9.")
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Work hours").frame(width: LBL, alignment: .leading).font(.system(size: 12))
                        TextField("", value: $prefs.workStart, format: .number).frame(width: 44).textFieldStyle(.roundedBorder).overlay(invalidBorder(prefs.workHoursValid))
                        Text("to").foregroundStyle(.secondary)
                        TextField("", value: $prefs.workEnd, format: .number).frame(width: 44).textFieldStyle(.roundedBorder).overlay(invalidBorder(prefs.workHoursValid))
                        Text(":00").foregroundStyle(.secondary); Spacer()
                    }
                    Help(text: "Only commits inside these hours count toward the split.")
                }
            }
            PrefCard(title: "Holidays") {
                HStack(spacing: 8) {
                    Text("Region").frame(width: LBL, alignment: .leading).font(.system(size: 12))
                    Picker("", selection: $prefs.holidayRegion) {
                        ForEach(SUPPORTED_REGIONS, id: \.self) { Text(regionName($0)).tag($0) }
                    }.labelsHidden().frame(width: 220); Spacer()
                }
                Help(text: "Statutory holidays for this region are computed automatically and left blank on your timesheet.")
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
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnbHeader(icon: "checkmark.seal", title: "Here's your week",
                      subtitle: "A live preview from everything you connected — nothing is written yet.")
            if prefs.previewing || prefs.logging {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text(prefs.logging ? "Writing to Harvest…" : "Building this week's preview…").font(.system(size: 12.5)).foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 20)
            } else if let s = prefs.preview, !s.days.isEmpty {
                let st = statusFor(s.state)
                HStack(spacing: 6) {
                    Image(systemName: st.symbol).foregroundStyle(st.color).font(.system(size: 12))
                    Text("\(s.week) · \(hrs(s.total)) · \(s.daysWorked) day\(s.daysWorked == 1 ? "" : "s")").font(.system(size: 12.5, weight: .semibold))
                }
                VStack(spacing: 0) {
                    ForEach(Array(s.days.enumerated()), id: \.offset) { i, day in
                        DayBlock(day: day)
                        if i < s.days.count - 1 {
                            Divider().opacity(0.5)
                        }
                    }
                }.padding(.vertical, 4).padding(.horizontal, 14).glassBG(12)
            } else {
                Text("No preview yet — that's fine. Once you've committed or had meetings this week, the menu-bar total fills in. You can finish now.")
                    .font(.system(size: 12.5)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            PrefCard(title: "Automatic recording") {
                Toggle("Log the finished week to Harvest every Friday at 6pm", isOn: $prefs.autoRecord).font(.system(size: 12.5)).toggleStyle(.switch)
                Text("On — records your week automatically every Friday evening (safe to run twice, it never double-books) and keeps the app running so it can. Off — you stay in control: nothing is logged until you click “Log this week” yourself.")
                    .font(.system(size: 10.5)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            }
            PrefCard(title: "Ready to run") {
                CheckRow(ok: prefs.pythonReady, text: prefs.pythonReady ? "Python engine — built into the app, nothing to install" : "Bundled Python missing — reinstall the app")
                CheckRow(ok: prefs.curlReady, text: "Network access (curl) — part of macOS")
                Text(prefs.ghToken.isEmpty ? "GitHub uses the gh CLI on this Mac. On a Mac without gh, add a GitHub token on the previous step." : "GitHub uses the token you added — no gh CLI needed.")
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
        step == 1 ? prefs.harvestTest.isOK : true
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
        default: OnbFinish(prefs: prefs)
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
                    Button { prefs.logThisWeek() } label: { Text("Log this week now") }.controlSize(.large).disabled(prefs.logging || prefs.previewing)
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
        .background(render ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.regularMaterial))
    }
}

// ============================================================ Menu
struct MenuContent: View {
    @ObservedObject var model: WeekModel
    @ObservedObject var updater = Updater.shared
    @Environment(\.openWindow) var openWindow
    var body: some View {
        if model.summary != nil {
            Text(model.menuHeadline).font(.system(size: 12, weight: .semibold))
            Text(model.menuDetail).font(.system(size: 11))
            Divider()
        }
        if case let .ready(info) = updater.state {
            Button("Update ready — install version \(info.version)") { updater.installAndRelaunch() }
            Divider()
        }
        Button("Open") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
        Button("Preferences…") { openWindow(id: "prefs"); NSApp.activate(ignoringOtherApps: true) }
        Button(model.refreshing ? "Recalculating…" : "Recalculate this week now") { model.refresh() }.disabled(model.refreshing)
        Divider()
        Button("Quit") { confirmQuit() }
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
                Step(n: 1, text: "Go to script.google.com (signed in as the Google account whose calendar you use) and create a New project.")
                Step(n: 2, text: "Replace everything in Code.gs with this — it checks a secret and returns your events as JSON:")
                Text(highlightJS(doGetCode)).font(.system(size: 10, design: .monospaced)).padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.25)))
                Step(n: 3, text: "Click the gear (Project Settings) → Script Properties → Add script property. Name it APPS_SCRIPT_SECRET and set the value to a strong secret you choose.")
                Step(n: 4, text: "Deploy → New deployment → choose Web app. Set Execute as: Me and Who has access: Anyone. Click Deploy, then copy the Web-app URL (it ends in /exec).")
                Step(n: 5, text: "Paste that URL and the same secret into the two fields above.")
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
        }.padding(22).frame(width: 640).background(Color(nsColor: .windowBackgroundColor))
    }
}

// ============================================================ App
class AppDelegate: NSObject, NSApplicationDelegate {
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
        // render mode for verification
        if let i = args.firstIndex(of: "--render"), i + 2 < args.count {
            let which = args[i + 1], out = args[i + 2]
            let model = WeekModel()
            var view: any View = MainWindow(model: model, render: true)
            if which == "prefs" {
                view = PreferencesView(render: true)
            } else if which == "verify" {
                view = VerifyView()
            } else if which.hasPrefix("onb") {
                view = OnboardingView(prefs: Self.demoPrefs(), startStep: Int(which.dropFirst(3)) ?? 0, render: true)
            } else if which == "reset" {
                view = ResetConfirmSheet(typed: .constant("RESET")).background(Color(nsColor: .windowBackgroundColor))
            } else if which == "about" {
                view = AboutContent(prefs: Prefs()).padding(22).frame(width: 480).background(Color(nsColor: .windowBackgroundColor))
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
            let renderer = ImageRenderer(content: AnyView(view)); renderer.scale = 2
            if let img = renderer.nsImage, let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:])
            {
                try? png.write(to: URL(fileURLWithPath: out))
            }
            NSApp.terminate(nil); return
        }
        // Menu-bar utility: no Dock icon by default, unless the user opted in (Preferences → General).
        NSApp.setActivationPolicy(Prefs.dockIconEnabled() ? .regular : .accessory)
        Updater.shared.startAuto() // check GitHub for signed updates on launch + daily
        // seed a default config on first launch so the engine has something to read
        if !FileManager.default.fileExists(atPath: P.config), FileManager.default.fileExists(atPath: P.configDefault) {
            try? FileManager.default.copyItem(atPath: P.configDefault, toPath: P.config)
        }
        // first-run Preferences is handled by MenuLabel.onAppear (needs openWindow)
        // wake -> refresh
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            (NSApp.delegate as? AppDelegate)?.model?.refresh()
        }
    }

    var model: WeekModel?

    // Populated Prefs for faithfully rendering each onboarding step in verification.
    @MainActor static func demoPrefs() -> Prefs {
        let p = Prefs()
        p.harvestAccount = "582834"; p.harvestToken = "pat-xxxxxxxx"
        p.harvestTest = .ok("Cole Beuker · cole.beuker@ttt.studio")
        p.harvestUser = "5692603"; p.discovered = true
        p.projectsList = [("ITC", "47292703"), ("Internal", "48661670"), ("Providence", "47573403"), ("Wheaton", "48917029")]
        p.ghLogin = "kaelys-js"; p.ghOrgsAvailable = ["resistjs", "tttstudios"]; p.ghOrgs = "resistjs, tttstudios"
        p.adoEnabled = true; p.adoOrg = "wheatonpreciousmetals"; p.adoProject = "OMS"
        p.adoAuthor = "ttt.cbeuker@wheatonpm.com"; p.adoPAT = "ado-xxxx"
        p.adoReposAvailable = ["OMS-AI", "OMS-BE", "OMS-DevOps", "OMS-FE"]; p.adoRepos = "OMS-BE, OMS-FE"
        p.preview = Summary(state: "dryrun", week: "Aug 24–28", total: 36.0, daysWorked: 4,
                            days: [
                                Day(name: "Mon Aug 24", total: 9.0, note: nil, entries: [
                                    Entry(span: "9:00am–1:30pm", project: "ITC", task: "Development", hours: 4.5),
                                    Entry(span: "1:30pm–5:00pm", project: "Wheaton", task: "Development", hours: 3.5),
                                    Entry(span: "11:00am–11:30am", project: "ITC", task: "Client Meetings", hours: 1.0),
                                ]),
                                Day(name: "Tue Aug 25", total: 9.0, note: nil, entries: [
                                    Entry(span: "9:00am–6:00pm", project: "Wheaton", task: "Development", hours: 9.0),
                                ]),
                                Day(name: "Wed Aug 26", total: nil, note: "Statutory holiday — skipped", entries: []),
                                Day(name: "Thu Aug 27", total: 9.0, note: nil, entries: [
                                    Entry(span: "9:00am–5:00pm", project: "Internal", task: "Development", hours: 8.0),
                                    Entry(span: "3:00pm–4:00pm", project: "Internal", task: "Internal Meetings", hours: 1.0),
                                ]),
                                Day(name: "Fri Aug 28", total: 9.0, note: nil, entries: [
                                    Entry(span: "9:00am–6:00pm", project: "ITC", task: "Development", hours: 9.0),
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
            MenuContent(model: model).onAppear { delegate.model = model; model.refresh() }
        } label: {
            MenuLabel(model: model)
        }
        Window("Harvest — This Week", id: "main") {
            MainWindow(model: model).onAppear { delegate.model = model }
        }.windowResizability(.contentSize)
        Window("Preferences", id: "prefs") {
            PreferencesView().onAppear { NSApp.activate(ignoringOtherApps: true) }
        }.windowResizability(.contentSize)
        Window("Welcome to Harvest Auto-Fill", id: "welcome") {
            OnboardingWindowHost()
        }.windowResizability(.contentSize)
        Window("What's New", id: "whatsnew") {
            WhatsNewView().onAppear { NSApp.activate(ignoringOtherApps: true) }
        }.windowResizability(.contentSize)
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
