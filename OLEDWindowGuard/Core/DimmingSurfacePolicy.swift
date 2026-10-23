import CoreGraphics

enum DimmingSurfacePolicy {
    static func includesInDimming(owner: String?, layer: Int) -> Bool {
        layer == 0 || (owner == "Dock" && layer == Int(CGWindowLevelForKey(.dockWindow)))
    }

    // Whole-display overlays must cover the Dock, while menu bars and context
    // menus stay above them. Window-only dimming retains its lower level.
    static let displayOverlayLevel = Int(CGWindowLevelForKey(.dockWindow)) + 1
    static let windowOverlayLevel = Int(CGWindowLevelForKey(.floatingWindow)) + 1
}
