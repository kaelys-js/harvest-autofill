import AppKit
import CryptoKit
import IOKit.ps
import SwiftUI

// HarvestSideEffects — the subprocess / launchctl / filesystem-install methods, split
// out of HarvestCore so the library target measures only unit-testable logic. These are
// exercised by the app's E2E render/self-test hooks and visual regression, not unit tests.
// Compiled into the app by build.sh; NOT part of the HarvestCore library/coverage target.

@MainActor
final class WeekModel: ObservableObject {
    @Published var summary: Summary?
    @Published var refreshing = false
    @Published var lastRefresh: Date?
    @Published var firstRun = false
    private var timer: Timer?

    init() {
        firstRun = !FileManager.default.fileExists(atPath: P.setupMarker)
        load()
        refresh() // refresh on launch
        // The timer ticks every 15 min, but tick() decides whether to actually refresh — 15 min
        // on AC power, ~45 min on battery — so an idle menu-bar app isn't hitting three APIs
        // three times as often on battery. Opening a window always pulls fresh data (refreshIfStale).
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    // Power-aware background tick: refresh at most every ~15 min on AC, ~45 min on battery.
    private func tick() {
        let minGap: TimeInterval = onBattery() ? 2700 : 870 // 45 min vs ~15 min (< the 900s tick)
        if let last = lastRefresh, Date().timeIntervalSince(last) < minGap {
            return
        }
        refresh()
    }

    // Refresh only when the shown data is older than `maxAge` — called when a window appears, so
    // the user always sees a current week without a tight always-on background timer.
    func refreshIfStale(maxAge: TimeInterval = 300) {
        if let last = lastRefresh, Date().timeIntervalSince(last) < maxAge {
            return
        }
        refresh()
    }

    // Whether the Mac is running on battery (not plugged in). Used to back off background refreshes.
    private func onBattery() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return false }
        for src in list {
            if let info = IOPSGetPowerSourceDescription(blob, src)?.takeUnretainedValue() as? [String: Any],
               let state = info[kIOPSPowerSourceStateKey] as? String
            {
                return state == kIOPSBatteryPowerValue
            }
        }
        return false
    }

    func load() {
        if let d = try? Data(contentsOf: URL(fileURLWithPath: P.summary)),
           let s = try? JSONDecoder().decode(Summary.self, from: d)
        {
            summary = s
        }
    }

    func run(_ mode: String) {
        guard !refreshing else { return }
        refreshing = true
        Task.detached { [dir = P.dataDir, engine = P.engine] in
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = [engine, mode]; p.currentDirectoryURL = URL(fileURLWithPath: dir)
            try? p.run(); p.waitUntilExit()
            await MainActor.run { self.load(); self.refreshing = false; self.lastRefresh = Date() }
        }
    }

    func refresh() {
        run("dry")
    }

    func logNow() {
        run("write")
    }

    var menuTitle: String {
        guard let s = summary else { return "—" }
        return hrs(s.actualTotal) // completed hours only — today's projection isn't in the label
    }

    var menuHeadline: String {
        guard let s = summary else { return "Adding up this week…" }
        switch s.state {
        case "written": return "Logged to Harvest"
        case "dedup": return "This week is already logged"
        case "fail": return "This week needs a look"
        default: return "This week, so far"
        }
    }

    var menuDetail: String {
        guard let s = summary else { return "" }
        return s.detailLine
    }
}

