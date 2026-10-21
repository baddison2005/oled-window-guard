import Foundation

/// Briefly keep a changed monitor bright while its Space animation settles.
struct SpaceDimmingRestore {
    private var deadlines: [String: TimeInterval] = [:]
    mutating func restart(_ id: String, now: TimeInterval) { deadlines[id] = now + 0.75 }
    func isRestoring(_ id: String, now: TimeInterval) -> Bool { now < (deadlines[id] ?? 0) }
}
