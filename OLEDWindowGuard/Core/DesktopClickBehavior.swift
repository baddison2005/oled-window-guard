import Foundation

enum DesktopClickBehavior: String, Codable, CaseIterable, Identifiable {
    case keepBright, restartTimers
    var id: Self { self }
    var title: String {
        switch self {
        case .keepBright: "Restore brightness without restarting dimming timers"
        case .restartTimers: "Restore brightness and restart dimming timers"
        }
    }
}

/// Explicit desktop-click choices apply only to the clicked display.
struct DesktopClickDimmingState {
    private var choices: [String: DesktopClickBehavior] = [:]
    mutating func click(on id: String, behavior: DesktopClickBehavior) { choices[id] = behavior }
    mutating func windowClicked(on id: String) { choices[id] = nil }
    mutating func reset() { choices.removeAll() }
    func behavior(on id: String) -> DesktopClickBehavior? { choices[id] }
    func eligibility(on id: String, windows: Bool, display: Bool) -> (windows: Bool, display: Bool) {
        switch choices[id] {
        case .keepBright: (false, false)
        case .restartTimers: (true, true)
        case nil: (windows, display)
        }
    }
}
