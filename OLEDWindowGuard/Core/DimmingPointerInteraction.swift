import CoreGraphics

struct DimmingPointerSurface {
    let owner: String?
    let layer: Int
    let frame: CGRect
    var windowID: CGWindowID? = nil
    var isDockControl: Bool { owner == "Dock" || owner == "DockHelper" }
}

enum DimmingPointerInteraction {
    case desktop, window, dockControl

    /// Visible surfaces arrive front to back, with the app's dimming panels removed.
    static func resolve(at point: CGPoint, surfaces: [DimmingPointerSurface], display: CGRect,
                        handlingWindowID: CGWindowID? = nil) -> Self {
        // Modern macOS renders the Dock in a full-screen, mostly transparent
        // surface. Its bounds cannot distinguish Dock icons from the desktop.
        // WindowServer's event recipient identifies the actual interactive hit.
        if let handlingWindowID, handlingWindowID != 0,
           surfaces.contains(where: { $0.windowID == handlingWindowID && $0.isDockControl }) {
            return .dockControl
        }
        let hit = surfaces.first {
            $0.layer >= 0 && $0.frame.contains(point)
                && !DimmingInteractionScope.isDesktopSurface(owner: $0.owner, layer: $0.layer, frame: $0.frame, displays: [display])
        }
        guard let hit else { return .desktop }
        // Using a Dock icon or its context menu is a control interaction,
        // not a desktop click or activation of the application underneath it.
        if hit.isDockControl { return .dockControl }
        return .window
    }
}
