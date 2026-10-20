import Foundation

/// A preview is a proposal with an explicit desktop/settings baseline, not a new random draw.
struct PreparedMovement {
    let plan: MovementPlan
    let baseline: DesktopSnapshot
    let preferences: Preferences
    let group: ImportedGroup?
    let layoutSource: LayoutSource?

    func matches(snapshot: DesktopSnapshot, preferences: Preferences, group: ImportedGroup?, source: LayoutSource?) -> Bool {
        self.preferences == preferences && self.group == group && layoutSource == source
        && SnapshotValidation.unchanged(baseline, snapshot.restricted(to: Set(baseline.displays.map(\.id))),
            moving: Set(plan.moves.map(\.windowID)), avoidFocused: preferences.avoidFocusedWindow)
    }
}
