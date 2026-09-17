import Foundation
import CoreGraphics

/// Fade in after eligibility delays. Removing eligibility restores brightness immediately.
struct DimmingFade {
    private var starts: [String: TimeInterval] = [:]
    mutating func reset() { starts.removeAll() }
    mutating func progress(ready: Set<String>, duration: Double, now: TimeInterval) -> [String: Double] {
        starts = starts.filter { ready.contains($0.key) }
        for id in ready where starts[id] == nil { starts[id] = now }
        return Dictionary(uniqueKeysWithValues: ready.map { id in
            (id, duration <= 0 ? 1 : min(1, max(0, (now - (starts[id] ?? now)) / duration)))
        })
    }
}

enum DimmingFocusScope {
    static func dimsWindows(on display: CGRect, focused: CGRect?, desktopScope: CGRect?) -> Bool {
        focused != nil || !(desktopScope.map { $0.intersects(display) } ?? false)
    }
}
