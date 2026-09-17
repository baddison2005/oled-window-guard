import Foundation
import CoreGraphics

/// Pure geometry: every final rectangle and, by default, every intermediate step is checked.
struct MovementPlanner {
    func plan<R: RandomNumberGenerator>(snapshot: DesktopSnapshot, preferences p: Preferences,
                                       anchors: [String: WindowAnchor], group: ImportedGroup?, rng: inout R) -> MovementPlan {
        var result = MovementPlan()
        var reducedShifts = 0
        var world = snapshot.windows
        for display in snapshot.displays where p.selectedDisplays.contains(display.id) {
            let candidates = world.filter { window in
                window.displayID == display.id && window.movable && window.skipReason == nil
                && !p.excludedApps.contains(window.appID) && !(p.avoidFocusedWindow && window.focused)
                && Geometry.contains(display.usableFrame, window.frame) && !Geometry.maximized(window.frame, display: display)
                // Already overlapping windows remain obstacles, not movement candidates.
                && !world.contains(where: { other in other.id != window.id && Geometry.overlaps(other.frame, window.frame) })
            }.shuffled(using: &rng)
            let remaining = p.maximumWindows - result.moves.count
            guard remaining > 0 else { break }
            let rotate = p.mode == .swap || (p.mode == .group && p.rotateGroup)
            let zones = p.mode == .group ? group?.frames(on: display) : nil
            if p.mode == .group && zones == nil {
                result.reason = "Choose a saved Window Layouts group first."
                continue
            }
            if rotate, let zones {
                if let accepted = Self.groupAssignment(candidates: candidates, zones: zones, world: world,
                                                       display: display, limit: remaining, tolerance: p.sizeTolerance, padding: group?.padding ?? 0, rng: &rng) {
                    result.moves += accepted.moves
                    result.steps += accepted.steps
                    world = Self.applying(accepted.moves, to: world)
                } else {
                    result.reason = "No compatible group arrangement fits around the stationary windows. Try increasing the window limit or including the focused window."
                }
            } else if rotate && p.keepSimilarWindowsTogether {
                if let grouped = Self.groupedSwap(candidates: candidates, world: world, display: display,
                                                  limit: remaining, tolerance: p.sizeTolerance,
                                                  allowOverlap: p.allowTransientOverlap, rng: &rng) {
                    result.moves += grouped.moves
                    result.steps += grouped.steps
                    world = Self.applying(grouped.moves, to: world)
                } else {
                    result.reason = "No swap keeps the adjacent groups together within the window limit and available space."
                }
            } else if rotate {
                var available = candidates
                if let zones {
                    available = available.filter { window in zones.filter { Geometry.contains($0, window.frame) }.count == 1 }
                }
                let capacity = min(remaining, available.count)
                guard capacity >= 2 else {
                    result.reason = "Swap positions needs at least two eligible windows on \(display.name). Choose Shift position for a single window."
                    continue
                }
                var accepted: MovementPlan?
                // Try rotations of up to 12 windows, then pairs; keep the search bounded.
                for _ in 0..<40 where accepted == nil {
                    let sample = Array(available.shuffled(using: &rng).prefix(capacity))
                    for count in stride(from: sample.count, through: 2, by: -1) {
                        let windows = Array(sample.prefix(count))
                        guard windows.allSatisfy({ a in windows.allSatisfy { b in Geometry.similar(a.frame, b.frame, tolerance: p.sizeTolerance) } }) else { continue }
                        if let zones {
                            let memberships = windows.compactMap { w in zones.firstIndex(where: { Geometry.contains($0, w.frame) }) }
                            guard Set(memberships).count == windows.count else { continue }
                        }
                        let moves = windows.indices.map { i -> Move in
                            let w = windows[i], destination = windows[(i + 1) % windows.count]
                            return Move(windowID: w.id, from: w.frame, to: CGRect(origin: destination.frame.origin, size: w.frame.size))
                        }
                        if let zones, !moves.allSatisfy({ m in zones.contains { Geometry.contains($0, m.to) } }) { continue }
                        if let steps = Self.safeSteps(moves: moves, world: world, area: display.usableFrame,
                                                      allowTransientOverlap: p.allowTransientOverlap, stagingAreas: zones) {
                            accepted = MovementPlan(moves: moves, steps: steps, reason: "")
                            break
                        }
                    }
                }
                if (accepted?.windowCount ?? 0) < capacity,
                   let coordinated = Self.freeSwap(candidates: candidates, world: world, display: display,
                                                    limit: remaining, allowOverlap: p.allowTransientOverlap, rng: &rng),
                   coordinated.windowCount > (accepted?.windowCount ?? 0) {
                    accepted = coordinated
                }
                if let accepted {
                    result.moves += accepted.moves
                    result.steps += accepted.steps
                    world = Self.applying(accepted.moves, to: world)
                } else if !p.allowTransientOverlap {
                    result.reason = "No safe swap fits. Swaps need a free staging space, or you can allow brief overlap during swaps."
                }
            } else {
                // Larger Gaussian samples can trigger a coordinated reorder. Otherwise retain ordinary shifts.
                if p.shiftReorderingEnabled, Self.gaussianShiftMagnitude(rng: &rng) >= 0.6,
                   let coordinated = Self.freeSwap(candidates: candidates, world: world, display: display,
                       limit: remaining, allowOverlap: true, allowVacantDestinations: true, shiftPolicy: p, rng: &rng) {
                    result.moves += coordinated.moves
                    result.steps += coordinated.steps
                    world = Self.applying(coordinated.moves, to: world)
                    continue
                }
                for window in candidates {
                    guard result.moves.count < p.maximumWindows else { break }
                    var area = display.usableFrame
                    if let zones {
                        let matches = zones.filter { Geometry.contains($0, window.frame) }
                        guard matches.count == 1, let zone = matches.first else { continue }
                        area = area.intersection(zone)
                    }
                    let anchor = anchors[window.id]?.originFrame ?? window.frame
                    if let target = Self.driftTarget(window: window, anchor: anchor,
                        previous: anchors[window.id]?.previousFrame, area: area, display: display,
                        percent: p.driftRangePercent, world: world, gaussian: p.mode == .drift, rng: &rng) {
                        if p.mode == .drift && Self.shiftMagnitude(from: window.frame, to: target, display: display, percent: p.driftRangePercent) < 0.2 { reducedShifts += 1 }
                        let move = Move(windowID: window.id, from: window.frame, to: target)
                        result.moves.append(move)
                        result.steps.append(move)
                        world = Self.applying([move], to: world)
                    }
                }
            }
        }
        if !result.moves.isEmpty { result.reason = "Ready to move \(result.windowCount) window\(result.windowCount == 1 ? "" : "s")." }
        if reducedShifts > 0 { result.reason += " Limited space required smaller shifts for \(reducedShifts) window(s), below the preferred minimum." }
        return result
    }

