import XCTest
@testable import OLEDWindowGuard

final class GaussianShiftTests: XCTestCase {
    func testCoordinatedHorizontalShiftsRespectRangeAndOptIn() {
        let fixture = MovementTests()
        let windows = [fixture.window("a", 0, 24, 800, 740), fixture.window("b", 800, 24, 400, 740)]
        var p = fixture.preferences; p.driftRangePercent = 100
        XCTAssertTrue(fixture.plan(windows, p: p).moves.isEmpty)
        p.allowHorizontalShiftReordering = true
        var successes = 0
        for seed in 1...40 {
            let plan = fixture.plan(windows, p: p, seed: UInt64(seed))
            if plan.moves.isEmpty { continue }
            successes += 1
            XCTAssertEqual(plan.moves.count, 2)
            XCTAssertTrue(MovementPlanner.safeFinal(moves: plan.moves, world: windows, area: fixture.display.usableFrame))
            XCTAssertTrue(MovementPlanner.shiftOrderAllowed(moves: plan.moves, candidates: windows, policy: p))
            for move in plan.moves {
                XCTAssertEqual(move.from.size, move.to.size)
                XCTAssertLessThanOrEqual(MovementPlanner.shiftMagnitude(from: move.from, to: move.to, display: fixture.display, percent: 100), 1 + 1e-9)
            }
        }
        XCTAssertGreaterThan(successes, 0)
        p.driftRangePercent = 30
        for seed in 1...10 { XCTAssertTrue(fixture.plan(windows, p: p, seed: UInt64(seed)).moves.isEmpty) }
        p.driftRangePercent = 100; p.maximumWindows = 1
        XCTAssertTrue(fixture.plan(windows, p: p).moves.isEmpty)
        p.maximumWindows = 4; p.excludedApps = [windows[0].appID]
        XCTAssertTrue(fixture.plan(windows, p: p).moves.isEmpty)
    }

    func testVerticalReorderingAndDisabledAxis() {
        let fixture = MovementTests()
        let windows = [fixture.window("a", 0, 24, 1200, 370), fixture.window("b", 0, 394, 1200, 370)]
        var p = fixture.preferences; p.driftRangePercent = 100; p.allowHorizontalShiftReordering = true
        for seed in 1...10 { XCTAssertTrue(fixture.plan(windows, p: p, seed: UInt64(seed)).moves.isEmpty) }
        p.allowHorizontalShiftReordering = false; p.allowVerticalShiftReordering = true
        XCTAssertTrue((1...40).contains { !fixture.plan(windows, p: p, seed: UInt64($0)).moves.isEmpty })
    }

