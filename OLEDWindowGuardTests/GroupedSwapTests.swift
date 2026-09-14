import XCTest
@testable import OLEDWindowGuard

final class GroupedSwapTests: XCTestCase {
    func testFinderBlockAndLargerChromeUseIndependentDestinations() {
        let helper = MovementTests()
        let display = DisplayInfo(id: "main", name: "LG", frame: CGRect(x: 468, y: -2160, width: 5120, height: 2160),
                                  usableFrame: CGRect(x: 468, y: -2160, width: 5120, height: 2160), scale: 1)
        let windows = [helper.window("chrome", 468, -2160, 1706, 2160),
                       helper.window("a", 2174, -2160, 854, 720), helper.window("b", 3028, -2160, 853, 720),
                       helper.window("c", 2174, -1440, 854, 720), helper.window("d", 3028, -1440, 853, 720)]
        var p = helper.preferences
        p.mode = .swap; p.keepSimilarWindowsTogether = true; p.maximumWindows = 8; p.allowTransientOverlap = true
        var relativeOffsets = Set<CGFloat>()
        var usesVacantSpace = false
        for seed in 1...30 {
            var rng = MovementTests.RNG(state: UInt64(seed))
            let plan = MovementPlanner().plan(snapshot: DesktopSnapshot(displays: [display], windows: windows),
                                              preferences: p, anchors: [:], group: nil, rng: &rng)
            XCTAssertEqual(plan.windowCount, 5)
            let finder = plan.moves.filter { $0.windowID != "chrome" }
            XCTAssertEqual(Set(finder.map { $0.to.minX - $0.from.minX }).count, 1)
            XCTAssertEqual(Set(finder.map { $0.to.minY - $0.from.minY }).count, 1)
            XCTAssertTrue(MovementPlanner.safeFinal(moves: plan.moves, world: windows, area: display.usableFrame))
            if let chrome = plan.moves.first(where: { $0.windowID == "chrome" }), let first = finder.first {
                relativeOffsets.insert(chrome.to.minX - first.to.minX)
            }
            usesVacantSpace = usesVacantSpace || plan.moves.contains { move in
                !windows.contains { $0.id != move.windowID && Geometry.overlaps($0.frame, move.to) }
            }
        }
        XCTAssertGreaterThan(relativeOffsets.count, 1)
        XCTAssertTrue(usesVacantSpace)
        // The Finder block remains intact and stationary when excluded; Chrome can still move into empty space.
        p.excludedApps = ["app.a"]
        var rng = MovementTests.RNG(state: 1)
        let plan = MovementPlanner().plan(snapshot: DesktopSnapshot(displays: [display], windows: windows),
                                          preferences: p, anchors: [:], group: nil, rng: &rng)
        XCTAssertEqual(plan.moves.map(\.windowID), ["chrome"])
    }

    func testSingleGroupCanMoveIntoVacantSpaceWithoutSwapPartner() {
        let helper = MovementTests()
        let windows = [helper.window("a", 0, 24, 200, 200), helper.window("b", 200, 24, 200, 200)]
        var p = helper.preferences; p.mode = .swap; p.keepSimilarWindowsTogether = true
        let plan = helper.plan(windows, p: p)
        XCTAssertEqual(plan.windowCount, 2)
        XCTAssertTrue(MovementPlanner.safeFinal(moves: plan.moves, world: windows, area: helper.display.usableFrame))
    }

    func testGroupMovesAsOneBlock() {
        let helper = MovementTests()
        let windows = [helper.window("large", 0, 24, 800, 740),
                       helper.window("a", 800, 24, 200, 370), helper.window("b", 1000, 24, 200, 370),
                       helper.window("c", 800, 394, 200, 370), helper.window("d", 1000, 394, 200, 370)]
        var p = helper.preferences
        p.mode = .swap; p.keepSimilarWindowsTogether = true; p.maximumWindows = 5; p.allowTransientOverlap = true
        let plan = helper.plan(windows, p: p)
        XCTAssertEqual(plan.windowCount, 5)
        let members = plan.moves.filter { $0.windowID != "large" }
        XCTAssertEqual(Set(members.map { $0.to.minX - $0.from.minX }).count, 1)
        XCTAssertEqual(Set(members.map { $0.to.minY - $0.from.minY }).count, 1)
        for move in plan.moves { XCTAssertEqual(move.from.size, move.to.size) }
        let final = MovementPlanner.applying(plan.moves, to: windows)
        for i in final.indices { for j in final.indices where j > i {
            XCTAssertFalse(Geometry.overlaps(final[i].frame, final[j].frame))
        } }
        p.maximumWindows = 4
        XCTAssertTrue(helper.plan(windows, p: p).moves.isEmpty)
        p.maximumWindows = 5; p.excludedApps = ["app.a"]
        XCTAssertTrue(helper.plan(windows, p: p).moves.isEmpty)
    }

    func testAdjacencyRequiresSharedEdgeAndSmallGap() {
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertTrue(MovementPlanner.adjacent(a, a.offsetBy(dx: 108, dy: 0)))
        XCTAssertFalse(MovementPlanner.adjacent(a, a.offsetBy(dx: 109, dy: 0)))
        XCTAssertFalse(MovementPlanner.adjacent(a, a.offsetBy(dx: 100, dy: 100)))
    }

    func testExistingPreferencesLeaveGroupingOff() throws {
        let data = try JSONEncoder().encode(Preferences())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "keepSwapGroups")
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(decoded.keepSimilarWindowsTogether)
    }
}
