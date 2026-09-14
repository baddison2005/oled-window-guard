import Foundation
import CoreGraphics

enum MovementMode: String, Codable, CaseIterable, Identifiable {
    case drift, swap, group
    var id: Self { self }
    var title: String {
        switch self {
        case .drift: "Shift position"
        case .swap: "Swap positions"
        case .group: "Window Layouts group"
        }
    }
    var symbol: String {
        switch self { case .drift: "arrow.up.and.down.and.arrow.left.and.right"; case .swap: "arrow.triangle.swap"; case .group: "rectangle.3.group" }
    }
}

struct Preferences: Codable, Equatable {
    var selectedDisplays: Set<String> = []
    var intervalMinutes: Double = 10
    var warningSeconds: Double = 10
    var mode: MovementMode = .drift
    var automaticDistance = true
    var distancePixels: Double = 16
    var maximumExcursionPixels: Double = 64 // Legacy settings retained for migration.
    var driftPercent: Double? = nil
    var driftRangePercent: Double {
        get { driftPercent ?? 10 }
        set { driftPercent = newValue }
    }
    var maximumWindows = 4
    var sizeTolerance: Double = 0.10
    var soundEnabled = false
    var systemNotifications = false
    var avoidFocusedWindow = true
    var quietSeconds: Double = 5
    var allowTransientOverlap = false
    var groupID = ""
    var rotateGroup = false
    var excludedApps: Set<String> = []
    var keepSwapGroups: Bool? = nil
    var layoutSourceID: String? = nil
    var layoutSource: LayoutSource {
        get { LayoutSource(rawValue: layoutSourceID ?? "") ?? .automatic }
        set { layoutSourceID = newValue.rawValue }
    }
    var keepSimilarWindowsTogether: Bool {
        get { keepSwapGroups ?? false }
        set { keepSwapGroups = newValue }
    }

    var permitsIntermediateOverlap: Bool { allowTransientOverlap || (mode == .group && rotateGroup) }

    func validated() -> Self {
        var p = self
        func clamp(_ n: Double, _ minValue: Double, _ maxValue: Double, fallback: Double) -> Double {
            n.isFinite ? min(max(n, minValue), maxValue) : fallback
        }
        if driftPercent != nil { p.driftRangePercent = clamp(driftRangePercent, 1, 100, fallback: 10) }
        p.intervalMinutes = clamp(intervalMinutes, 1, 240, fallback: 10)
        p.warningSeconds = clamp(warningSeconds, 3, 60, fallback: 10)
        p.distancePixels = clamp(distancePixels, 2, 128, fallback: 16)
        p.maximumExcursionPixels = clamp(maximumExcursionPixels, 8, 512, fallback: 64)
        p.maximumWindows = min(max(maximumWindows, 1), 12)
        p.sizeTolerance = clamp(sizeTolerance, 0, 0.25, fallback: 0.10)
        p.quietSeconds = clamp(quietSeconds, 0, 60, fallback: 5)
        return p
    }
}

struct DisplayInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let frame: CGRect
    let usableFrame: CGRect
    let scale: CGFloat
    var suggestedPixels: CGFloat { min(32, max(8, (min(frame.width, frame.height) * scale * 0.004).rounded())) }
}

struct WindowInfo: Identifiable, Equatable {
    let id: String
    let appID: String
    let appName: String
    let frame: CGRect
    let displayID: String?
    let movable: Bool
    let focused: Bool
    let skipReason: String?
    var resizable: Bool = false
}

struct DesktopSnapshot: Equatable {
    var displays: [DisplayInfo]
    var windows: [WindowInfo]

    func restricted(to displayIDs: Set<String>) -> DesktopSnapshot {
        let relevantDisplays = displays.filter { displayIDs.contains($0.id) }
        return DesktopSnapshot(
            displays: relevantDisplays,
            windows: windows.filter { window in
                relevantDisplays.contains { Geometry.overlaps($0.frame, window.frame) }
            }
        )
    }
}

