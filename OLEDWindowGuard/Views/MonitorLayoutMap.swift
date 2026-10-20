import SwiftUI

/// All monitors share a coordinate transform, including negative origins and mixed sizes.
struct MonitorLayoutMap: View {
    let snapshot: DesktopSnapshot
    let plan: MovementPlan?
    var body: some View {
        Canvas { context, size in
            guard let first = snapshot.displays.first else { return }
            let bounds = snapshot.displays.dropFirst().reduce(first.frame) { $0.union($1.frame) }
            let scale = min((size.width - 40) / bounds.width, (size.height - 48) / bounds.height)
            let origin = CGPoint(x: (size.width - bounds.width * scale) / 2, y: 28 + (size.height - 48 - bounds.height * scale) / 2)
            func rect(_ frame: CGRect) -> CGRect {
                CGRect(x: origin.x + (frame.minX - bounds.minX) * scale,
                       y: origin.y + (frame.minY - bounds.minY) * scale,
                       width: frame.width * scale, height: frame.height * scale)
            }
            for display in snapshot.displays {
                let frame = rect(display.frame)
                context.fill(Path(roundedRect: frame, cornerRadius: 5), with: .color(.black.opacity(0.18)))
                context.stroke(Path(frame), with: .color(.secondary), lineWidth: 1)
                context.draw(Text(display.name).font(.system(size: 10, weight: .semibold)), at: CGPoint(x: frame.midX, y: frame.minY - 10))
                // Snapshot order is front-to-back. Draw back-to-front to show the same stacking.
                for window in snapshot.windows.reversed() where Geometry.overlaps(window.frame, display.frame) {
                    let r = rect(window.frame.intersection(display.frame))
                    context.fill(Path(r), with: .color(window.focused ? .blue.opacity(0.5) : .gray.opacity(0.4)))
                    context.stroke(Path(r), with: .color(.secondary), lineWidth: 0.6)
                    if r.width > 44 && r.height > 18 {
                        context.draw(Text(window.appName).font(.system(size: 9)), at: CGPoint(x: r.midX, y: r.midY))
                    }
                }
                for move in plan?.moves ?? [] where Geometry.contains(display.frame, move.to) {
                    let target = rect(move.to), source = rect(move.from)
                    context.stroke(Path(target), with: .color(.mint), style: StrokeStyle(lineWidth: 2, dash: [4,2]))
                    let start = CGPoint(x: source.midX, y: source.midY), end = CGPoint(x: target.midX, y: target.midY)
                    var arrow = Path(); arrow.move(to: start); arrow.addLine(to: end)
                    let angle = atan2(end.y-start.y, end.x-start.x)
                    for offset in [-0.5, 0.5] {
                        arrow.move(to: end)
                        arrow.addLine(to: CGPoint(x: end.x - 7*cos(angle+offset), y: end.y - 7*sin(angle+offset)))
                    }
                    context.stroke(arrow, with: .color(.mint), lineWidth: 1.5)
                }
            }
        }.accessibilityLabel("Live monitor layout. \(snapshot.displays.count) displays and \(snapshot.windows.count) windows. \(plan?.windowCount ?? 0) windows have planned destinations.")
    }
}