    /// Assign mixed window shapes jointly: group zones are alternative destinations,
    /// not a partition. An occupied destination becomes available if its occupant moves.
    static func groupAssignment<R: RandomNumberGenerator>(candidates: [WindowInfo], zones: [CGRect],
        world: [WindowInfo], display: DisplayInfo, limit: Int, tolerance: Double, padding: CGFloat = 0, rng: inout R) -> MovementPlan? {
        let resizeLimit = GroupPaddingPolicy.resizeLimit(padding)
        let sourceAllowance = GroupPaddingPolicy.sourceAllowance(padding)
        var entries: [(window: WindowInfo, targets: [CGRect])] = []
        for window in candidates {
            // Recognize source frames with padding and rounding discrepancies.
            // This does not relax final containment; destinations
            // must still contain the final window and pass exact collision checks.
            let sources = zones.filter { Geometry.contains($0.insetBy(dx: -sourceAllowance, dy: -sourceAllowance), window.frame) }
            guard !sources.isEmpty else { continue }
            var targets: [CGRect] = []
            for source in sources {
                for zone in zones where !Geometry.close(source, zone)
                    && Geometry.similar(source, zone, tolerance: tolerance) {
                    // Preserve size and relative inset, clamping the origin only when
                    // a similar destination has less spare room.
                    let size = CGSize(width: min(window.frame.width, zone.width), height: min(window.frame.height, zone.height))
                    guard size == window.frame.size || (window.resizable && window.frame.width - size.width <= resizeLimit
                        && window.frame.height - size.height <= resizeLimit) else { continue }
                    let target = CGRect(x: max(zone.minX, min(zone.maxX - size.width, zone.minX + window.frame.minX - source.minX)),
                                        y: max(zone.minY, min(zone.maxY - size.height, zone.minY + window.frame.minY - source.minY)),
                                        width: size.width, height: size.height)
                    guard Geometry.contains(display.usableFrame, target), Geometry.contains(zone, target),
                          !Geometry.close(target, window.frame),
                          !targets.contains(where: { Geometry.close($0, target) }) else { continue }
                    targets.append(target)
                }
            }
            if !targets.isEmpty { entries.append((window, targets.shuffled(using: &rng))) }
        }
        // Constrained shapes first. Randomized ties and destinations vary successive cycles.
        entries.sort { $0.targets.count < $1.targets.count }
        let participants = Set(entries.map { $0.window.id })
        let obstacles = world.filter { !participants.contains($0.id) }.map(\.frame)
        var assigned: [CGRect] = []
        var moves: [Move] = []
        var best: [Move] = []
        var visited = 0
        let targetCount = min(limit, entries.count)
        func search(_ index: Int) {
            guard visited < 50_000, best.count < targetCount,
                  moves.count + entries.count - index > best.count else { return }
            visited += 1
            if index == entries.count {
                if moves.count > best.count { best = moves }
                return
            }
            let entry = entries[index]
            let choices = (moves.count < limit ? entry.targets : []) + [entry.window.frame]
            for target in choices {
                guard !obstacles.contains(where: { Geometry.overlaps($0, target) }),
                      !assigned.contains(where: { Geometry.overlaps($0, target) }) else { continue }
                let moved = !Geometry.close(target, entry.window.frame)
                assigned.append(target)
                if moved { moves.append(Move(windowID: entry.window.id, from: entry.window.frame, to: target,
                                             permitsRoundingResize: entry.window.frame.size != target.size, roundingResizeLimit: resizeLimit)) }
                search(index + 1)
                if moved { moves.removeLast() }
                assigned.removeLast()
                if best.count == targetCount || visited >= 50_000 { break }
            }
        }
        search(0)
        guard let steps = safeSteps(moves: best, world: world, area: display.usableFrame,
                                   allowTransientOverlap: true, stagingAreas: zones) else { return nil }
        // A size write and a position write are separate verified operations. Shrink
        // at the original location first, so failure recovery can reverse each step.
        let operations = steps.flatMap { move -> [Move] in
            guard move.from.size != move.to.size else { return [move] }
            let resized = CGRect(origin: move.from.origin, size: move.to.size)
            return [Move(windowID: move.windowID, from: move.from, to: resized, permitsRoundingResize: true, roundingResizeLimit: move.roundingResizeLimit),
                    Move(windowID: move.windowID, from: resized, to: move.to)]
        }
        return MovementPlan(moves: best, steps: operations, reason: "")
    }