struct Move: Equatable {
    let windowID: String
    let from: CGRect
    let to: CGRect
    var permitsRoundingResize: Bool = false
    var roundingResizeLimit: CGFloat = 2
    var reversed: Move { Move(windowID: windowID, from: to, to: from, permitsRoundingResize: permitsRoundingResize, roundingResizeLimit: roundingResizeLimit) }
    var validSizeChange: Bool {
        from.size == to.size || (permitsRoundingResize
            && roundingResizeLimit.isFinite && (0...32).contains(roundingResizeLimit)
            && abs(from.width - to.width) <= roundingResizeLimit && abs(from.height - to.height) <= roundingResizeLimit)
    }
    func acceptsPartialResize(_ frame: CGRect) -> Bool {
        permitsRoundingResize && validSizeChange && from.origin == to.origin && frame.origin == from.origin
        && (min(from.width, to.width)...max(from.width, to.width)).contains(frame.width)
        && (min(from.height, to.height)...max(from.height, to.height)).contains(frame.height)
    }
}

struct MovementPlan {
    var moves: [Move] = []
    var steps: [Move] = []
    var reason = "No safe movement is available. Leave space between windows or try another mode."
    var windowCount: Int { moves.count }
}

struct WindowAnchor {
    var originFrame: CGRect
    var lastFrame: CGRect
    var previousFrame: CGRect? = nil
}

enum Geometry {
    static func valid(_ r: CGRect) -> Bool {
        [r.minX, r.minY, r.width, r.height].allSatisfy(\.isFinite) && r.width > 0 && r.height > 0
    }
    static func close(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 0.5) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
        && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }
    static func contains(_ outer: CGRect, _ inner: CGRect) -> Bool {
        valid(outer) && valid(inner) && inner.minX >= outer.minX && inner.minY >= outer.minY
        && inner.maxX <= outer.maxX && inner.maxY <= outer.maxY
    }
    static func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
        let i = a.intersection(b)
        return !i.isNull && i.width > 0.01 && i.height > 0.01
    }
    static func maximized(_ frame: CGRect, display: DisplayInfo) -> Bool {
        close(frame, display.usableFrame, tolerance: 4) || close(frame, display.frame, tolerance: 4)
    }
    static func similar(_ a: CGRect, _ b: CGRect, tolerance: Double) -> Bool {
        abs(a.width - b.width) / max(a.width, b.width) <= tolerance
        && abs(a.height - b.height) / max(a.height, b.height) <= tolerance
    }
    static func axRect(_ rect: CGRect, primaryTop: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryTop - rect.maxY, width: rect.width, height: rect.height)
    }
}

enum DesktopWindowFilter {
    static let dashboardTitle = "OLED Window Guard"

    /// Keep the visible dashboard as an obstacle, while excluding this app's
    /// menu-bar host and warning panels from the external-window model.
    static func includes(ownerPID: pid_t, ownPID: pid_t, title: String?) -> Bool {
        ownerPID != ownPID || title == dashboardTitle
    }
}

enum ActivityPolicy {
    static func permitsMove(idleSeconds: Double, quietSeconds: Double, mouseButtonDown: Bool) -> Bool {
        !mouseButtonDown && idleSeconds >= quietSeconds
    }

    static func explanation(quietSeconds: Double) -> String {
        if quietSeconds == 0 { return "Release mouse buttons before the countdown ends. You can also skip this move." }
        return "Typing, clicking or scrolling on a display being moved within the last \(quietSeconds.formatted()) seconds before the countdown ends cancels this move."
    }
}

struct DisplayActivityHistory {
    var started = Date()
    var latest: [String: Date] = [:]
    mutating func record(on displayIDs: Set<String>, at date: Date) {
        for id in displayIDs { latest[id] = max(latest[id] ?? started, date) }
    }
    func isQuiet(on displayIDs: Set<String>, at date: Date, seconds: Double) -> Bool {
        displayIDs.allSatisfy { date.timeIntervalSince(latest[$0] ?? started) >= seconds }
    }
}
