import Foundation

struct DisplayMovementSettings: Codable, Equatable {
    var mode: MovementMode
    var interval: Double
    var range: Double
    var maximumWindows: Int
    var tolerance: Double
    var groupID: String
    var rotateGroup: Bool
    var keepGroups: Bool
    var horizontal: Bool
    var vertical: Bool
    init(_ p: Preferences) {
        mode = p.mode; interval = p.intervalMinutes; range = p.driftRangePercent
        maximumWindows = p.maximumWindows; tolerance = p.sizeTolerance
        groupID = p.groupID; rotateGroup = p.rotateGroup; keepGroups = p.keepSimilarWindowsTogether
        horizontal = p.allowHorizontalShiftReordering; vertical = p.allowVerticalShiftReordering
    }
    func applying(to defaults: Preferences) -> Preferences {
        var p = defaults
        p.mode = mode; p.intervalMinutes = interval; p.driftRangePercent = range
        p.maximumWindows = maximumWindows; p.sizeTolerance = tolerance
        p.groupID = groupID; p.rotateGroup = rotateGroup; p.keepSimilarWindowsTogether = keepGroups
        p.allowHorizontalShiftReordering = horizontal; p.allowVerticalShiftReordering = vertical
        return p.validated()
    }
}
extension Preferences {
    func movementSettings(for displayID: String) -> Preferences {
        var p = movementOverrides?[displayID]?.applying(to: self) ?? validated()
        p.selectedDisplays = [displayID]
        return p
    }
}
struct DisplayMovementSchedule {
    private(set) var deadlines: [String: Date] = [:]
    private var intervals: [String: TimeInterval] = [:]
    mutating func sync(_ values: [String: TimeInterval], now: Date) {
        deadlines = deadlines.filter { values[$0.key] != nil }
        for (id, interval) in values where intervals[id] != interval || deadlines[id] == nil {
            deadlines[id] = now.addingTimeInterval(interval)
        }
        intervals = values
    }
    mutating func restart(_ id: String, now: Date) {
        if let interval = intervals[id] { deadlines[id] = now.addingTimeInterval(interval) }
    }
    mutating func stop() { deadlines.removeAll(); intervals.removeAll() }
    var next: (id: String, date: Date)? {
        deadlines.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value < $1.value }.first.map { ($0.key, $0.value) }
    }
}