    static func driftTarget<R: RandomNumberGenerator>(window: WindowInfo, anchor: CGRect, previous: CGRect?,
        area: CGRect, display: DisplayInfo, percent: Double, world: [WindowInfo], gaussian: Bool = false, rng: inout R) -> CGRect? {
        let dx = display.usableFrame.width * min(100, max(1, percent)) / 100
        let dy = display.usableFrame.height * min(100, max(1, percent)) / 100
        // Shift position can roam; only group-zone drift remains tied to its origin.
        let reference = gaussian ? window.frame : anchor
        let left = ceil(max(area.minX, reference.minX - dx, window.frame.minX - dx))
        let right = floor(min(area.maxX - window.frame.width, reference.minX + dx, window.frame.minX + dx))
        let top = ceil(max(area.minY, reference.minY - dy, window.frame.minY - dy))
        let bottom = floor(min(area.maxY - window.frame.height, reference.minY + dy, window.frame.minY + dy))
        guard left <= right, top <= bottom else { return nil }
        let obstacles = world.filter { $0.id != window.id }.map(\.frame)
        if gaussian {
            return gaussianTarget(window: window, previous: previous, area: area, display: display,
                                  percent: percent, obstacles: obstacles, bounds: CGRect(x: left, y: top, width: right-left, height: bottom-top), rng: &rng)
        }
        var targets: [CGRect] = []
        for _ in 0..<128 {
            targets.append(CGRect(x: CGFloat.random(in: left...right, using: &rng).rounded(),
                                  y: CGFloat.random(in: top...bottom, using: &rng).rounded(),
                                  width: window.frame.width, height: window.frame.height))
        }
        // Edge candidates also find narrow gaps that random sampling can miss.
        let xs = Set([left, right, window.frame.minX] + obstacles.flatMap { [$0.maxX, $0.minX - window.frame.width] })
        let ys = Set([top, bottom, window.frame.minY] + obstacles.flatMap { [$0.maxY, $0.minY - window.frame.height] })
        for x in xs where x >= left && x <= right { for y in ys where y >= top && y <= bottom {
            targets.append(CGRect(x: x, y: y, width: window.frame.width, height: window.frame.height))
        } }
        let safe = targets.filter { target in
            !Geometry.close(target, window.frame) && Geometry.contains(area, target)
            && !obstacles.contains { Geometry.overlaps($0, target) }
        }
        let fresh = safe.filter { target in previous.map { !Geometry.close($0, target) } ?? true }
        // Favor substantial moves, while retaining randomness and a safe fallback.
        return (fresh.isEmpty ? safe : fresh).shuffled(using: &rng).prefix(16).max {
            hypot(($0.minX - window.frame.minX) / dx, ($0.minY - window.frame.minY) / dy)
            < hypot(($1.minX - window.frame.minX) / dx, ($1.minY - window.frame.minY) / dy)
        }
    }

