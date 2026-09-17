import AppKit
import ApplicationServices

@MainActor
final class DimmingPresenter {
    static private(set) var windowNumbers: Set<CGWindowID> = []
    private var panels: [String: NSPanel] = [:]
    private let desktop = DesktopService()
    private(set) var animating = false
    private var runtimes: [String: DisplayDimmingRuntime] = [:]
    private var brightnessRestore = BrightnessRestore()
    private var lastFocus: CGRect?
    private var interaction = DimmingInteractionScope()
    private var spaceTransitionActive = false
    private var globalClicks: Any?
    private var localClicks: Any?
    init() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
        globalClicks = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.recordInteraction(event) }
        }
        localClicks = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.recordInteraction(event) }; return event
        }
    }
    private func recordInteraction(_ event: NSEvent) {
        if event.type == .keyDown {
            // Capture Space navigation before transient Finder focus can reset timers.
            if event.modifierFlags.contains(.control) && [123, 124].contains(event.keyCode) { spaceChanged() }
            else if !event.modifierFlags.contains(.control) { interaction.windowInteraction() }
            return
        }
        guard let point = event.cgEvent?.location,
              let display = desktop.displays().first(where: { $0.frame.contains(point) }),
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
        let hitWindow = list.contains { item in
            guard let id = (item[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  !Self.windowNumbers.contains(id),
                  (item[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let layer = item[kCGWindowLayer as String] as? Int, layer >= 0,
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
            return frame.contains(point) && !DimmingInteractionScope.isDesktopSurface(owner: item[kCGWindowOwnerName as String] as? String, layer: layer, frame: frame, displays: [display.frame])
        }
        if hitWindow { interaction.windowInteraction() }
        else { interaction.desktopClicked(on: display.frame) }
    }
    func spaceChanged() {
        guard let point = CGEvent(source: nil)?.location,
              let display = desktop.displays().first(where: { $0.frame.contains(point) }) else { return }
        interaction.spaceChanged(on: display.frame)
    }
    func restoreBrightness() {
        hide()
        brightnessRestore.restore(now: ProcessInfo.processInfo.systemUptime)
    }
    func hide() {
        runtimes.removeAll(); animating = false
        for panel in panels.values { panel.orderOut(nil) }
    }
    func update(preferences p: Preferences, active: Bool) -> String {
        guard p.dimUnfocusedWindows || p.dimInactiveDisplays else { hide(); return "Dimming is off." }
        guard active, AXIsProcessTrusted() else { hide(); return "Dimming is suspended while inactive, updating or awaiting Accessibility access." }
        guard let front = NSWorkspace.shared.frontmostApplication else { return "Keeping dimming while desktop focus changes." }
        var focused: CGRect?
        if front.processIdentifier == getpid() {
            if let window = NSApp.keyWindow, let top = NSScreen.screens.first?.frame.maxY {
                focused = Geometry.axRect(window.frame, primaryTop: top)
            }
        } else {
            let app = AXUIElementCreateApplication(front.processIdentifier)
            AXUIElementSetMessagingTimeout(app, 0.1)
            var value: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value)
            if error == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() {
                let window = unsafeBitCast(value, to: AXUIElement.self)
                AXUIElementSetMessagingTimeout(window, 0.1)
                focused = desktop.frame(window)
                // Missing focus is scoped to the last interacted display.
            }
        }
        guard let rawList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let top = NSScreen.screens.first?.frame.maxY else { return "Keeping dimming while visible windows refresh." }
        let displays = desktop.displays()
        // Dock's moving Space snapshots arrive before the workspace notification.
        // Anchor focus now, before Finder can report a stale window on another screen.
        let transitioning = rawList.contains { item in
            guard item[kCGWindowLayer as String] as? Int == 4,
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return false }
            return DimmingInteractionScope.isDesktopSurface(owner: item[kCGWindowOwnerName as String] as? String,
                layer: 4, frame: frame, displays: displays.map(\.frame))
        }
        if transitioning && !spaceTransitionActive { spaceChanged() }
        spaceTransitionActive = transitioning
        let list = rawList.filter { item in
            guard let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return true }
            return !DimmingInteractionScope.isDesktopSurface(owner: item[kCGWindowOwnerName as String] as? String,
                layer: item[kCGWindowLayer as String] as? Int ?? 0, frame: frame, displays: displays.map(\.frame))
        }
        let now = ProcessInfo.processInfo.systemUptime
        focused = DimmingInteractionScope.applicationFocus(reported: focused,
            isFinder: front.bundleIdentifier == "com.apple.finder",
            visibleFinderWindows: list.compactMap { item in
                guard (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == front.processIdentifier,
                      item[kCGWindowLayer as String] as? Int == 0,
                      let bounds = item[kCGWindowBounds as String] as? [String: Any] else { return nil }
                return CGRect(dictionaryRepresentation: bounds as CFDictionary)
            })
        let resolved = interaction.resolve(reported: focused, fallback: lastFocus)
        focused = resolved.focused
        if let current = focused { lastFocus = current }
        let scope = resolved.scope
        let desktopScope = focused == nil ? scope : nil
        let restoring = brightnessRestore.isActive(now: now)
        let excludedPIDs = Set(NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier.map { p.dimmingExclusions.contains($0) } ?? false
        }.map(\.processIdentifier))
        animating = false
        let ids = Set(displays.map(\.id))
        runtimes = runtimes.filter { ids.contains($0.key) }
        for id in Array(panels.keys) where !ids.contains(id) {
            if let panel = panels.removeValue(forKey: id) {
                Self.windowNumbers.remove(CGWindowID(panel.windowNumber)); panel.close()
            }
        }
        for display in displays {
            guard p.dimmingDisplays.contains(display.id) else { panels[display.id]?.orderOut(nil); runtimes[display.id] = nil; continue }
            let settings = p.dimmingSettings(for: display.id)
            var runtime = runtimes[display.id] ?? DisplayDimmingRuntime()
            let eligibleWindows = Set(list.compactMap { item -> String? in
                guard settings.windows,
                      let id = (item[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                      !Self.windowNumbers.contains(id),
                      let pid = (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value, pid != getpid(), !excludedPIDs.contains(pid),
                      item[kCGWindowLayer as String] as? Int == 0,
                      let bounds = item[kCGWindowBounds as String] as? [String: Any],
                      let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                      !(focused.map { Geometry.close($0, frame, tolerance: 2) } ?? false),
                      display.frame.intersects(frame) && DimmingFocusScope.dimsWindows(on: display.frame, focused: focused, desktopScope: desktopScope) else { return nil }
                return "\(pid):\(id)"
            })
            let readyWindows = runtime.windows.ready(eligibleWindows, delay: settings.windowDelay, now: now)
            let windowProgress = runtime.windowFade.progress(ready: restoring ? [] : readyWindows, duration: settings.windowFade, now: now)
            let windows: [DimmingWindow] = list.compactMap { item in
                guard let id = (item[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                      !Self.windowNumbers.contains(id),
                      let pid = (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                      let layer = item[kCGWindowLayer as String] as? Int,
                      let bounds = item[kCGWindowBounds as String] as? [String: Any],
                      let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary), Geometry.valid(frame),
                      (item[kCGWindowAlpha as String] as? Double ?? 1) > 0, layer >= 0 else { return nil }
                return DimmingWindow(frame: frame, dimmable: layer == 0 && pid != getpid() && !excludedPIDs.contains(pid), ready: readyWindows.contains("\(pid):\(id)"), fadeProgress: windowProgress["\(pid):\(id)"] ?? 0)
            }
            let eligibleDisplays: Set<String> = settings.display && !(scope.map { $0.intersects(display.frame) } ?? false) ? [display.id] : []
            let readyDisplays = runtime.display.ready(eligibleDisplays, delay: settings.displayDelay, now: now)
            let displayProgress = runtime.displayFade.progress(ready: restoring ? [] : readyDisplays, duration: settings.displayFade, now: now)
            animating = animating || windowProgress.values.contains { $0 < 1 } || displayProgress.values.contains { $0 < 1 }
            runtimes[display.id] = runtime
            if restoring { panels[display.id]?.orderOut(nil); continue }
            let regions = DimmingPlan.regions(display: display.frame, windows: windows, focused: focused,
                windowAmount: settings.windows && DimmingFocusScope.dimsWindows(on: display.frame, focused: focused, desktopScope: desktopScope) ? settings.windowPercent / 100 : 0,
                displayAmount: readyDisplays.contains(display.id) ? settings.displayPercent / 100 : 0, displayProgress: displayProgress[display.id] ?? 0)
            guard !regions.isEmpty else { panels[display.id]?.orderOut(nil); continue }
            let frame = Geometry.axRect(display.frame, primaryTop: top)
            let panel: NSPanel
            if let existing = panels[display.id] { panel = existing }
            else {
                panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
                panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false
                panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
                // Floating panels default to transient: Mission Control hides them.
                // Keep the dimming surface stationary even when another display changes Spaces.
                panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
                panel.isReleasedWhenClosed = false; panel.animationBehavior = .none
                panel.contentView = DimmingView()
                panels[display.id] = panel
                Self.windowNumbers.insert(CGWindowID(panel.windowNumber))
            }
            panel.setFrame(frame, display: false)
            if let view = panel.contentView as? DimmingView {
                let local = regions.map { DimmingRegion(frame: $0.frame.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY), amount: $0.amount) }
                if view.regions != local { view.regions = local; view.needsDisplay = true }
            }
            panel.orderFrontRegardless()
        }
        let names = displays.filter { p.dimmingDisplays.contains($0.id) }.map(\.name).joined(separator: ", ")
        return restoring ? "Brightness restored. Dimming delays restarted; at least five seconds remain bright." : "Dimming displays: \(names.isEmpty ? "None selected" : names)."

    }
}

private final class DimmingView: NSView {
    var regions: [DimmingRegion] = []
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill(); dirtyRect.fill(using: .copy)
        for region in regions {
            NSColor.black.withAlphaComponent(region.amount).setFill()
            region.frame.fill(using: .sourceOver)
        }
    }
}
