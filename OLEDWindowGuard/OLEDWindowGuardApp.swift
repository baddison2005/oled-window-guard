import AppKit
import SwiftUI

@main
struct OLEDWindowGuardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        MenuBarExtra {
            GuardMenu(controller: delegate.controller, showWindow: delegate.showWindow)
        } label: {
            Image(systemName: "display.and.arrow.down")
                .accessibilityLabel("OLED Window Guard")
        }
        .menuBarExtraStyle(.window)
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let controller = GuardController()
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let duplicates = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0.processIdentifier != getpid() }
        if let other = duplicates.first, !ProcessInfo.processInfo.arguments.contains("--updated-relaunch") {
            other.activate()
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(controller.preferences.showsDockIcon ? .regular : .accessory)
        showWindow()
    }

    @objc func showWindow() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 780),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.title = "OLED Window Guard"
            window.titlebarAppearsTransparent = true
            window.minSize = NSSize(width: 920, height: 660)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: DashboardView().environmentObject(controller))
            window.setFrameAutosaveName("GuardDashboard")
            window.center()
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        for (title, action) in [("Open OLED Window Guard…", #selector(showWindow)),
                                (controller.running ? "Pause movement" : "Start movement", #selector(toggleGuarding)),
                                (controller.dimmingRunning ? "Pause dimming" : "Start dimming", #selector(toggleDimming)),
                                ("Restore brightness", #selector(restoreBrightness))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            if action == #selector(toggleGuarding) { item.isEnabled = !controller.busy && !controller.updateInProgress }
            if action == #selector(toggleDimming) { item.isEnabled = !controller.updateInProgress }
            item.target = self; menu.addItem(item)
        }
        menu.addItem(.separator())
        for (title, action, enabled) in [
            ("Move now…", #selector(moveNow), !controller.busy && !controller.warningActive && !controller.updateInProgress && controller.trusted),
            ("Restore last move…", #selector(restoreMove), controller.canUndo && !controller.busy && !controller.warningActive && !controller.updateInProgress),
            ("Dim monitor now — \(controller.manualDimmingDisplayName)", #selector(dimMonitorNow), controller.canDimMonitorNow)
        ] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self; item.isEnabled = enabled
            if action == #selector(moveNow) { item.toolTip = "Starts the advance warning, then applies the next safe move on the display selected in Overview." }
            if action == #selector(dimMonitorNow) { item.toolTip = "Immediately dims this display and its application windows using its display dimming level. Start dimming first." }
            menu.addItem(item)
        }
        menu.autoenablesItems = false
        return menu
    }
    @objc private func toggleGuarding() { controller.toggleRunning() }
    @objc private func toggleDimming() { controller.toggleDimming() }
    @objc private func restoreBrightness() { controller.restoreBrightness() }
    @objc private func moveNow() { controller.moveSoon() }
    @objc private func restoreMove() { controller.restoreLastMove() }
    @objc private func dimMonitorNow() { controller.dimMonitorNow() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

private struct GuardMenu: View {
    @ObservedObject var controller: GuardController
    let showWindow: () -> Void
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 14) {
            Label("OLED Window Guard", systemImage: "display").font(.headline)
            Text(controller.phaseTitle).foregroundStyle(.secondary)
            if controller.clock.deadline != nil {
                HStack { Text(controller.warningActive ? "Moving in" : "Next check"); Spacer(); Text(controller.countdown).monospacedDigit() }
            }
            Text(controller.status).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            GuardStatusLights(model: controller)
            Button(controller.running ? "Pause movement" : "Start movement") { controller.toggleRunning() }.disabled(controller.busy || controller.updateInProgress)
            Button(controller.dimmingRunning ? "Pause dimming" : "Start dimming") { controller.toggleDimming() }.disabled(controller.updateInProgress)
            if controller.warningActive { Button("Skip this move") { controller.skip() } }
            Button("Move after warning…") { controller.moveSoon() }.disabled(controller.busy || controller.warningActive)
            Button("Restore last move…") { controller.restoreLastMove() }.disabled(!controller.canUndo || controller.busy || controller.warningActive || controller.updateInProgress)
            Divider()
            Text("Default movement: \(controller.preferences.mode.title)").font(.caption.weight(.semibold))
            Picker("Movement type", selection: $controller.preferences.mode) {
                ForEach(MovementMode.allCases) { mode in Text(mode.title).tag(mode) }
            }.disabled(controller.busy || controller.updateInProgress)
            ForEach(controller.snapshot.displays) { display in
                DisclosureGroup(display.name) {
                    Toggle("Movement enabled", isOn: Binding(get: { controller.preferences.selectedDisplays.contains(display.id) }, set: { enabled in
                        if enabled { controller.preferences.selectedDisplays.insert(display.id) }
                        else { controller.preferences.selectedDisplays.remove(display.id) }
                    }))
                    Text(controller.movementSummary(for: display.id)).font(.caption)
                    DisplayMovementCard(display: display, groups: controller.groups, preferences: $controller.preferences)
                    Button("Preview on \(display.name)") {
                        controller.movementDisplayID = display.id; controller.showPreview(); showWindow()
                    }.disabled(!controller.preferences.selectedDisplays.contains(display.id))
                    Button("Move after warning on \(display.name)") {
                        controller.movementDisplayID = display.id; controller.moveSoon()
                    }.disabled(!controller.preferences.selectedDisplays.contains(display.id))
                }.disabled(controller.busy || controller.warningActive || controller.updateInProgress)
            }
            Toggle("Window dimming: \(controller.preferences.dimUnfocusedWindows ? "On" : "Off")", isOn: $controller.preferences.dimUnfocusedWindows)
            Toggle("Display dimming: \(controller.preferences.dimInactiveDisplays ? "On" : "Off")", isOn: $controller.preferences.dimInactiveDisplays)
            Text(controller.dimmingStatus).font(.caption).foregroundStyle(.secondary)
            Picker("Display for Dim monitor now", selection: $controller.dimmingDisplayID) {
                Text("First selected dimming display").tag("")
                ForEach(controller.snapshot.displays.filter { controller.preferences.dimmingDisplays.contains($0.id) }) { display in
                    Text(display.name).tag(display.id)
                }
            }
            Button("Dim monitor now — \(controller.manualDimmingDisplayName)") { controller.dimMonitorNow() }
                .disabled(!controller.canDimMonitorNow)
            Text("Start dimming first. Dims the selected monitor and its windows immediately at its display dimming level, skipping delays and fades. Interact on that monitor or Restore brightness to clear it. App exclusions and OWG controls stay bright.").font(.caption).foregroundStyle(.secondary)
            Button("Restore brightness · ⌃⌥⌘B") { controller.restoreBrightness() }
            Text("Dimming follows its own Start/Pause control and activation delays, independently of movement.").font(.caption).foregroundStyle(.secondary)
            Divider()
            Button("Open OLED Window Guard…", action: showWindow)
            Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q").disabled(controller.busy || controller.updateInProgress)
        }
        .padding(18)
        }.frame(width: 370, height: 650)
    }
}