    /// Unit magnitude: 0.2...1, mean 0.6, caps at ±1.5σ. Tail samples stay at the caps.
    static func gaussianShiftMagnitude<R: RandomNumberGenerator>(rng: inout R) -> Double {
        let u = max(Double.leastNonzeroMagnitude, Double.random(in: 0..<1, using: &rng))
        let angle = Double.random(in: 0..<(2 * .pi), using: &rng)
        let normal = sqrt(-2 * log(u)) * cos(angle)
        return min(1, max(0.2, 0.6 + normal * (0.8 / 3)))
    }

    static func shiftMagnitude(from: CGRect, to: CGRect, display: DisplayInfo, percent: Double) -> Double {
        let range = min(100, max(1, percent)) / 100
        return hypot((to.minX-from.minX)/(display.usableFrame.width*range),
                     (to.minY-from.minY)/(display.usableFrame.height*range))
    }

    private static func gaussianTarget<R: RandomNumberGenerator>(window: WindowInfo, previous: CGRect?,
        area: CGRect, display: DisplayInfo, percent: Double, obstacles: [CGRect], bounds: CGRect, rng: inout R) -> CGRect? {
        let dx = display.usableFrame.width * min(100, max(1, percent)) / 100
        let dy = display.usableFrame.height * min(100, max(1, percent)) / 100
        func magnitude(_ target: CGRect) -> Double { shiftMagnitude(from: window.frame, to: target, display: display, percent: percent) }
        func safe(_ target: CGRect) -> Bool {
            target.minX >= bounds.minX && target.minX <= bounds.maxX
                && target.minY >= bounds.minY && target.minY <= bounds.maxY
                && magnitude(target) <= 1 + 1e-9 && !Geometry.close(target, window.frame)
                && Geometry.contains(area, target) && !obstacles.contains { Geometry.overlaps($0, target) }
        }
        func fresh(_ target: CGRect) -> Bool { previous.map { !Geometry.close($0, target) } ?? true }
        var reversals: [CGRect] = []
        // Preserve the sampled distance while trying independent directions first.
        for _ in 0..<16 {
            let radius = gaussianShiftMagnitude(rng: &rng)
            for _ in 0..<32 {
                let theta = Double.random(in: 0..<(2 * .pi), using: &rng)
                let rounding: FloatingPointRoundingRule = radius == 0.2 ? .awayFromZero : .towardZero
                let target = window.frame.offsetBy(dx: (cos(theta)*radius*dx).rounded(rounding),
                                                   dy: (sin(theta)*radius*dy).rounded(rounding))
                guard safe(target), magnitude(target) >= 0.2 else { continue }
                if fresh(target) { return target }
                reversals.append(target)
            }
        }
        // Include obstacle edges to find thin safe corridors missed by random directions.
        let xs = Set([bounds.minX, bounds.maxX, window.frame.minX] + obstacles.flatMap { [$0.maxX, $0.minX-window.frame.width] }).sorted()
        let ys = Set([bounds.minY, bounds.maxY, window.frame.minY] + obstacles.flatMap { [$0.maxY, $0.minY-window.frame.height] }).sorted()
        var alternatives: [CGRect] = []
        for x in xs { for y in ys {
            let target = CGRect(origin: CGPoint(x: x, y: y), size: window.frame.size)
            if safe(target) { alternatives.append(target) }
        } }
        // Search larger distances too: narrow openings can defeat the initial direction samples.
        // Then progressively relax only the preferred minimum.
        for upper in [1.0, 0.5, 0.2, 0.1, 0.05] {
            for _ in 0..<96 {
                let radius = Double.random(in: (upper/2)...upper, using: &rng)
                let theta = Double.random(in: 0..<(2 * .pi), using: &rng)
                let target = window.frame.offsetBy(dx: (cos(theta)*radius*dx).rounded(.towardZero),
                                                   dy: (sin(theta)*radius*dy).rounded(.towardZero))
                if safe(target) { alternatives.append(target) }
            }
        }
        let newTargets = alternatives.filter(fresh)
        let pool = newTargets.isEmpty ? alternatives + reversals : newTargets
        for minimum in [0.2, 0.1, 0.05, 0.0] {
            let band = pool.filter { magnitude($0) >= minimum }
            if !band.isEmpty {
                let desired = gaussianShiftMagnitude(rng: &rng)
                return band.shuffled(using: &rng).min { abs(magnitude($0)-desired) < abs(magnitude($1)-desired) }
            }
        }
        return nil
    }

