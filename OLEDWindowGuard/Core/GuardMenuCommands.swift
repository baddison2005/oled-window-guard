import Foundation

/// Both menus use the same commands. Targets are display UUIDs, never screen indexes or ports.
struct GuardMenuCommand: Identifiable {
    enum Action: Hashable {
        case pauseAll, move(String), dim(String), dimAll
        case restoreBrightness(String), restoreAllBrightness, restoreLastMove
    }
    let id: Action
    let title: String
    let enabled: Bool
    let help: String
}

struct GuardMenuCommands {
    let pauseAll: GuardMenuCommand
    let moves: [GuardMenuCommand]
    let dims: [GuardMenuCommand]
    let restores: [GuardMenuCommand]
    let dimAll: GuardMenuCommand
    let restoreAll: GuardMenuCommand
    let restoreLastMove: GuardMenuCommand

    init(displays: [DisplayInfo], movementIDs: Set<String>, dimmingIDs: Set<String>,
         movementRunning: Bool, dimmingRunning: Bool, operational: Bool,
         busy: Bool, warning: Bool, updating: Bool,
         lastMovedDisplay: DisplayInfo?, canUndo: Bool) {
        let connected = Set(displays.map(\.id))
        let movement = displays.filter { movementRunning && movementIDs.contains($0.id) }
        let dimming = displays.filter { dimmingRunning && dimmingIDs.contains($0.id) }
        let brightness = displays.filter { dimmingIDs.contains($0.id) }
        let canMove = operational && !busy && !warning && !updating
        let canDim = operational && !updating
        pauseAll = GuardMenuCommand(id: .pauseAll, title: "Pause all guarding",
            enabled: (movementRunning || dimmingRunning || warning) && !busy && !updating,
            help: "Pause movement and dimming, cancel any warning, and restore brightness. Settings are retained.")
        moves = movement.map { display in
            GuardMenuCommand(id: .move(display.id), title: Self.name(display, among: displays), enabled: canMove,
                help: "Warn, then apply the next safe move on this monitor. Display ID: \(display.id)")
        }
        dims = dimming.map { display in
            GuardMenuCommand(id: .dim(display.id), title: Self.name(display, among: displays), enabled: canDim,
                help: "Immediately dim this monitor and its windows at its display dimming level. Display ID: \(display.id)")
        }
        restores = brightness.map { display in
            GuardMenuCommand(id: .restoreBrightness(display.id), title: Self.name(display, among: displays), enabled: !updating,
                help: "Restore brightness and restart dimming delays on this monitor only. Display ID: \(display.id)")
        }
        dimAll = GuardMenuCommand(id: .dimAll, title: "Dim all available monitors", enabled: canDim && !dims.isEmpty,
            help: "Immediately dim all connected monitors selected for dimming and their windows. Dimming guarding must be running.")
        restoreAll = GuardMenuCommand(id: .restoreAllBrightness, title: "Restore brightness on all available monitors",
            enabled: !updating && !restores.isEmpty, help: "Restore brightness and restart dimming delays on all connected dimming monitors.")
        let lastName = lastMovedDisplay.map { last in
            Self.name(displays.first(where: { $0.id == last.id }) ?? last, among: displays)
        }
        restoreLastMove = GuardMenuCommand(id: .restoreLastMove,
            title: lastName.map { "Restore last move — \($0)…" } ?? "Restore last move…",
            enabled: canUndo && canMove && (lastMovedDisplay.map { connected.contains($0.id) } ?? false),
            help: "After a warning, restore the last moved monitor's previous window arrangement if it is still safe.")
    }

    static func name(_ display: DisplayInfo, among displays: [DisplayInfo]) -> String {
        // Identical display models can share a localized name; keep both targets distinguishable.
        displays.filter { $0.name == display.name }.count > 1
            ? "\(display.name) (\(display.id))" : display.name
    }
}