extension Updater {
    func startAuto() {
        maybeShowWhatsNew()
        Task { try? await Task.sleep(nanoseconds: 8_000_000_000); self.check(manual: false) }
        timer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.check(manual: false) }
        }
    }

    func check(manual: Bool) {
        if case .downloading = state {
            return
        }
        if case .ready = state {
            return
        }
        state = .checking
        Task { await self.doCheck(manual: manual) }
    }

    private func doCheck(manual: Bool) async {
        do {
            let info = try await fetchLatest()
            if info.build > currentBuild {
                await download(info)
            } else {
                state = .upToDate
            }
        } catch { state = manual ? .failed(error.localizedDescription) : .idle }
    }

    private func download(_ info: UpdateInfo) async {
        state = .downloading
        do {
            let (zipData, _) = try await URLSession.shared.data(from: info.zip)
            let digest = SHA256.hash(data: zipData).map { String(format: "%02x", $0) }.joined()
            guard digest == info.sha256 else { throw UpdErr(m: "The download didn't match its verified fingerprint, so the update wasn't installed.") }
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("haf-update-\(info.build)")
            try? FileManager.default.removeItem(at: tmp)
            try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
            let zipPath = tmp.appendingPathComponent("app.zip"); try zipData.write(to: zipPath)
            let unzip = Process(); unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzip.arguments = ["-x", "-k", zipPath.path, tmp.path]; try unzip.run(); unzip.waitUntilExit()
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: tmp.path),
                  let appName = items.first(where: { $0.hasSuffix(".app") }) else { throw UpdErr(m: "The update didn't contain an app.") }
            let newApp = tmp.appendingPathComponent(appName).path
            let xq = Process(); xq.executableURL = URL(fileURLWithPath: "/usr/bin/xattr"); xq.arguments = ["-dr", "com.apple.quarantine", newApp]; try? xq.run(); xq.waitUntilExit()
            let cv = Process(); cv.executableURL = URL(fileURLWithPath: "/usr/bin/codesign"); cv.arguments = ["--verify", "--deep", "--strict", newApp]; try? cv.run(); cv.waitUntilExit()
            guard cv.terminationStatus == 0 else { throw UpdErr(m: "The update's code signature didn't check out, so the update wasn't installed.") }
            readyAppPath = newApp; state = .ready(info)
            if Prefs.autoUpdateEnabled() {
                installAndRelaunch()
            }
        } catch { state = .failed(error.localizedDescription) }
    }

    func installAndRelaunch() {
        guard let newApp = readyAppPath else { return }
        let target = Bundle.main.bundlePath
        let script = FileManager.default.temporaryDirectory.appendingPathComponent("haf-swap.sh").path
        let body = """
        #!/bin/bash
        NEW="$1"; TARGET="$2"
        for i in $(seq 1 120); do pgrep -f "$TARGET/Contents/MacOS/" >/dev/null || break; sleep 0.5; done
        rm -rf "$TARGET.new"; /usr/bin/ditto "$NEW" "$TARGET.new" || exit 1
        [ -d "$TARGET.new/Contents" ] || exit 1
        rm -rf "$TARGET.bak"; /bin/mv "$TARGET" "$TARGET.bak"
        if /bin/mv "$TARGET.new" "$TARGET"; then /usr/bin/xattr -dr com.apple.quarantine "$TARGET"; rm -rf "$TARGET.bak"; else /bin/mv "$TARGET.bak" "$TARGET"; fi
        /usr/bin/open "$TARGET"
        rm -rf "$(dirname "$NEW")"
        """
        try? body.write(toFile: script, atomically: true, encoding: .utf8)
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", "nohup /bin/bash '\(script)' '\(newApp)' '\(target)' >/tmp/haf-update.log 2>&1 &"]
        try? p.run(); p.waitUntilExit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { NSApp.terminate(nil) }
    }
}

extension Prefs {
    func save() {
        writeAll(); markComplete(); syncAgents(); status = "Saved ✓"
    }

    // Destructive: wipe config + all secret env files + the setup marker, then re-seed a blank
    // template so the engine still has a config. Returns the app to first-run onboarding.
    func resetAll() {
        removeAgents()
        for f in [P.config, P.harvestEnv, P.calEnv, P.adoEnv, P.githubEnv, P.setupMarker] {
            try? FileManager.default.removeItem(atPath: f)
        }
        if FileManager.default.fileExists(atPath: P.configDefault) {
            try? FileManager.default.copyItem(atPath: P.configDefault, toPath: P.config)
        }
        harvestTest = .idle; discovered = false; preview = nil
        load()
        status = ""
    }

    private func laPath(_ label: String) -> String {
        NSHomeDirectory() + "/Library/LaunchAgents/\(label).plist"
    }

    private func launchctl(_ args: [String]) {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/launchctl"); p.arguments = args
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try? p.run(); p.waitUntilExit()
    }

    private func installPlist(_ label: String, _ xml: String) {
        let dir = NSHomeDirectory() + "/Library/LaunchAgents"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = laPath(label)
        try? xml.write(toFile: path, atomically: true, encoding: .utf8)
        let uid = String(getuid())
        launchctl(["bootout", "gui/\(uid)/\(label)"]) // idempotent: clear any prior instance
        launchctl(["bootstrap", "gui/\(uid)", path])
    }

    private func uninstallPlist(_ label: String) {
        launchctl(["bootout", "gui/\(String(getuid()))/\(label)"])
        try? FileManager.default.removeItem(atPath: laPath(label))
    }