    /// Rearrange different-sized windows without predefined zones. Destinations
    /// occupy space another participant vacates; stationary windows remain barriers.
    static func freeSwap<R: RandomNumberGenerator>(candidates: [WindowInfo], world: [WindowInfo],
        display: DisplayInfo, limit: Int, allowOverlap: Bool, allowVacantDestinations: Bool = false, shiftPolicy: Preferences? = nil,
        rng: inout R) -> MovementPlan? {
        let minimumMoves = allowVacantDestinations ? 1 : 2
        guard limit >= minimumMoves, candidates.count >= minimumMoves else { return nil }
        let area = display.usableFrame
        let entries = candidates.sorted { $0.frame.width * $0.frame.height > $1.frame.width * $1.frame.height }.map { w in
            let desired = shiftPolicy == nil ? 0 : gaussianShiftMagnitude(rng: &rng)
            let right = area.maxX - w.frame.width, bottom = area.maxY - w.frame.height
            let xs = Set([area.minX, right, area.minX + right - w.frame.minX]
                + candidates.flatMap { [$0.frame.minX, $0.frame.maxX - w.frame.width, $0.frame.maxX, $0.frame.minX - w.frame.width] })
            let ys = Set([area.minY, bottom, area.minY + bottom - w.frame.minY]
                + (1...3).map { area.minY + (bottom - area.minY) * CGFloat($0) / 4 }
                + candidates.flatMap { [$0.frame.minY, $0.frame.maxY - w.frame.height, $0.frame.maxY, $0.frame.minY - w.frame.height] })
            var targets: [CGRect] = []
            for x in xs.sorted() { for y in ys.sorted() {
                let target = CGRect(x: x.rounded(), y: y.rounded(), width: w.frame.width, height: w.frame.height)
                if Geometry.contains(area, target), !Geometry.close(w.frame, target),
                   (allowVacantDestinations || candidates.contains(where: { $0.id != w.id && Geometry.overlaps($0.frame, target) })) {
                    if let policy = shiftPolicy {
                        let distance = shiftMagnitude(from: w.frame, to: target, display: display, percent: policy.driftRangePercent)
                        guard distance >= 0.2, distance <= 1 + 1e-9 else { continue }
                    }
                    targets.append(target)
                }
            } }
            targets.shuffle(using: &rng)
            if let policy = shiftPolicy {
                targets.sort { abs(shiftMagnitude(from: w.frame, to: $0, display: display, percent: policy.driftRangePercent) - desired)
                    < abs(shiftMagnitude(from: w.frame, to: $1, display: display, percent: policy.driftRangePercent) - desired) }
            }
            return (window: w, targets: targets)
        }
        let ids = Set(candidates.map(\.id))
        let obstacles = world.filter { !ids.contains($0.id) }.map(\.frame)
        var occupied: [CGRect] = [], moves: [Move] = []
        var best: MovementPlan?
        var visited = 0
        let goal = min(limit, entries.count)
        func search(_ index: Int) {
            guard visited < 50_000, (best?.windowCount ?? 0) < goal,
                  moves.count + entries.count - index > (best?.windowCount ?? 0) else { return }
            visited += 1
            if index == entries.count {
                guard moves.count >= minimumMoves else { return }
                if let policy = shiftPolicy {
                    guard moves.contains(where: { shiftMagnitude(from: $0.from, to: $0.to, display: display, percent: policy.driftRangePercent) >= 0.4 }),
                          shiftOrderAllowed(moves: moves, candidates: candidates, policy: policy) else { return }
                }
                guard let steps = safeSteps(moves: moves, world: world, area: area, allowTransientOverlap: allowOverlap) else { return }
                best = MovementPlan(moves: moves, steps: steps, reason: "")
                return
            }
            let entry = entries[index]
            for target in (moves.count < limit ? entry.targets : []) + [entry.window.frame] {
                guard !obstacles.contains(where: { Geometry.overlaps($0, target) }),
                      !occupied.contains(where: { Geometry.overlaps($0, target) }) else { continue }
                let moved = !Geometry.close(entry.window.frame, target)
                occupied.append(target)
                if moved { moves.append(Move(windowID: entry.window.id, from: entry.window.frame, to: target)) }
                search(index + 1)
                occupied.removeLast()
                if moved { moves.removeLast() }
                if visited >= 50_000 || best?.windowCount == goal { break }
            }
        }
        search(0)
        return best
    }

