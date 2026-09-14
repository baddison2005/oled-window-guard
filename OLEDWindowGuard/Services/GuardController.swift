import AppKit
import Combine
import ServiceManagement

@MainActor
final class GuardController: ObservableObject {
    @Published var preferences: Preferences {
        didSet {
            guard preferences != oldValue else { return }
            if preferences.mode != oldValue.mode || preferences.groupID != oldValue.groupID || preferences.rotateGroup != oldValue.rotateGroup {
                anchors.removeAll()
            }
            cancelPending(message: "Settings saved. The next interval starts now.")
            savePreferences()
            if preferences.layoutSource != oldValue.layoutSource {
                anchors.removeAll()
                refreshGroups()
            }
        }
    }
    @Published private(set) var snapshot = DesktopSnapshot(displays: [], windows: [])
    @Published private(set) var groups: [ImportedGroup] = []
    @Published private(set) var integrationStatus = "Checking Window Layouts…"
    @Published private(set) var status = "Choose your displays, then start guarding."
    @Published private(set) var running = false
    @Published private(set) var trusted = false
    @Published private(set) var busy = false
    @Published var updateInProgress = false
    @Published private(set) var clock = MovementClock()
    @Published private(set) var now = Date()
    @Published private(set) var lastMove: Date?
    @Published private(set) var movedCount = 0
    @Published private(set) var canUndo = false
    @Published private(set) var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var preview: MovementPlan?
    private let desktop = DesktopService()
    private let warnings = WarningPresenter()
    private let activity = DisplayActivityMonitor()
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var pending: (plan: MovementPlan, baseline: DesktopSnapshot, handles: [String: DesktopService.Handle], isRestore: Bool)?
    private var pendingGroup: ImportedGroup?
    private var activeLayoutSource: LayoutSource?
    private var pendingLayoutSource: LayoutSource?
    private var undo: (MovementPlan, DesktopSnapshot, [String: DesktopService.Handle])?
    private var anchors: [String: WindowAnchor] = [:]
    private var suspended = false
    private var generation = 0
    private var applyingTask: Task<Void, Never>?
    private let settingsURL: URL

