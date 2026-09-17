import Foundation
import CoreGraphics

struct DimmingWindow {
    let frame: CGRect
    let dimmable: Bool
    var ready = true
    var fadeProgress: Double = 1
}
struct DimmingRegion: Equatable {
    let frame: CGRect
    let amount: Double
}

enum DimmingPlan {
    static func subtract(_ rect: CGRect, _ cut: CGRect) -> [CGRect] {
        let intersection = rect.intersection(cut)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return [rect] }
        return [CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: intersection.minY-rect.minY),
                CGRect(x: rect.minX, y: intersection.maxY, width: rect.width, height: rect.maxY-intersection.maxY),
                CGRect(x: rect.minX, y: intersection.minY, width: intersection.minX-rect.minX, height: intersection.height),
                CGRect(x: intersection.maxX, y: intersection.minY, width: rect.maxX-intersection.maxX, height: intersection.height)]
            .filter { $0.width > 0 && $0.height > 0 }
    }
    // Front-to-back windows. Occluded pixels are never dimmed twice.
    static func regions(display: CGRect, windows: [DimmingWindow], focused: CGRect?, windowAmount: Double, displayAmount: Double, displayProgress: Double = 1) -> [DimmingRegion] {
        let whole = displayAmount > 0 && !(focused.map { $0.intersects(display) } ?? false)
        if whole {
            var pieces = [display]
            var occluders: [CGRect] = []
            for window in windows {
                if !window.dimmable {
                    var visible = [window.frame.intersection(display)].filter { !$0.isNull }
                    for front in occluders {
                        visible = visible.flatMap { subtract($0, front) }
                        if visible.count > 2048 { return [] }
                    }
                    for region in visible { pieces = pieces.flatMap { subtract($0, region) } }
                    if pieces.count > 2048 { return [] }
                }
                occluders.append(window.frame)
            }
            // Blend from window dimming rather than briefly brightening dimmed windows.
            if displayProgress >= 1 { return pieces.map { DimmingRegion(frame: $0, amount: displayAmount) } }
            let background = regions(display: display, windows: windows, focused: focused, windowAmount: windowAmount, displayAmount: 0)
            var blended: [DimmingRegion] = []
            for region in background {
                pieces = pieces.flatMap { subtract($0, region.frame) }
                if pieces.count > 2048 { return [] }
                blended.append(DimmingRegion(frame: region.frame, amount: region.amount * (1-displayProgress) + displayAmount * displayProgress))
            }
            return blended + pieces.map { DimmingRegion(frame: $0, amount: displayAmount * displayProgress) }
        }
        guard windowAmount > 0 else { return [] }
        var occluders: [CGRect] = [], result: [DimmingRegion] = []
        for window in windows {
            let clipped = window.frame.intersection(display)
            defer { occluders.append(window.frame) }
            guard !clipped.isNull, window.dimmable, window.ready,
                  !(focused.map { Geometry.close($0, window.frame, tolerance: 2) } ?? false) else { continue }
            var pieces = [clipped]
            for other in occluders + (focused.map { [$0] } ?? []) {
                pieces = pieces.flatMap { subtract($0, other) }
                if pieces.count > 2048 { return [] }
            }
            result += pieces.map { DimmingRegion(frame: $0, amount: windowAmount * window.fadeProgress) }
            if result.count > 2048 { return [] }
        }
        return result
    }
}
