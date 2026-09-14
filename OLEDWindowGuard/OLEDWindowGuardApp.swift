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
        showWindow()
    }

    func showWindow() {
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

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

private struct GuardMenu: View {
    @ObservedObject var controller: GuardController
    let showWindow: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("OLED Window Guard", systemImage: "display").font(.headline)
            Text(controller.phaseTitle).foregroundStyle(.secondary)
            if controller.clock.deadline != nil {
                HStack { Text(controller.warningActive ? "Moving in" : "Next check"); Spacer(); Text(controller.countdown).monospacedDigit() }
            }
            Text(controller.status).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            Button(controller.running ? "Pause guarding" : "Start guarding") { controller.toggleRunning() }.disabled(controller.busy)
            if controller.warningActive { Button("Skip this move") { controller.skip() } }
            Button("Move after warning…") { controller.moveSoon() }.disabled(controller.busy || controller.warningActive)
            Button("Restore last move…") { controller.restoreLastMove() }.disabled(!controller.canUndo || controller.busy)
            Divider()
            Button("Open OLED Window Guard…", action: showWindow)
            Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q").disabled(controller.busy || controller.updateInProgress)
        }
        .padding(18).frame(width: 310)
    }
}
