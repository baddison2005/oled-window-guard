import Foundation

extension MovementPlanner {
    static func adjacent(_ a: CGRect, _ b: CGRect) -> Bool {
        let vertical = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        let horizontal = min(a.maxX, b.maxX) - max(a.minX, b.minX)
        return (vertical > 1 && min(abs(a.maxX - b.minX), abs(b.maxX - a.minX)) <= 8)
            || (horizontal > 1 && min(abs(a.maxY - b.minY), abs(b.maxY - a.minY)) <= 8)
    }

    static func groupedSwap<R: RandomNumberGenerator>(candidates: [WindowInfo], world: [WindowInfo],
        display: DisplayInfo, limit: Int, tolerance: Double, allowOverlap: Bool, rng: inout R) -> MovementPlan? {
        var remaining = world.filter { $0.displayID == display.id }
        var groups: [[WindowInfo]] = []
        while let first = remaining.first {
            remaining.removeFirst()
            var group = [first]
            while let index = remaining.firstIndex(where: { next in
                group.allSatisfy { Geometry.similar($0.frame, next.frame, tolerance: tolerance) }
                && group.contains { adjacent($0.frame, next.frame) }
            }) { group.append(remaining.remove(at: index)) }
            groups.append(group)
        }
        let eligible = Set(candidates.map(\.id))
        var members: [String: [WindowInfo]] = [:]
        var blocks: [WindowInfo] = []
        for (index, group) in groups.enumerated() {
            let id = "swap-block-\(index)"
            members[id] = group
            let box = group.dropFirst().reduce(group[0].frame) { $0.union($1.frame) }
            let movable = group.count <= limit && group.allSatisfy { eligible.contains($0.id) }
            blocks.append(WindowInfo(id: id, appID: id, appName: "Window group", frame: box,
                                     displayID: display.id, movable: movable, focused: false,
                                     skipReason: movable ? nil : "Stationary group"))
        }
        let otherDisplays = world.filter { $0.displayID != display.id }
        // Try bounded subsets, counting real windows rather than bounding rectangles.
        let available = blocks.filter(\.movable).shuffled(using: &rng)
        var best: MovementPlan?
        for _ in 0..<24 {
            var budget = limit
            let chosen = available.shuffled(using: &rng).filter { block in
                let count = members[block.id]!.count
                guard count <= budget else { return false }
                budget -= count
                return true
            }
            guard let plan = freeSwap(candidates: chosen, world: blocks + otherDisplays,
                                      display: display, limit: chosen.count, allowOverlap: allowOverlap,
                                      allowVacantDestinations: true, rng: &rng) else { continue }
            let moves = plan.moves.flatMap { move in
                members[move.windowID, default: []].map { member in
                    Move(windowID: member.id, from: member.frame,
                         to: member.frame.offsetBy(dx: move.to.minX - move.from.minX, dy: move.to.minY - move.from.minY))
                }
            }
            guard moves.count <= limit,
                  let steps = safeSteps(moves: moves, world: world, area: display.usableFrame,
                                        allowTransientOverlap: allowOverlap) else { continue }
            if moves.count > (best?.windowCount ?? 0) { best = MovementPlan(moves: moves, steps: steps, reason: "") }
            if best?.windowCount == min(limit, eligible.count) { break }
        }
        return best
    }
}
