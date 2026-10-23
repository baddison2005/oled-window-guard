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
        controller.refresh()
        let menu = NSMenu()
        for (title, action) in [("Open OLED Window Guard…", #selector(showWindow)),
                                (controller.running ? "Pause movement" : "Start movement", #selector(toggleGuarding)),
                                (controller.dimmingRunning ? "Pause dimming" : "Start dimming", #selector(toggleDimming))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            if action == #selector(toggleGuarding) { item.isEnabled = !controller.busy && !controller.updateInProgress }
            if action == #selector(toggleDimming) { item.isEnabled = !controller.updateInProgress }
            item.target = self; menu.addItem(item)
        }
        appendMonitorCommands(to: menu, commands: controller.menuCommands)
        menu.autoenablesItems = false
        return menu
    }

    func appendMonitorCommands(to menu: NSMenu, commands: GuardMenuCommands) {
        func item(_ command: GuardMenuCommand) -> NSMenuItem {
            let item = NSMenuItem(title: command.title, action: #selector(performMonitorCommand(_:)), keyEquivalent: "")
            item.target = self; item.isEnabled = command.enabled
            item.toolTip = command.help; item.representedObject = command.id
            return item
        }
        func submenu(_ title: String, commands: [GuardMenuCommand], all: GuardMenuCommand? = nil) {
            let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let children = NSMenu(title: title)
            children.autoenablesItems = false
            for command in commands { children.addItem(item(command)) }
            if let all {
                if !commands.isEmpty { children.addItem(.separator()) }
                children.addItem(item(all))
            }
            parent.submenu = children
            parent.isEnabled = commands.contains(where: \.enabled) || all?.enabled == true
            menu.addItem(parent)
        }
        menu.addItem(item(commands.pauseAll))
        menu.addItem(.separator())
        submenu("Move now…", commands: commands.moves)
        submenu("Dim now", commands: commands.dims, all: commands.dimAll)
        submenu("Restore brightness", commands: commands.restores, all: commands.restoreAll)
        menu.addItem(item(commands.restoreLastMove))
    }

    @objc private func performMonitorCommand(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? GuardMenuCommand.Action else { return }
        controller.performMenuAction(action)
    }
    @objc private func toggleGuarding() { controller.toggleRunning() }
    @objc private func toggleDimming() { controller.toggleDimming() }

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
            MonitorCommandMenus(controller: controller)
            if controller.warningActive { Button("Skip this move") { controller.skip() } }
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
                }.disabled(controller.busy || controller.warningActive || controller.updateInProgress)
            }
            Toggle("Window dimming: \(controller.preferences.dimUnfocusedWindows ? "On" : "Off")", isOn: $controller.preferences.dimUnfocusedWindows)
            Toggle("Display dimming: \(controller.preferences.dimInactiveDisplays ? "On" : "Off")", isOn: $controller.preferences.dimInactiveDisplays)
            Text(controller.dimmingStatus).font(.caption).foregroundStyle(.secondary)
            Text("Dim now includes that monitor's windows at its display dimming level, skipping delays and fades. App exclusions and OWG controls stay bright. Restore brightness restarts delays on the chosen monitor; ⌃⌥⌘B restores all monitors.").font(.caption).foregroundStyle(.secondary)
            Text("Dimming follows its own Start/Pause control and activation delays, independently of movement.").font(.caption).foregroundStyle(.secondary)
            Divider()
            Button("Open OLED Window Guard…", action: showWindow)
            Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q").disabled(controller.busy || controller.updateInProgress)
        }
        .padding(18)
        }.frame(width: 370, height: 650)
        .onAppear { controller.refresh() }
    }
}

private struct MonitorCommandMenus: View {
    @ObservedObject var controller: GuardController
    private func commandButton(_ command: GuardMenuCommand) -> some View {
        Button(command.title) { controller.performMenuAction(command.id) }
            .disabled(!command.enabled).help(command.help)
    }
    var body: some View {
        let commands = controller.menuCommands
        commandButton(commands.pauseAll)
        Menu("Move now…") {
            ForEach(commands.moves) { commandButton($0) }
        }.disabled(!commands.moves.contains(where: \.enabled))
            .help("Choose a monitor with movement guarding running. Starts the warning before moving.")
        Menu("Dim now") {
            ForEach(commands.dims) { commandButton($0) }
            if !commands.dims.isEmpty { Divider() }
            commandButton(commands.dimAll)
        }.disabled(!commands.dimAll.enabled)
        Menu("Restore brightness") {
            ForEach(commands.restores) { commandButton($0) }
            if !commands.restores.isEmpty { Divider() }
            commandButton(commands.restoreAll)
        }.disabled(!commands.restoreAll.enabled)
        commandButton(commands.restoreLastMove)
    }
}
