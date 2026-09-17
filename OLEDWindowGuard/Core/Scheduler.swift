import Foundation

/// No catch-up moves: every pause, wake or configuration change begins a fresh interval.
struct MovementClock {
    enum Phase: Equatable { case stopped, waiting(Date), warning(Date), applying }
    private(set) var phase: Phase = .stopped
    mutating func start(now: Date, interval: TimeInterval) { phase = .waiting(now.addingTimeInterval(interval)) }
    mutating func wait(until deadline: Date) { phase = .waiting(deadline) }
    mutating func stop() { phase = .stopped }
    mutating func warn(now: Date, seconds: TimeInterval) { phase = .warning(now.addingTimeInterval(seconds)) }
    mutating func applying() { phase = .applying }
    func isDue(now: Date) -> Bool {
        switch phase { case .waiting(let date), .warning(let date): now >= date; default: false }
    }
    var deadline: Date? {
        switch phase { case .waiting(let date), .warning(let date): date; default: nil }
    }
}

enum SnapshotValidation {
    static func safePositions(_ snapshot: DesktopSnapshot, moving ids: Set<String>, regions: [String: [CGRect]] = [:], sourceRounding: Bool = false, sourceAllowance: CGFloat = 2) -> Bool {
        ids.allSatisfy { id in
            guard let window = snapshot.windows.first(where: { $0.id == id }), window.skipReason == nil,
                  let display = snapshot.displays.first(where: { $0.id == window.displayID }),
                  Geometry.contains(display.usableFrame, window.frame) else { return false }
            if let allowed = regions[display.id], !allowed.contains(where: {
                Geometry.contains(sourceRounding ? $0.insetBy(dx: -min(32, max(0, sourceAllowance)), dy: -min(32, max(0, sourceAllowance))) : $0, window.frame)
            }) { return false }
            return !snapshot.windows.contains { $0.id != id && Geometry.overlaps($0.frame, window.frame) }
        }
    }
    static func unchanged(_ before: DesktopSnapshot, _ after: DesktopSnapshot, moving ids: Set<String>, avoidFocused: Bool,
                          ignoringEligibilityFor ignoredIDs: Set<String> = []) -> Bool {
        changeDescription(before, after, moving: ids, avoidFocused: avoidFocused,
                          ignoringEligibilityFor: ignoredIDs) == nil
    }

    static func changeDescription(_ before: DesktopSnapshot, _ after: DesktopSnapshot, moving ids: Set<String>, avoidFocused: Bool,
                                  ignoringEligibilityFor ignoredIDs: Set<String> = []) -> String? {
        guard before.displays == after.displays else { return "The display configuration changed." }
        if let added = after.windows.first(where: { new in !before.windows.contains { $0.id == new.id } }) {
            return "A window appeared in \(added.appName)."
        }
        for old in before.windows {
            guard let current = after.windows.first(where: { $0.id == old.id }) else { return "A window disappeared from \(old.appName)." }
            guard Geometry.close(old.frame, current.frame) else { return "A window moved or resized in \(old.appName)." }
            guard old.appID == current.appID else { return "A window’s identity changed in \(old.appName)." }
            if !ignoredIDs.contains(old.id), old.skipReason != current.skipReason || old.movable != current.movable {
                return "A window’s eligibility changed in \(old.appName)."
            }
            if ids.contains(old.id) && avoidFocused && current.focused { return "A planned window gained focus in \(old.appName)." }
        }
        return nil
    }
}
