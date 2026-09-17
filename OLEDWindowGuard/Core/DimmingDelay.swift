import Foundation

/// Independent continuous-eligibility timers. Regaining focus cancels that item's wait.
struct DimmingDelay {
    private var since: [String: TimeInterval] = [:]
    private var previousDelay: Double?
    mutating func reset() { since.removeAll(); previousDelay = nil }
    mutating func ready(_ eligible: Set<String>, delay: Double, now: TimeInterval) -> Set<String> {
        if previousDelay != delay { since.removeAll(); previousDelay = delay }
        since = since.filter { eligible.contains($0.key) }
        for id in eligible where since[id] == nil { since[id] = now }
        return Set(eligible.filter { now - (since[$0] ?? now) >= delay })
    }
}