    // Install the login-launch agent always; the Friday agent only when auto-log is enabled.
    func syncAgents() {
        let app = Bundle.main.bundlePath
        let logs = P.dataDir + "/logs"
        let login = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>Label</key><string>\(Self.loginLabel)</string>
          <key>ProgramArguments</key><array><string>/usr/bin/open</string><string>-a</string><string>\(app)</string></array>
          <key>RunAtLoad</key><true/>
        </dict></plist>
        """
        installPlist(Self.loginLabel, login)
        if autoRecord {
            let weekly = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict>
              <key>Label</key><string>\(Self.weeklyLabel)</string>
              <key>ProgramArguments</key><array><string>/bin/bash</string><string>\(P.engine)</string><string>auto</string></array>
              <key>StartCalendarInterval</key><dict><key>Weekday</key><integer>5</integer><key>Hour</key><integer>18</integer><key>Minute</key><integer>0</integer></dict>
              <key>RunAtLoad</key><false/>
              <key>StandardOutPath</key><string>\(logs)/launchd.out</string>
              <key>StandardErrorPath</key><string>\(logs)/launchd.err</string>
            </dict></plist>
            """
            installPlist(Self.weeklyLabel, weekly)
        } else {
            uninstallPlist(Self.weeklyLabel)
        }
    }

    func removeAgents() {
        uninstallPlist(Self.weeklyLabel); uninstallPlist(Self.loginLabel)
    }

    func runPreview() {
        writeAll()
        previewing = true; preview = nil
        Task.detached { [dir = P.dataDir, engine = P.engine] in
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = [engine, "dry"]; p.currentDirectoryURL = URL(fileURLWithPath: dir)
            try? p.run(); p.waitUntilExit()
            let sum = (try? Data(contentsOf: URL(fileURLWithPath: P.summary)))
                .flatMap { try? JSONDecoder().decode(Summary.self, from: $0) }
            await MainActor.run { self.preview = sum; self.previewing = false }
        }
    }

    func logThisWeek() {
        writeAll(); logging = true
        Task.detached { [dir = P.dataDir, engine = P.engine] in
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/bash")
            p.arguments = [engine, "write"]; p.currentDirectoryURL = URL(fileURLWithPath: dir)
            try? p.run(); p.waitUntilExit()
            let sum = (try? Data(contentsOf: URL(fileURLWithPath: P.summary)))
                .flatMap { try? JSONDecoder().decode(Summary.self, from: $0) }
            await MainActor.run { self.preview = sum; self.logging = false }
        }
    }

    // Ask the GitHub CLI whether it's signed in (a token comes back on success). Drives whether
    // the GitHub token field is shown — when gh is signed in, the app reads commits through it and
    // the field is hidden as redundant. Runs off the main thread; publishes back on it.
    func checkGhAuth() {
        Task.detached {
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/bash")
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = NSHomeDirectory() + "/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            p.environment = env
            p.arguments = ["-c", "gh auth token"]
            let pipe = Pipe(); p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
            try? p.run(); p.waitUntilExit()
            let out = pipe.fileHandleForReading.readDataToEndOfFile()
            let signedIn = p.terminationStatus == 0 && !out.isEmpty
            await MainActor.run { self.ghSignedIn = signedIn }
        }
    }

    func discover() {
        status = "Scanning…"; discovering = true
        Task.detached { [account = harvestAccount, token = harvestToken, aorg = adoOrg, aproj = adoProject, apat = adoPAT, ght = ghToken, py = P.python, disc = P.discover] in
            let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/bash")
            var env = ProcessInfo.processInfo.environment
            env["HARVEST_ACCOUNT_ID"] = account; env["HARVEST_ACCESS_TOKEN"] = token
            env["ADO_ORG"] = aorg; env["ADO_PROJECT"] = aproj; env["ADO_PAT"] = apat
            if !ght.isEmpty {
                env["GITHUB_TOKEN"] = ght
            }
            env["PYTHONDONTWRITEBYTECODE"] = "1" // keep the signed bundle immutable at runtime
            env["PATH"] = NSHomeDirectory() + "/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            p.environment = env
            // Pasted token wins; else fall back to the gh CLI. Run through the bundled Python.
            p.arguments = ["-c", "export GITHUB_TOKEN=\"${GITHUB_TOKEN:-$(gh auth token 2>/dev/null)}\"; '\(py)' '\(disc)'"]
            let pipe = Pipe(); p.standardOutput = pipe
            try? p.run(); p.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            await MainActor.run {
                self.discovering = false
                guard let o = obj else { self.status = "Scan failed — check your Harvest account ID and token"; return }
                self.discovered = true
                if let hv = o["harvest"] as? [String: Any] {
                    self.harvestUser = String(describing: hv["user_id"] ?? "")
                    self.harvestName = (hv["name"] as? String) ?? ""
                }
                if let gh = o["github"] as? [String: Any] {
                    if let l = gh["login"] as? String, !l.isEmpty {
                        self.ghLogin = l
                    }
                    if let orgs = gh["orgs"] as? [String] {
                        self.ghOrgsAvailable = orgs; if self.ghOrgs.isEmpty {
                            self.ghOrgs = orgs.joined(separator: ", ")
                        }
                    }
                }
                if let ado = o["azure_devops"] as? [String: Any] {
                    if let projects = ado["projects"] as? [String] {
                        self.adoProjectsAvailable = projects
                    }
                    if let repos = ado["repos"] as? [String] {
                        self.adoReposAvailable = repos
                    }
                }
                if let pr = o["harvest_projects"] as? [String: Any] {
                    self.projectsList = pr.compactMap { k, v in (v as? [String: Any]).map { (k, String(describing: $0["project_id"] ?? "")) } }.sorted { $0.0 < $1.0 }
                }
                self.status = "Found your projects, orgs, and repos ✓. Pick the ones to include below."
            }
        }
    }
}