    init() {
        settingsURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OLED Window Guard/settings.json")
        var loadWarning: String?
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            do { preferences = try JSONDecoder().decode(Preferences.self, from: Data(contentsOf: settingsURL)).validated() }
            catch { preferences = Preferences(); loadWarning = "Saved settings could not be read. Safe defaults are active; the original file is untouched until you change a setting." }
        } else { preferences = Preferences() }
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
        activity.start()
        refresh()
        refreshGroups()
        if let loadWarning { status = loadWarning }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.suspend() }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.resumeAfterSystemChange() }
            })
        }
        observers.append(workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.cancelPending(message: "Space changed. A fresh interval starts now.") }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.anchors.removeAll()
                self?.cancelPending(message: "Display configuration changed. A fresh interval starts now.")
                self?.refresh()
            }
        })
    }

    var phaseTitle: String {
        if suspended { return "Sleeping" }
        if busy { return "Moving windows" }
        if case .warning = clock.phase { return "Move approaching" }
        return running ? "Guarding your workspace" : "Ready when you are"
    }
    var countdown: String {
        guard let deadline = clock.deadline else { return "—" }
        let seconds = max(0, Int(ceil(deadline.timeIntervalSince(now))))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    var warningActive: Bool { if case .warning = clock.phase { true } else { false } }
    var selectedGroup: ImportedGroup? { groups.first { $0.id == preferences.groupID } }

    func refresh() {
        guard !busy else { return }
        trusted = desktop.trusted
        snapshot = desktop.snapshot()
        let ids = Set(snapshot.windows.map(\.id))
        anchors = anchors.filter { ids.contains($0.key) }
        for window in snapshot.windows {
            if let previous = anchors[window.id], Geometry.close(previous.lastFrame, window.frame) { continue }
            anchors[window.id] = WindowAnchor(originFrame: window.frame, lastFrame: window.frame)
        }
    }

    func grantAccessibility() { desktop.requestPermission(); trusted = desktop.trusted }

    func refreshGroups() {
        groups = []
        activeLayoutSource = nil
        let choices: [LayoutSource] = [.standard, .experimental]
        let installed = Set(choices.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) != nil })
        let running = Set(choices.filter { !NSRunningApplication.runningApplications(withBundleIdentifier: $0.bundleID).isEmpty })
        guard let source = LayoutSource.resolve(preferences.layoutSource, installed: installed, running: running) else {
            integrationStatus = installed.union(running).isEmpty ? "Window Layouts is not installed."
                : preferences.layoutSource == .automatic ? "Choose a layout source below: both versions are installed and no single running version can be selected."
                : "The selected Window Layouts version is not installed. Choose another source."
            return
        }
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(source.libraryDirectory).appendingPathComponent("layout-library.json")
        do {
            let data = try Data(contentsOf: url)
            let custom = try LayoutGroupReader.decode(data)
            let library = try JSONDecoder().decode(LayoutGroupReader.Library.self, from: data)
            groups = LayoutGroupReader.builtInGroups(padding: library.layoutPadding ?? 0) + custom
            activeLayoutSource = source
            integrationStatus = "\(source.title) · Padding: \((library.layoutPadding ?? 0).formatted()) logical points · 6 built-in groups · \(custom.count) custom groups · read-only access"
        } catch {
            integrationStatus = "\(source.title): library could not be read. Group movement is unavailable until it can be loaded; padding has not been replaced with zero. \(error.localizedDescription)"
        }
    }

    func toggleRunning() {
        if running { running = false; cancelPending(message: "Paused. Windows stay where they are."); return }
        refresh()
        guard ready() else { return }
        running = true
        clock.start(now: Date(), interval: preferences.intervalMinutes * 60)
        status = "Guarding selected displays. You’ll receive a warning before each move."
    }

    func showPreview() {
        refresh()
        refreshGroups()
        var rng = SystemRandomNumberGenerator()
        preview = MovementPlanner().plan(snapshot: snapshot, preferences: preferences.validated(), anchors: anchors, group: selectedGroup, rng: &rng)
        status = preview?.reason ?? ""
    }

    func moveSoon() {
        guard !busy else { return }
        refresh()
        guard ready() else { return }
        beginWarning()
    }

    func skip() { cancelPending(message: "Move skipped. The next interval starts now.") }

    func restoreLastMove() {
        guard !busy, !updateInProgress, let undo else { return }
        refresh()
        let ids = Set(undo.0.moves.map(\.windowID))
        let affectedDisplays = Set(undo.1.displays.map(\.id))
        let current = snapshot.restricted(to: affectedDisplays)
        guard SnapshotValidation.unchanged(undo.1, current, moving: ids, avoidFocused: preferences.avoidFocusedWindow) else {
            self.undo = nil; canUndo = false
            status = "Restore cancelled because the desktop changed. Manually moved windows are never pulled back."
            return
        }
        queueWarning(plan: undo.0, baseline: current, handles: undo.2, isRestore: true)
        self.undo = nil; canUndo = false
    }

    func setNotifications(_ enabled: Bool) {
        if !enabled { preferences.systemNotifications = false; return }
        Task {
            let allowed = await warnings.requestNotifications()
            preferences.systemNotifications = allowed
            if !allowed { status = "System notifications are disabled. On-screen advance warnings remain available." }
        }
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if SMAppService.mainApp.status == .requiresApproval { status = "Allow OLED Window Guard in System Settings → General → Login Items." }
        } catch { status = "Login setting could not be changed: \(error.localizedDescription)" }
    }

    private func ready() -> Bool {
        guard !updateInProgress else { status = "Guarding is paused while the update installs."; return false }
        guard trusted else { status = "Grant Accessibility access to discover and move windows."; return false }
        guard snapshot.displays.contains(where: { preferences.selectedDisplays.contains($0.id) }) else {
            status = "Select at least one connected display."; return false
        }
        guard preferences.mode != .group || selectedGroup != nil else { status = "Select a saved Window Layouts group."; return false }
        guard !suspended else { status = "Waiting for an active desktop."; return false }
        return true
    }

    private func tick() {
        now = Date()
        trusted = desktop.trusted
        if !trusted && (running || warningActive) {
            running = false
            cancelPending(message: "Accessibility access was removed. Guarding has paused.")
        }
        guard !busy, !suspended, clock.isDue(now: now) else { return }
        if case .warning = clock.phase { executePending() }
        else if running {
            beginWarning()
        }
    }

    private func positionsAreSafe(_ snapshot: DesktopSnapshot, ids: Set<String>, sourceRounding: Bool = false) -> Bool {
        let regions: [String: [CGRect]] = preferences.mode == .group
            ? Dictionary(uniqueKeysWithValues: snapshot.displays.map { ($0.id, selectedGroup?.frames(on: $0) ?? []) }) : [:]
        return SnapshotValidation.safePositions(snapshot, moving: ids, regions: regions, sourceRounding: sourceRounding,
                                                sourceAllowance: GroupPaddingPolicy.sourceAllowance(selectedGroup?.padding ?? 0))
    }

    private func handlesMatch(_ snapshot: DesktopSnapshot, ids: Set<String>, handles: [String: DesktopService.Handle]) -> Bool {
        ids.allSatisfy { id in
            guard let expected = snapshot.windows.first(where: { $0.id == id }),
                  let handle = handles[id], let observed = desktop.frame(handle.element) else { return false }
            return Geometry.close(expected.frame, observed)
        }
    }

    private func userIsQuiet(on displays: Set<String>) -> Bool {
        activity.isQuiet(on: displays, seconds: preferences.quietSeconds)
    }

    private func beginWarning() {
        warnings.dismiss()
        refresh(); refreshGroups()
        guard ready() else { cancelPending(message: status); return }
        var rng = SystemRandomNumberGenerator()
        let plan = MovementPlanner().plan(snapshot: snapshot, preferences: preferences.validated(), anchors: anchors, group: selectedGroup, rng: &rng)
        preview = plan
        guard !plan.moves.isEmpty else { cancelPending(message: plan.reason); return }
        queueWarning(plan: plan, baseline: snapshot, handles: desktop.handles)
    }

    private func queueWarning(plan: MovementPlan, baseline: DesktopSnapshot, handles: [String: DesktopService.Handle], isRestore: Bool = false) {
        generation += 1
        let affectedDisplays = Set(plan.moves.compactMap { move in
            baseline.windows.first(where: { $0.id == move.windowID })?.displayID
        })
        let scopedBaseline = baseline.restricted(to: affectedDisplays)
        pending = (plan, scopedBaseline, handles, isRestore)
        pendingGroup = selectedGroup
        pendingLayoutSource = activeLayoutSource
        clock.warn(now: Date(), seconds: preferences.warningSeconds)
        status = isRestore
            ? "\(plan.windowCount) windows will return to their previous positions after the warning. Skip at any time."
            : "\(plan.windowCount) windows will move after the warning. Skip at any time."
        status += " " + ActivityPolicy.explanation(quietSeconds: preferences.quietSeconds)
        warnings.show(count: plan.windowCount, seconds: Int(preferences.warningSeconds), displays: affectedDisplays,
                      quietSeconds: preferences.quietSeconds,
                      sound: preferences.soundEnabled, notify: preferences.systemNotifications) { [weak self] in self?.skip() }
    }

    private func executePending() {
        guard let pending else { cancelPending(message: "No pending move."); return }
        self.pending = nil
        let affectedDisplays = Set(pending.baseline.displays.map(\.id))
        let quietAtDeadline = userIsQuiet(on: affectedDisplays)
        let warningWindowNumbers = warnings.dismiss()
        busy = true
        clock.applying()
        let token = generation
        applyingTask = Task { [weak self] in
            guard let self else { return }
            // Let the warning panels leave the WindowServer list before revalidation.
            try? await Task.sleep(for: .milliseconds(180))
            let fresh = desktop.snapshot(excludingOwnWindowNumbers: warningWindowNumbers)
                .restricted(to: affectedDisplays)
            let expectedGroup = pendingGroup
            if preferences.mode == .group { refreshGroups() }
            let ids = Set(pending.plan.moves.map(\.windowID))
            guard token == generation, !suspended, quietAtDeadline, userIsQuiet(on: affectedDisplays), desktop.trusted,
                  preferences.mode != .group || (expectedGroup == selectedGroup && pendingLayoutSource == activeLayoutSource),
                  positionsAreSafe(fresh, ids: ids, sourceRounding: true),
                  SnapshotValidation.unchanged(pending.baseline, fresh, moving: ids, avoidFocused: preferences.avoidFocusedWindow),
                  ids.allSatisfy({ id in
                      guard let old = pending.handles[id], let current = self.desktop.handles[id] else { return false }
                      return old.pid == current.pid && CFEqual(old.element, current.element)
                  }) else {
                let detail: String
                if !desktop.trusted { detail = "Accessibility permission is unavailable." }
                else if token != generation || suspended { detail = "The pending move was cancelled or the desktop became inactive." }
                else if !quietAtDeadline || !userIsQuiet(on: affectedDisplays) {
                    detail = "Recent activity prevented \(preferences.quietSeconds.formatted()) seconds of quiet before movement."
                }
                else if let change = SnapshotValidation.changeDescription(pending.baseline, fresh, moving: ids, avoidFocused: preferences.avoidFocusedWindow) { detail = change }
                else if preferences.mode == .group && (expectedGroup != selectedGroup || pendingLayoutSource != activeLayoutSource) { detail = "The layout source, selected group or padding changed." }
                else { detail = "A planned window no longer has a safe position or a matching Accessibility reference." }
                finish(message: "Move cancelled. \(detail)")
                if token == generation, !suspended, (!quietAtDeadline || !userIsQuiet(on: affectedDisplays)) {
                    warnings.showCancellation(message: "Move cancelled. \(detail)", displays: affectedDisplays,
                                              notify: preferences.systemNotifications)
                }
                return
            }
            var expected = fresh
            var completed: [Move] = []
            for step in pending.plan.steps {
                let check = desktop.snapshot(excludingOwnWindowNumbers: warningWindowNumbers)
                    .restricted(to: affectedDisplays)
                let ignoredEligibility = preferences.permitsIntermediateOverlap ? ids : []
                guard token == generation, !suspended, userIsQuiet(on: affectedDisplays),
                      SnapshotValidation.unchanged(expected, check, moving: ids, avoidFocused: preferences.avoidFocusedWindow,
                                                   ignoringEligibilityFor: ignoredEligibility),
                      handlesMatch(expected, ids: ids, handles: pending.handles),
                      preferences.permitsIntermediateOverlap || positionsAreSafe(check, ids: ids),
                      let handle = pending.handles[step.windowID] else {
                    await failAndRecover(completed, handles: pending.handles, detail: SnapshotValidation.changeDescription(expected, check, moving: ids, avoidFocused: preferences.avoidFocusedWindow) ?? "Activity or Accessibility references changed during placement.")
                    return
                }
                completed.append(step)
                _ = desktop.move(handle, to: step.to, permitsRoundingResize: step.permitsRoundingResize, roundingResizeLimit: step.roundingResizeLimit)
                // Allow the visible frame to settle before validating recovery.
            try? await Task.sleep(for: .milliseconds(450))
                // Some apps apply only one size dimension on the first AX write.
                // Record the exact partial change and retry once, only while the
                // whole affected desktop and user activity still match expectations.
                if let partial = desktop.frame(handle.element), !Geometry.close(partial, step.to), step.acceptsPartialResize(partial) {
                    let actual = Move(windowID: step.windowID, from: step.from, to: partial, permitsRoundingResize: true,
                                      roundingResizeLimit: step.roundingResizeLimit)
                    completed[completed.count - 1] = actual
                    var intermediate = expected
                    intermediate.windows = MovementPlanner.applying([actual], to: expected.windows)
                    let live = desktop.snapshot(excludingOwnWindowNumbers: warningWindowNumbers).restricted(to: affectedDisplays)
                    if token == generation, !suspended, userIsQuiet(on: affectedDisplays),
                       SnapshotValidation.unchanged(intermediate, live, moving: ids, avoidFocused: preferences.avoidFocusedWindow,
                                                    ignoringEligibilityFor: ignoredEligibility),
                       handlesMatch(intermediate, ids: ids, handles: pending.handles) {
                        let retry = Move(windowID: step.windowID, from: partial, to: step.to, permitsRoundingResize: true,
                                         roundingResizeLimit: step.roundingResizeLimit)
                        completed.append(retry)
                        _ = desktop.move(handle, to: retry.to, permitsRoundingResize: true, roundingResizeLimit: retry.roundingResizeLimit)
                        // Allow the visible frame to settle before the next validation.
                        try? await Task.sleep(for: .milliseconds(450))
                        if let observed = desktop.frame(handle.element), retry.acceptsPartialResize(observed) {
                            completed[completed.count - 1] = Move(windowID: retry.windowID, from: retry.from, to: observed,
                                permitsRoundingResize: true, roundingResizeLimit: retry.roundingResizeLimit)
                        }
                    }
                }
                guard let observed = desktop.frame(handle.element), Geometry.close(observed, step.to) else {
                    await failAndRecover(completed, handles: pending.handles, detail: "\(expected.windows.first(where: { $0.id == step.windowID })?.appName ?? "An application") did not accept its requested position or size.")
                    return
                }
                expected.windows = MovementPlanner.applying([step], to: expected.windows)
            }
            // A second settling check catches applications that asynchronously constrain a requested position.
            try? await Task.sleep(for: .milliseconds(250))
            let after = desktop.snapshot(excludingOwnWindowNumbers: warningWindowNumbers)
                .restricted(to: affectedDisplays)
            guard token == generation, SnapshotValidation.unchanged(expected, after, moving: ids, avoidFocused: preferences.avoidFocusedWindow),
                  positionsAreSafe(after, ids: ids, sourceRounding: pending.isRestore) else {
                await failAndRecover(completed, handles: pending.handles, detail: SnapshotValidation.changeDescription(expected, after, moving: ids, avoidFocused: preferences.avoidFocusedWindow) ?? "Final positions did not pass the safety check."); return
            }
            for move in pending.plan.moves {
                if var anchor = anchors[move.windowID] { anchor.previousFrame = move.from; anchor.lastFrame = move.to; anchors[move.windowID] = anchor }
            }
            if pending.isRestore {
                undo = nil
                canUndo = false
            } else {
                let inverse = MovementPlan(moves: pending.plan.moves.map(\.reversed),
                                           steps: completed.reversed().map(\.reversed), reason: "Restore last move")
                undo = (inverse, after, pending.handles)
                canUndo = true
            }
            lastMove = Date()
            movedCount += pending.plan.windowCount
            let verb = pending.isRestore ? "Restored" : "Moved"
            let destination = pending.isRestore ? "original" : "final"
            finish(message: "\(verb) \(pending.plan.windowCount) windows. All \(destination) positions verified.")
        }
    }

    private func failAndRecover(_ completed: [Move], handles: [String: DesktopService.Handle], detail: String) async {
        running = false
        var restored = true
        for step in completed.reversed() {
            let live = desktop.snapshot()
            if let handle = handles[step.windowID], desktop.frame(handle.element).map({ Geometry.close($0, step.from) }) == true { continue }
            guard !suspended, NSEvent.pressedMouseButtons == 0,
                  let handle = handles[step.windowID],
                  desktop.frame(handle.element).map({ Geometry.close($0, step.to) }) == true,
                  live.displays.contains(where: { Geometry.contains($0.usableFrame, step.from) }),
                  (preferences.permitsIntermediateOverlap
                   || !live.windows.contains(where: { $0.id != step.windowID && Geometry.overlaps($0.frame, step.from) })),
                  desktop.move(handle, to: step.from, permitsRoundingResize: step.permitsRoundingResize, roundingResizeLimit: step.roundingResizeLimit) else { restored = false; continue }
            // Allow the visible frame to settle before validating recovery.
            try? await Task.sleep(for: .milliseconds(450))
            if desktop.frame(handle.element).map({ Geometry.close($0, step.from) }) != true { restored = false }
        }
        undo = nil; canUndo = false
        finish(message: restored ? "Guarding paused: \(detail) Completed steps were restored."
               : "Guarding paused: \(detail) Some positions could not be safely restored; please check your windows.")
    }

    private func finish(message: String) {
        busy = false
        applyingTask = nil
        refresh()
        status = message
        if running && !suspended { clock.start(now: Date(), interval: preferences.intervalMinutes * 60) } else { clock.stop() }
    }

    private func cancelPending(message: String) {
        generation += 1
        pending = nil
        preview = nil
        warnings.dismiss()
        if !busy {
            if running && !suspended { clock.start(now: Date(), interval: preferences.intervalMinutes * 60) }
            else { clock.stop() }
        }
        status = message
    }

    private func suspend() { suspended = true; cancelPending(message: "Guarding is suspended while the desktop is inactive.") }
    private func resumeAfterSystemChange() {
        suspended = false
        anchors.removeAll()
        cancelPending(message: "Desktop active. A fresh interval starts now.")
        refresh()
    }

    private func savePreferences() {
        do {
            try FileManager.default.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(preferences.validated()).write(to: settingsURL, options: .atomic)
        } catch { status = "Settings could not be saved: \(error.localizedDescription)" }
    }
}
