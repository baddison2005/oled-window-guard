import XCTest
@testable import OLEDWindowGuard

final class GroupRoundingTests: XCTestCase {
    func testRoundingToleranceIsSourceOnlyAndBoundedToTwoPoints() {
        let helper = MovementTests()
        let source = CGRect(x: 200, y: 24, width: 200, height: 200)
        let destination = CGRect(x: 700, y: 24, width: 200, height: 200)
        func plan(x: CGFloat, target: CGRect = CGRect(x: 700, y: 24, width: 200, height: 200)) -> MovementPlan? {
            let window = helper.window("a", x, 24, 200, 200)
            var rng = MovementTests.RNG(state: 1)
            return MovementPlanner.groupAssignment(candidates: [window], zones: [source, target], world: [window],
                                                    display: helper.display, limit: 1, tolerance: 0.05, rng: &rng)
        }
        XCTAssertEqual(plan(x: 201)?.moves.first?.to, destination)
        XCTAssertEqual(plan(x: 199)?.moves.first?.to, destination)
        XCTAssertEqual(plan(x: 202)?.moves.first?.to, destination)
        XCTAssertNil(plan(x: 203))
        XCTAssertNil(plan(x: 201, target: CGRect(x: 700, y: 24, width: 199, height: 200)))
    }

    func testPreflightAcceptsRoundedSourceButFinalRequiresExactZone() {
        let helper = MovementTests()
        let w = helper.window("a", 201, 24, 200, 200)
        let snapshot = DesktopSnapshot(displays: [helper.display], windows: [w])
        let regions = ["main": [CGRect(x: 200, y: 24, width: 200, height: 200)]]
        XCTAssertFalse(SnapshotValidation.safePositions(snapshot, moving: ["a"], regions: regions))
        XCTAssertTrue(SnapshotValidation.safePositions(snapshot, moving: ["a"], regions: regions, sourceRounding: true))
        let blocked = DesktopSnapshot(displays: [helper.display], windows: [w, helper.window("b", 400, 24)])
        XCTAssertFalse(SnapshotValidation.safePositions(blocked, moving: ["a"], regions: regions, sourceRounding: true))
    }

    func testRoundingShrinkHasVerifiedSeparateStepsAndReversibleSize() throws {
        let helper = MovementTests()
        var w = helper.window("a", 200, 24, 200, 200); w.resizable = true
        let zones = [w.frame, CGRect(x: 700, y: 24, width: 198, height: 199)]
        var rng = MovementTests.RNG(state: 1)
        let plan = try XCTUnwrap(MovementPlanner.groupAssignment(candidates: [w], zones: zones, world: [w],
            display: helper.display, limit: 1, tolerance: 0.05, rng: &rng))
        XCTAssertEqual(plan.moves.first?.to, zones[1])
        XCTAssertEqual(plan.steps.count, 2)
        XCTAssertEqual(plan.steps[0].to.origin, w.frame.origin)
        XCTAssertEqual(plan.steps[0].to.size, zones[1].size)
        XCTAssertTrue(plan.steps[0].permitsRoundingResize)
        XCTAssertFalse(plan.steps[1].permitsRoundingResize)
        let after = MovementPlanner.applying(plan.steps, to: [w])
        let restored = MovementPlanner.applying(plan.steps.reversed().map(\.reversed), to: after)
        XCTAssertEqual(restored, [w])
        XCTAssertTrue(plan.steps.allSatisfy { $0.validSizeChange && $0.reversed.validSizeChange })
        XCTAssertFalse(Move(windowID: "a", from: w.frame, to: zones[1]).validSizeChange)
        XCTAssertFalse(Move(windowID: "a", from: w.frame, to: CGRect(x: 700, y: 24, width: 197, height: 200), permitsRoundingResize: true).validSizeChange)
        var rng2 = MovementTests.RNG(state: 1)
        XCTAssertNil(MovementPlanner.groupAssignment(candidates: [w], zones: [w.frame, CGRect(x: 700, y: 24, width: 197, height: 200)], world: [w],
            display: helper.display, limit: 1, tolerance: 0.05, rng: &rng2))
    }

    func testExcelReachesBothBottomZonesWithRoundedSourceWindow() {
        let helper = MovementTests()
        let area = CGRect(x: -1239, y: -2160, width: 5120, height: 2160)
        let display = DisplayInfo(id: "main", name: "LG", frame: area, usableFrame: area, scale: 1)
        var zones: [LayoutZone] = []
        for y in [0.0, 1.0 / 3] { for x in [0.0, 1.0 / 3, 2.0 / 3] {
            zones.append(LayoutZone(id: UUID(), name: "Tall", x: x, y: y, width: 1.0 / 3, height: 2.0 / 3, groupId: nil))
        } }
        for y in [0.0, 2.0 / 3] { for x in [0.0, 1.0 / 3] {
            zones.append(LayoutZone(id: UUID(), name: "Wide", x: x, y: y, width: 2.0 / 3, height: 1.0 / 3, groupId: nil))
        } }
        let group = ImportedGroup(id: "g", name: "Grouping 1", zones: zones, padding: 0)
        let windows = [helper.window("excel", 468, -2160, 3413, 720),
                       helper.window("finder1", -1239, -2160, 1707, 1440),
                       helper.window("textmate", 468, -1440, 1707, 1440),
                       helper.window("finder2", 2175, -1440, 1706, 1440)]
        var p = helper.preferences; p.mode = .group; p.rotateGroup = true; p.maximumWindows = 8
        var bottomXs = Set<CGFloat>()
        for seed in 1...100 {
            var rng = MovementTests.RNG(state: UInt64(seed))
            let plan = MovementPlanner().plan(snapshot: DesktopSnapshot(displays: [display], windows: windows),
                                              preferences: p, anchors: [:], group: group, rng: &rng)
            XCTAssertEqual(plan.windowCount, 4)
            XCTAssertTrue(MovementPlanner.safeFinal(moves: plan.moves, world: windows, area: area))
            XCTAssertTrue(plan.moves.allSatisfy { move in group.frames(on: display).contains { Geometry.contains($0, move.to) } })
            if let excel = plan.moves.first(where: { $0.windowID == "excel" }), excel.to.minY == -720 {
                bottomXs.insert(excel.to.minX)
            }
        }
        XCTAssertEqual(bottomXs, [-1239, 468])
    }
}
