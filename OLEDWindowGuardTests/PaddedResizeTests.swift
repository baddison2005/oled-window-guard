import XCTest
@testable import OLEDWindowGuard

final class PaddedResizeTests: XCTestCase {
    func testCurrentTextMateLayoutParticipatesWithPadding() {
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
        let group = ImportedGroup(id: "g", name: "Grouping 1", zones: zones, padding: 4)
        let windows = [helper.window("excel", 472, -716, 3409, 716), helper.window("finder1", 2178, -2160, 1703, 1436),
                       helper.window("finder2", 472, -2160, 1698, 1436), helper.window("textmate", -1239, -1440, 1703, 1440)]
            .map { w in var w = w; w.resizable = true; return w }
        var p = helper.preferences; p.mode = .group; p.rotateGroup = true
        let baseline = DesktopSnapshot(displays: [display], windows: windows)
        for seed in 1...50 {
            var rng = MovementTests.RNG(state: UInt64(seed))
            let plan = MovementPlanner().plan(snapshot: baseline, preferences: p, anchors: [:], group: group, rng: &rng)
            XCTAssertEqual(plan.windowCount, 4)
            XCTAssertTrue(plan.moves.contains { $0.windowID == "textmate" && $0.to.height == 1436 })
            XCTAssertTrue(plan.moves.allSatisfy { $0.validSizeChange })
            XCTAssertTrue(MovementPlanner.safeFinal(moves: plan.moves, world: windows, area: area))
            let ids = Set(plan.moves.map(\.windowID)), regions = ["main": group.frames(on: display)]
            XCTAssertTrue(SnapshotValidation.safePositions(baseline, moving: ids, regions: regions, sourceRounding: true,
                                                           sourceAllowance: GroupPaddingPolicy.sourceAllowance(4)))
            let after = MovementPlanner.applying(plan.steps, to: windows)
            XCTAssertTrue(SnapshotValidation.safePositions(DesktopSnapshot(displays: [display], windows: after), moving: ids, regions: regions))
            XCTAssertEqual(MovementPlanner.applying(plan.steps.reversed().map(\.reversed), to: after), windows)
        }
    }
    func testPaddingResizeLimitIsBoundedAndPreservedForRestore() {
        XCTAssertEqual(GroupPaddingPolicy.resizeLimit(0), 2)
        XCTAssertEqual(GroupPaddingPolicy.resizeLimit(4), 10)
        XCTAssertEqual(GroupPaddingPolicy.resizeLimit(200), 32)
        let a = CGRect(x: 0, y: 0, width: 200, height: 200)
        let move = Move(windowID: "a", from: a, to: CGRect(x: 0, y: 0, width: 195, height: 196), permitsRoundingResize: true, roundingResizeLimit: 10)
        XCTAssertTrue(move.validSizeChange)
        XCTAssertTrue(move.reversed.validSizeChange)
        XCTAssertFalse(Move(windowID: "a", from: a, to: CGRect(x: 0, y: 0, width: 189, height: 200), permitsRoundingResize: true, roundingResizeLimit: 10).validSizeChange)
        XCTAssertFalse(Move(windowID: "a", from: a, to: move.to).validSizeChange)
        let partial = CGRect(x: 0, y: 0, width: 195, height: 200)
        XCTAssertTrue(move.acceptsPartialResize(partial))
        XCTAssertFalse(move.acceptsPartialResize(partial.offsetBy(dx: 1, dy: 0)))
        XCTAssertFalse(move.acceptsPartialResize(CGRect(x: 0, y: 0, width: 194, height: 200)))
        let first = Move(windowID: "a", from: a, to: partial, permitsRoundingResize: true, roundingResizeLimit: 10)
        let second = Move(windowID: "a", from: partial, to: move.to, permitsRoundingResize: true, roundingResizeLimit: 10)
        let helper = MovementTests()
        var window = helper.window("a", 0, 0, 200, 200); window.resizable = true
        let restored = MovementPlanner.applying([second.reversed, first.reversed], to: MovementPlanner.applying([first, second], to: [window]))
        XCTAssertEqual(restored, [window])
    }
}