    /// A coordinated shift must reverse an enabled axis and preserve ordering on disabled axes.
    static func shiftOrderAllowed(moves: [Move], candidates: [WindowInfo], policy: Preferences) -> Bool {
        let final = applying(moves, to: candidates)
        var reordered = false
        for i in candidates.indices {
            for j in candidates.indices where j > i {
                let horizontal = (candidates[i].frame.midX - candidates[j].frame.midX) * (final[i].frame.midX - final[j].frame.midX) < -1
                let vertical = (candidates[i].frame.midY - candidates[j].frame.midY) * (final[i].frame.midY - final[j].frame.midY) < -1
                if horizontal && !policy.allowHorizontalShiftReordering { return false }
                if vertical && !policy.allowVerticalShiftReordering { return false }
                reordered = reordered || horizontal || vertical
            }
        }
        return reordered
    }

    static func applying(_ moves: [Move], to windows: [WindowInfo]) -> [WindowInfo] {
        windows.map { w in
            guard let move = moves.last(where: { $0.windowID == w.id }) else { return w }
            return WindowInfo(id: w.id, appID: w.appID, appName: w.appName, frame: move.to,
                              displayID: w.displayID, movable: w.movable, focused: w.focused, skipReason: w.skipReason, resizable: w.resizable)
        }
    }

