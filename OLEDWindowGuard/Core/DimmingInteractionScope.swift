import CoreGraphics

/// Desktop/Space events can leave AX reporting a window on a different display.
/// Keep the interaction's display authoritative until the next explicit window action.
struct DimmingInteractionScope {
    private var display: CGRect?
    private var desktop = false

    mutating func desktopClicked(on display: CGRect) {
        self.display = display
        desktop = true
    }
    mutating func spaceChanged(on display: CGRect) {
        self.display = display
        desktop = false
    }
    mutating func windowInteraction() { display = nil; desktop = false }

    func resolve(reported: CGRect?, fallback: CGRect?) -> (focused: CGRect?, scope: CGRect?) {
        guard let display else { return (reported, reported ?? fallback) }
        if !desktop, let reported, reported.intersects(display) { return (reported, reported) }
        return (nil, display)
    }
}

extension DimmingInteractionScope {
    static func applicationFocus(reported: CGRect?, isFinder: Bool, visibleFinderWindows: [CGRect]) -> CGRect? {
        guard isFinder, let reported else { return reported }
        // Finder's AX desktop covers the entire virtual desktop but is absent from
        // the ordinary (desktop-excluded) layer-zero CG window list.
        return visibleFinderWindows.contains { Geometry.close($0, reported, tolerance: 2) } ? reported : nil
    }

    /// Dock creates screen-sized transition/desktop surfaces that are not app windows
    /// or interactive panels. They must not consume the desktop hit test or dimming mask.
    static func isDesktopSurface(owner: String?, layer: Int, frame: CGRect, displays: [CGRect]) -> Bool {
        owner == "Dock" && layer > 0 && displays.contains { display in
            // During a Space swipe these surfaces slide partly off screen.
            // Classify by their full size, not how much currently overlaps a display.
            frame.width >= display.width * 0.95 && frame.height >= display.height * 0.95
        }
    }
}
