import Foundation

/// A manual whole-display dim remains local until interaction or explicit restoration.
struct InstantDimming {
    private(set) var displays: Set<String> = []
    mutating func dim(_ id: String) { displays.insert(id) }
    mutating func interact(on ids: Set<String>) { displays.subtract(ids) }
    mutating func retain(_ ids: Set<String>) { displays.formIntersection(ids) }
    mutating func reset() { displays.removeAll() }
    func contains(_ id: String) -> Bool { displays.contains(id) }

    static func target(requested: String, selected: Set<String>, connected: Set<String>) -> String? {
        let available = selected.intersection(connected)
        return available.contains(requested) ? requested : available.sorted().first
    }
}