    static func safeFinal(moves: [Move], world: [WindowInfo], area: CGRect) -> Bool {
        guard !moves.isEmpty, Set(moves.map(\.windowID)).count == moves.count,
              moves.allSatisfy({ m in Geometry.contains(area, m.to) && m.validSizeChange
                  && (m.from.size == m.to.size || world.first(where: { $0.id == m.windowID })?.resizable == true)
                  && world.contains(where: { $0.id == m.windowID && Geometry.close($0.frame, m.from) }) }) else { return false }
        let final = applying(moves, to: world)
        return moves.allSatisfy { move in !final.contains { $0.id != move.windowID && Geometry.overlaps($0.frame, move.to) } }
    }

    static func safeSteps(moves: [Move], world: [WindowInfo], area: CGRect, allowTransientOverlap: Bool,
                          stagingAreas: [CGRect]? = nil) -> [Move]? {
        guard safeFinal(moves: moves, world: world, area: area) else { return nil }
        if allowTransientOverlap { return moves }
        var current = world
        var pending = moves
        var steps: [Move] = []
        var staged = Set<String>()
        while !pending.isEmpty {
            if let index = pending.firstIndex(where: { move in
                !current.contains { $0.id != move.windowID && Geometry.overlaps($0.frame, move.to) }
            }) {
                let move = pending.remove(at: index)
                guard let existing = current.first(where: { $0.id == move.windowID }) else { return nil }
                let step = Move(windowID: move.windowID, from: existing.frame, to: move.to)
                steps.append(step)
                current = applying([step], to: current)
            } else {
                // Break a swap cycle only when there is an entirely empty on-screen staging rectangle.
                guard let move = pending.first(where: { !staged.contains($0.windowID) }),
                      let existing = current.first(where: { $0.id == move.windowID }),
                      let staging = (stagingAreas ?? [area]).compactMap({ stagingFrame(size: existing.frame.size, world: current,
                                                                                      destinations: moves.map(\.to), area: area.intersection($0)) }).first
                else { return nil }
                let step = Move(windowID: move.windowID, from: existing.frame, to: staging)
                steps.append(step)
                current = applying([step], to: current)
                staged.insert(move.windowID)
            }
        }
        return steps
    }

    static func stagingFrame(size: CGSize, world: [WindowInfo], destinations: [CGRect], area: CGRect) -> CGRect? {
        let obstacles = world.map(\.frame) + destinations
        let xs = Set([area.minX, area.maxX - size.width] + obstacles.flatMap { [$0.maxX, $0.minX - size.width] })
        let ys = Set([area.minY, area.maxY - size.height] + obstacles.flatMap { [$0.maxY, $0.minY - size.height] })
        for x in xs.sorted() { for y in ys.sorted() {
            let rect = CGRect(origin: CGPoint(x: x, y: y), size: size)
            if Geometry.contains(area, rect) && !obstacles.contains(where: { Geometry.overlaps($0, rect) }) { return rect }
        } }
        return nil
    }
}