    func testShiftOrderPreferencesMigrationAndRoundTrip() throws {
        let encoded = try JSONEncoder().encode(Preferences())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "shiftHorizontalOrder"); object.removeValue(forKey: "shiftVerticalOrder")
        var p = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(p.shiftReorderingEnabled)
        p.allowHorizontalShiftReordering = true; p.allowVerticalShiftReordering = true
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(p))
        XCTAssertTrue(decoded.allowHorizontalShiftReordering); XCTAssertTrue(decoded.allowVerticalShiftReordering)
        XCTAssertTrue(decoded.permitsIntermediateOverlap)
        p.mode = .swap
        XCTAssertFalse(p.permitsIntermediateOverlap)
    }

    func testClampedGaussianDistribution() {
        var rng = MovementTests.RNG(state: 731)
        let samples = (0..<100_000).map { _ in MovementPlanner.gaussianShiftMagnitude(rng: &rng) }
        XCTAssertTrue(samples.allSatisfy { $0 >= 0.2 && $0 <= 1 })
        XCTAssertEqual(samples.reduce(0,+)/Double(samples.count), 0.6, accuracy: 0.004)
        XCTAssertEqual(Double(samples.filter { $0 == 0.2 }.count)/Double(samples.count), 0.0668, accuracy: 0.004)
        XCTAssertEqual(Double(samples.filter { $0 == 1 }.count)/Double(samples.count), 0.0668, accuracy: 0.004)
    }

    func testOpenSpaceUsesPreferredRangeAndVariedDirections() {
        let fixture = MovementTests()
        let w = fixture.window("a", 500, 330, 100, 100)
        var p = fixture.preferences; p.driftRangePercent = 25
        var directions = Set<Int>()
        var distances: [Double] = []
        for seed in 1...150 {
            let plan = fixture.plan([w], p: p, seed: UInt64(seed))
            guard let move = plan.moves.first else { return XCTFail("Expected a safe move") }
            let magnitude = MovementPlanner.shiftMagnitude(from: move.from, to: move.to, display: fixture.display, percent: 25)
            XCTAssertGreaterThanOrEqual(magnitude, 0.2)
            XCTAssertLessThanOrEqual(magnitude, 1)
            directions.insert((move.to.minX > move.from.minX ? 1 : 0) + (move.to.minY > move.from.minY ? 2 : 0))
            distances.append(magnitude)
        }
        XCTAssertEqual(directions.count, 4)
        XCTAssertLessThan(distances.reduce(0,+)/Double(distances.count), 0.7)
        XCTAssertGreaterThan(distances.reduce(0,+)/Double(distances.count), 0.5)
    }

    func testCrowdedScreenRelaxesMinimumWithoutOverlap() {
        let fixture = MovementTests()
        let moving = fixture.window("a", 0, 24, 100, 100)
        let right = fixture.window("right", 120, 24, 1080, 740, movable: false)
        let below = fixture.window("below", 0, 144, 120, 620, movable: false)
        var p = fixture.preferences; p.driftRangePercent = 50
        for seed in 1...30 {
            let plan = fixture.plan([moving,right,below], p: p, seed: UInt64(seed))
            guard let move = plan.moves.first else { return XCTFail("Expected a smaller safe shift") }
            XCTAssertLessThan(MovementPlanner.shiftMagnitude(from: move.from, to: move.to, display: fixture.display, percent: 50), 0.2)
            XCTAssertTrue(Geometry.contains(fixture.display.usableFrame, move.to))
            XCTAssertFalse(Geometry.overlaps(move.to, right.frame))
            XCTAssertFalse(Geometry.overlaps(move.to, below.frame))
            XCTAssertTrue(plan.reason.contains("smaller shifts"))
        }
    }

    func testCanReachDistantSlotOutsideOriginalAnchorRange() {
        let fixture = MovementTests()
        let moving = fixture.window("a", 400, 24, 100, 740)
        let barrier = fixture.window("barrier", 500, 24, 280, 740, movable: false)
        let farBarrier = fixture.window("far", 880, 24, 320, 740, movable: false)
        let leftBarrier = fixture.window("left", 0, 24, 400, 740, movable: false)
        var p = fixture.preferences; p.driftRangePercent = 50
        let anchor = WindowAnchor(originFrame: CGRect(x: 0, y: 24, width: 100, height: 740), lastFrame: moving.frame)
        for seed in 1...30 {
            let plan = fixture.plan([moving, barrier, farBarrier, leftBarrier], p: p,
                                    anchors: [moving.id: anchor], seed: UInt64(seed))
            XCTAssertEqual(plan.moves.count, 1)
            XCTAssertEqual(plan.moves.first?.to.minX, 780)
            XCTAssertEqual(plan.moves.first?.to.size, moving.frame.size)
        }
    }

    func testNoSpaceSkipsInsteadOfOverlapping() {
        let fixture = MovementTests()
        let moving = fixture.window("a", 0, 24, 100, 100)
        let right = fixture.window("right", 100, 24, 1100, 740, movable: false)
        let below = fixture.window("below", 0, 124, 100, 640, movable: false)
        XCTAssertTrue(fixture.plan([moving,right,below]).moves.isEmpty)
    }

    func testMultipleWindowsEveryStepAndFinalArrangementRemainSafe() {
        let fixture = MovementTests()
        let windows = [fixture.window("a", 0, 24, 200, 180), fixture.window("b", 400, 260, 200, 180), fixture.window("c", 900, 550, 200, 180)]
        var p = fixture.preferences; p.driftRangePercent = 50
        for seed in 1...75 {
            let plan = fixture.plan(windows, p: p, seed: UInt64(seed))
            var world = windows
            XCTAssertFalse(plan.moves.isEmpty)
            for step in plan.steps {
                XCTAssertLessThanOrEqual(MovementPlanner.shiftMagnitude(from: step.from, to: step.to, display: fixture.display, percent: 50), 1+1e-9)
                XCTAssertEqual(step.from.size, step.to.size)
                XCTAssertTrue(Geometry.contains(fixture.display.usableFrame, step.to))
                XCTAssertFalse(world.contains { $0.id != step.windowID && Geometry.overlaps($0.frame,step.to) })
                world = MovementPlanner.applying([step], to: world)
            }
        }
    }
}
