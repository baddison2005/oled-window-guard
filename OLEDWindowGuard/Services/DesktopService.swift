import AppKit
import ApplicationServices

@MainActor
final class DesktopService {
    struct Handle { let element: AXUIElement; let pid: pid_t }
    private(set) var handles: [String: Handle] = [:]
    var trusted: Bool { AXIsProcessTrusted() }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func displays() -> [DisplayInfo] {
        let screens = NSScreen.screens
        // The first screen is the primary menu-bar display, even with a display above it.
        guard let primaryTop = screens.first?.frame.maxY else { return [] }
        return screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let displayID = CGDirectDisplayID(number.uint32Value)
            let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
            let id = uuid.map { CFUUIDCreateString(nil, $0) as String } ?? "display-\(displayID)"
            return DisplayInfo(id: id, name: screen.localizedName,
                               frame: Geometry.axRect(screen.frame, primaryTop: primaryTop),
                               usableFrame: Geometry.axRect(screen.visibleFrame, primaryTop: primaryTop),
                               scale: screen.backingScaleFactor)
        }
    }

    func snapshot(excludingOwnWindowNumbers: Set<CGWindowID> = []) -> DesktopSnapshot {
        let screens = displays()
        let cgWindows = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
        struct Visible { let id: String; let pid: pid_t; let frame: CGRect; let layer: Int }
        let visible: [Visible] = cgWindows.compactMap { item in
            guard let pid = (item[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let id = (item[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let layer = item[kCGWindowLayer as String] as? Int,
                  let bounds = item[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary), Geometry.valid(frame),
                  (item[kCGWindowAlpha as String] as? Double ?? 1) > 0 else { return nil }
            let title = item[kCGWindowName as String] as? String
            guard DesktopWindowFilter.includes(ownerPID: pid, ownPID: getpid(), title: title) else { return nil }
            // Exclude only the warning panels this process just closed. Keep
            // every other application window, including our dashboard, as an obstacle.
            guard pid != getpid() || !excludingOwnWindowNumbers.contains(id) else { return nil }
            // Floating windows and dialogs are obstacles too. System overlays are handled by usableFrame / session events.
            guard layer >= 0, layer < Int(CGWindowLevelForKey(.mainMenuWindow)) else { return nil }
            return Visible(id: "\(pid):\(id)", pid: pid, frame: frame, layer: layer)
        }
        var axByPID: [pid_t: [AXUIElement]] = [:]
        var focusedByPID: [pid_t: AXUIElement] = [:]
        if trusted {
            for pid in Set(visible.filter { $0.layer == 0 }.map(\.pid)) where pid != getpid() {
                let app = AXUIElementCreateApplication(pid)
                AXUIElementSetMessagingTimeout(app, 0.15)
                axByPID[pid] = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
                if let focused = attribute(app, kAXFocusedWindowAttribute), CFGetTypeID(focused) == AXUIElementGetTypeID() {
                    focusedByPID[pid] = unsafeBitCast(focused, to: AXUIElement.self)
                }
            }
        }
        var newHandles: [String: Handle] = [:]
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        var rows: [WindowInfo] = []
        for v in visible {
            let app = NSRunningApplication(processIdentifier: v.pid)
            let appID = app?.bundleIdentifier ?? "pid:\(v.pid)"
            let display = screens.first { Geometry.contains($0.usableFrame, v.frame) }
            var reason: String? = "Unsupported window"
            var movable = false
            var focused = false
            var resizable = false
            // Ambiguous matches (e.g. identical windows on different Spaces) are always skipped.
            let matches = (axByPID[v.pid] ?? []).filter { element in
                guard let frame = frame(element) else { return false }
                return Geometry.close(frame, v.frame, tolerance: 1)
            }
            let cgMatches = visible.filter { $0.pid == v.pid && Geometry.close($0.frame, v.frame, tolerance: 1) }
            if v.pid == getpid() {
                reason = "OLED Window Guard"
            } else if matches.count == 1, cgMatches.count == 1, let element = matches.first, v.layer == 0 {
                AXUIElementSetMessagingTimeout(element, 0.15)
                let subrole = attribute(element, kAXSubroleAttribute) as? String
                let minimized = attribute(element, kAXMinimizedAttribute) as? Bool
                let fullScreen = attribute(element, "AXFullScreen") as? Bool
                let modal = attribute(element, kAXModalAttribute) as? Bool ?? false
                let hasSheets = (attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []).contains {
                    attribute($0, kAXRoleAttribute) as? String == kAXSheetRole as String
                }
                var settable = DarwinBoolean(false)
                movable = AXUIElementIsAttributeSettable(element, kAXPositionAttribute as CFString, &settable) == .success && settable.boolValue
                var sizeSettable = DarwinBoolean(false)
                resizable = AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &sizeSettable) == .success && sizeSettable.boolValue
                focused = frontPID == v.pid && focusedByPID[v.pid].map { CFEqual($0, element) } == true
                if subrole != kAXStandardWindowSubrole as String { reason = "Dialog or nonstandard window" }
                else if minimized != false { reason = "Minimized or unknown state" }
                else if fullScreen == true { reason = "Full screen" }
                else if modal || hasSheets { reason = "Dialog is open" }
                else if display == nil { reason = "Spans displays or extends outside the usable screen" }
                else if let display, Geometry.maximized(v.frame, display: display) { reason = "Maximised" }
                else if !movable { reason = "Position cannot be changed" }
                else { reason = nil }
                newHandles[v.id] = Handle(element: element, pid: v.pid)
            } else if !trusted { reason = "Accessibility permission required" }
            rows.append(WindowInfo(id: v.id, appID: appID, appName: app?.localizedName ?? "Application",
                                   frame: v.frame, displayID: display?.id, movable: movable, focused: focused, skipReason: reason, resizable: resizable))
        }
        handles = newHandles
        return DesktopSnapshot(displays: screens, windows: rows)
    }

    func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = attribute(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, dimensions = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(position, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeBitCast(size, to: AXValue.self), .cgSize, &dimensions) else { return nil }
        let r = CGRect(origin: point, size: dimensions)
        return Geometry.valid(r) ? r : nil
    }

    func move(_ handle: Handle, to rect: CGRect, permitsRoundingResize: Bool = false, roundingResizeLimit: CGFloat = 2) -> Bool {
        guard trusted, Geometry.valid(rect), let observed = frame(handle.element) else { return false }
        var pid: pid_t = 0
        guard AXUIElementGetPid(handle.element, &pid) == .success, pid == handle.pid else { return false }
        if observed.size != rect.size {
            guard permitsRoundingResize, observed.origin == rect.origin,
                  Move(windowID: "", from: observed, to: rect, permitsRoundingResize: true, roundingResizeLimit: roundingResizeLimit).validSizeChange else { return false }
            var settable = DarwinBoolean(false)
            guard AXUIElementIsAttributeSettable(handle.element, kAXSizeAttribute as CFString, &settable) == .success,
                  settable.boolValue else { return false }
            var size = rect.size
            guard let value = AXValueCreate(.cgSize, &size) else { return false }
            return AXUIElementSetAttributeValue(handle.element, kAXSizeAttribute as CFString, value) == .success
        }
        var origin = rect.origin
        guard let value = AXValueCreate(.cgPoint, &origin) else { return false }
        return AXUIElementSetAttributeValue(handle.element, kAXPositionAttribute as CFString, value) == .success
    }

    func focusedWindowFrame() -> CGRect? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.1)
        guard let value = attribute(app, kAXFocusedWindowAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return frame(unsafeBitCast(value, to: AXUIElement.self))
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}

/// Observe event kind/location only, never key contents. Accessibility approval
/// permits the global keyboard monitor; local monitoring covers our own UI.
@MainActor
final class DisplayActivityMonitor {
    private var global: Any?
    private var local: Any?
    private var history = DisplayActivityHistory()
    private let desktop = DesktopService()

    func start() {
        guard global == nil, local == nil else { return }
        let mask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown,
                                         .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel]
        global = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.record(event) }
        }
        local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.record(event) }
            return event
        }
    }

    private func record(_ event: NSEvent) {
        let screens = desktop.displays()
        let ids: Set<String>
        if event.type == .keyDown {
            if let frame = desktop.focusedWindowFrame() {
                ids = Set(screens.filter { Geometry.overlaps($0.frame, frame) }.map(\.id))
            } else {
                // Unknown keyboard focus cannot safely be assigned to another screen.
                ids = Set(screens.map(\.id))
            }
        } else if let point = event.cgEvent?.location {
            ids = Set(screens.filter { $0.frame.contains(point) }.map(\.id))
        } else { ids = Set(screens.map(\.id)) }
        history.record(on: ids, at: Date())
    }

    func isQuiet(on ids: Set<String>, seconds: Double) -> Bool {
        if NSEvent.pressedMouseButtons != 0 {
            guard let point = CGEvent(source: nil)?.location else { return false }
            if desktop.displays().contains(where: { ids.contains($0.id) && $0.frame.contains(point) }) { return false }
        }
        return history.isQuiet(on: ids, at: Date(), seconds: seconds)
    }

    deinit {
        if let global { NSEvent.removeMonitor(global) }
        if let local { NSEvent.removeMonitor(local) }
    }
}
