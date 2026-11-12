import CoreGraphics

enum WarningPosition: String, CaseIterable, Identifiable {
    case topLeft, topCenter, topRight, random

    var id: Self { self }

    var title: String {
        switch self {
        case .topLeft: "Top left"
        case .topCenter: "Top centre"
        case .topRight: "Top right"
        case .random: "Random within top 25%"
        }
    }

    // These are AppKit screen coordinates, with Y increasing upwards.
    func origin(for size: CGSize, screenFrame: CGRect, visibleFrame: CGRect,
                rng: inout some RandomNumberGenerator) -> CGPoint {
        let horizontalInset = min(24, max(0, (visibleFrame.width - size.width) / 2))
        let left = visibleFrame.minX + horizontalInset
        let right = max(left, visibleFrame.maxX - size.width - horizontalInset)
        let highest = max(visibleFrame.minY, visibleFrame.maxY - size.height)
        let top = max(visibleFrame.minY, highest - 24)

        switch self {
        case .topLeft: return CGPoint(x: left, y: top)
        case .topCenter: return CGPoint(x: (left + right) / 2, y: top)
        case .topRight: return CGPoint(x: right, y: top)
        case .random:
            let bandBottom = screenFrame.maxY - screenFrame.height / 4
            // Use less top inset when needed to fit inside the band. On a short
            // display, pin the card just below the menu bar and still vary X.
            let upper = min(highest, max(top, bandBottom))
            let lower = min(upper, max(visibleFrame.minY, bandBottom))
            return CGPoint(x: CGFloat.random(in: left...right, using: &rng),
                           y: CGFloat.random(in: lower...upper, using: &rng))
        }
    }
}
