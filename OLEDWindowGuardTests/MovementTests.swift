import XCTest
@testable import OLEDWindowGuard

final class MovementTests: XCTestCase {
    struct RNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    }
    let display = DisplayInfo(id: "main", name: "Test display", frame: CGRect(x: 0, y: 0, width: 1200, height: 800),
                              usableFrame: CGRect(x: 0, y: 24, width: 1200, height: 740), scale: 2)
    func window(_ id: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat = 250, _ h: CGFloat = 200,
                display: String = "main", movable: Bool = true, focused: Bool = false, reason: String? = nil) -> WindowInfo {
        WindowInfo(id: id, appID: "app.\(id)", appName: id, frame: CGRect(x: x, y: y, width: w, height: h),
                   displayID: display, movable: movable, focused: focused, skipReason: reason)
    }
    var preferences: Preferences { var p = Preferences(); p.selectedDisplays = ["main"]; p.automaticDistance = false; return p }
    func plan(_ windows: [WindowInfo], p: Preferences? = nil, anchors: [String: WindowAnchor] = [:], group: ImportedGroup? = nil, seed: UInt64 = 1) -> MovementPlan {
        var rng = RNG(state: seed)
        return MovementPlanner().plan(snapshot: DesktopSnapshot(displays: [display], windows: windows),
                                      preferences: p ?? preferences, anchors: anchors, group: group, rng: &rng)
    }

    func testDriftUsesDisplayPercentage() {
        let w = window("a", 200, 200)
        let move = plan([w]).moves[0]
        XCTAssertLessThanOrEqual(abs(move.to.minX - w.frame.minX), 120)
        XCTAssertLessThanOrEqual(abs(move.to.minY - w.frame.minY), 74)
        XCTAssertGreaterThan(max(abs(move.to.minX - w.frame.minX), abs(move.to.minY - w.frame.minY)), 32)
        XCTAssertEqual(move.from.size, move.to.size)
    }
    func testUnselectedMonitorDoesNotMove() {
        var p = preferences; p.selectedDisplays = ["other"]
        XCTAssertTrue(plan([window("a", 200, 200)], p: p).moves.isEmpty)
    }
    func testPercentageDriftVariesAndAvoidsImmediateReversal() {
        var p = preferences; p.driftRangePercent = 50
        var w = window("a", 400, 250, 150, 100)
        var anchor = WindowAnchor(originFrame: w.frame, lastFrame: w.frame)
        var positions = Set<String>()
        for seed in 1...100 {
            let result = plan([w], p: p, anchors: [w.id: anchor], seed: UInt64(seed))
            guard let move = result.moves.first else { XCTFail("Expected open-space drift"); return }
            if let previous = anchor.previousFrame { XCTAssertFalse(Geometry.close(previous, move.to)) }
            XCTAssertLessThanOrEqual(abs(move.to.minX - move.from.minX), 600)
            XCTAssertLessThanOrEqual(abs(move.to.minY - move.from.minY), 370)
            positions.insert("\(move.to.minX),\(move.to.minY)")
            anchor.previousFrame = move.from; anchor.lastFrame = move.to
            w = MovementPlanner.applying([move], to: [w])[0]
        }
        XCTAssertGreaterThan(positions.count, 20)
    }
    func testOnePercentDriftBound() {
        var p = preferences; p.driftRangePercent = 1
        let result = plan([window("a", 200, 200)], p: p)
        XCTAssertEqual(result.windowCount, 1)
        XCTAssertLessThanOrEqual(abs(result.moves[0].to.minX - 200), 12)
        XCTAssertLessThanOrEqual(abs(result.moves[0].to.minY - 200), 7.4)
    }
    func testMaximisedWindowDoesNotMove() {
        let w = window("a", 0, 24, 1200, 740)
        XCTAssertTrue(plan([w]).moves.isEmpty)
    }
    func testFullscreenGeometryDoesNotMove() {
        XCTAssertTrue(plan([window("a", 0, 0, 1200, 800)]).moves.isEmpty)
    }
    func testExcludedFocusedAndUnsupportedWindowsDoNotMove() {
        var p = preferences; p.excludedApps = ["app.a"]
        let windows = [window("a", 100, 100), window("b", 400, 100, focused: true),
                       window("c", 700, 100, movable: false), window("d", 100, 400, reason: "Full screen")]
        XCTAssertTrue(plan(windows, p: p).moves.isEmpty)
    }
    func testExistingOverlapsAreNotMoved() {
        XCTAssertTrue(plan([window("a", 100, 100), window("b", 150, 150)]).moves.isEmpty)
    }
    func testOffscreenWindowDoesNotMove() {
        XCTAssertTrue(plan([window("a", -1, 100)]).moves.isEmpty)
    }
    func testImmovableObstaclesRemainCollisionBarriers() {
        let windows = [window("a", 0, 24, 250, 740), window("b", 250, 24, 950, 740, movable: false)]
        XCTAssertTrue(plan(windows).moves.isEmpty)
    }
    func testTouchingEdgesAreNotOverlap() {
        XCTAssertFalse(Geometry.overlaps(CGRect(x: 0, y: 0, width: 10, height: 10), CGRect(x: 10, y: 0, width: 10, height: 10)))
    }
    func testNoCumulativeDriftBeyondAnchor() {
        var w = window("a", 200, 200)
        let anchor = w.frame
        for seed in 1...500 {
            let p = plan([w], anchors: [w.id: WindowAnchor(originFrame: anchor, lastFrame: w.frame)], seed: UInt64(seed))
            if let move = p.moves.first {
                XCTAssertLessThanOrEqual(abs(move.to.minX - anchor.minX), 120)
                XCTAssertLessThanOrEqual(abs(move.to.minY - anchor.minY), 74)
                w = MovementPlanner.applying([move], to: [w])[0]
            }
        }
    }
    func testStrictSwapUsesEmptyStagingSpace() {
        var p = preferences; p.mode = .swap
        let windows = [window("a", 0, 24), window("b", 300, 24)]
        let result = plan(windows, p: p)
        XCTAssertEqual(result.moves.count, 2)
        XCTAssertEqual(result.steps.count, 3)
        assertSafeSteps(result.steps, world: windows)
    }
    func testStrictSwapSkippedWhenDisplayHasNoStagingSpace() {
        var p = preferences; p.mode = .swap
        let windows = [window("a", 0, 24, 600, 740), window("b", 600, 24, 600, 740)]
        XCTAssertTrue(plan(windows, p: p).moves.isEmpty)
    }
    func testOptInAllowsTransientOverlapButSafeFinal() {
        var p = preferences; p.mode = .swap; p.allowTransientOverlap = true
        let windows = [window("a", 0, 24, 600, 740), window("b", 600, 24, 600, 740)]
        let result = plan(windows, p: p)
        XCTAssertEqual(result.moves.count, 2)
        XCTAssertEqual(result.steps.count, 2)
        XCTAssertTrue(MovementPlanner.safeFinal(moves: result.moves, world: windows, area: display.usableFrame))
    }
    func testSimilarSizesPreservedDuringSwap() {
        var p = preferences; p.mode = .swap
        let result = plan([window("a", 0, 24), window("b", 400, 24, 260, 210)], p: p)
        XCTAssertEqual(result.moves.count, 2)
        XCTAssertTrue(result.moves.allSatisfy { $0.from.size == $0.to.size })
    }
    func testDifferentSizedWindowsSwapSidesWithoutResizing() {
        var p = preferences; p.mode = .swap; p.allowTransientOverlap = true
        let windows = [window("wide", 0, 24, 800, 740), window("small", 800, 24, 400, 490)]
        var heights = Set<CGFloat>()
        for seed in 1...50 {
            let result = plan(windows, p: p, seed: UInt64(seed))
            XCTAssertEqual(result.windowCount, 2)
            XCTAssertEqual(result.moves.first { $0.windowID == "wide" }?.to.minX, 400)
            let small = result.moves.first { $0.windowID == "small" }
            XCTAssertEqual(small?.to.minX, 0)
            if let small { heights.insert(small.to.minY) }
            XCTAssertTrue(MovementPlanner.safeFinal(moves: result.moves, world: windows, area: display.usableFrame))
        }
        XCTAssertGreaterThan(heights.count, 1)
        p.allowTransientOverlap = false
        XCTAssertTrue(plan(windows, p: p).moves.isEmpty)
        p.allowTransientOverlap = true; p.maximumWindows = 1
        XCTAssertTrue(plan(windows, p: p).moves.isEmpty)
        p.maximumWindows = 4; p.excludedApps = ["app.small"]
        XCTAssertTrue(plan(windows, p: p).moves.isEmpty)
    }
    func testHundredPercentShiftCanCrossTheDisplay() {
        var p = preferences; p.driftRangePercent = 100
        let w = window("a", 0, 24, 100, 100)
        let results = (1...30).compactMap { plan([w], p: p, seed: UInt64($0)).moves.first }
        XCTAssertTrue(results.contains { $0.to.minX > display.usableFrame.width * 0.5 })
        XCTAssertTrue(results.allSatisfy { Geometry.contains(display.usableFrame, $0.to) && $0.from.size == $0.to.size })
        XCTAssertEqual(p.validated().driftRangePercent, 100)
        p.driftRangePercent = 150
        XCTAssertEqual(p.validated().driftRangePercent, 100)
    }
    func testMixedArrangementMovesMoreThanSimilarPair() {
        var p = preferences; p.mode = .swap; p.allowTransientOverlap = true
        let windows = [window("wide", 0, 24, 800, 740), window("small1", 800, 24, 400, 370),
                       window("small2", 800, 394, 400, 370)]
        let result = plan(windows, p: p)
        XCTAssertEqual(result.windowCount, 3)
        XCTAssertTrue(MovementPlanner.safeFinal(moves: result.moves, world: windows, area: display.usableFrame))
    }
    func testThreeWindowRotation() {
        var p = preferences; p.mode = .swap; p.maximumWindows = 3
        let windows = [window("a", 0, 24), window("b", 300, 24), window("c", 600, 24)]
        let result = plan(windows, p: p)
        XCTAssertEqual(result.moves.count, 3)
        XCTAssertEqual(Set(result.moves.map { $0.to.origin.x }), Set(windows.map { $0.frame.origin.x }))
        assertSafeSteps(result.steps, world: windows)
    }
    func testMaximumWindowCountIsRespected() {
        var p = preferences; p.maximumWindows = 1
        XCTAssertEqual(plan([window("a", 0, 100), window("b", 400, 100)], p: p).moves.count, 1)
        p.mode = .swap
        XCTAssertTrue(plan([window("a", 0, 100), window("b", 400, 100)], p: p).moves.isEmpty)
    }
    func testMixedDisplayCoordinatesAndScale() {
        let upper = DisplayInfo(id: "upper", name: "Upper", frame: CGRect(x: -1400, y: -900, width: 1400, height: 900),
                                usableFrame: CGRect(x: -1400, y: -875, width: 1400, height: 850), scale: 1)
        var p = preferences; p.selectedDisplays = ["main", "upper"]
        let windows = [window("a", 100, 100), window("b", -1300, -800, display: "upper")]
        var rng = RNG(state: 8)
        let result = MovementPlanner().plan(snapshot: DesktopSnapshot(displays: [display, upper], windows: windows), preferences: p, anchors: [:], group: nil, rng: &rng)
        XCTAssertEqual(result.moves.count, 2)
        for move in result.moves {
            let d = move.windowID == "a" ? display : upper
            XCTAssertTrue(Geometry.contains(d.usableFrame, move.to))
            XCTAssertLessThanOrEqual(abs(move.to.minX - move.from.minX), d.usableFrame.width * 0.1)
            XCTAssertLessThanOrEqual(abs(move.to.minY - move.from.minY), d.usableFrame.height * 0.1)
        }
    }
    func testAXCoordinateConversionAbovePrimaryScreen() {
        XCTAssertEqual(Geometry.axRect(CGRect(x: -100, y: 900, width: 1400, height: 800), primaryTop: 900),
                       CGRect(x: -100, y: -800, width: 1400, height: 800))
    }
    func testGroupDriftStaysInsideZone() {
        var p = preferences; p.mode = .group
        let zone = LayoutZone(id: UUID(), name: "Left", x: 0, y: 0, width: 0.5, height: 1, groupId: nil)
        let group = ImportedGroup(id: "group", name: "Group", zones: [zone], padding: 8)
        for seed in 1...100 {
            let result = plan([window("a", 100, 100), window("b", 800, 100)], p: p, group: group, seed: UInt64(seed))
            XCTAssertEqual(result.moves.count, 1)
            XCTAssertEqual(result.moves.first?.windowID, "a")
            XCTAssertTrue(result.moves.allSatisfy { Geometry.contains(group.frames(on: display)[0], $0.to) })
        }
    }
    func testWindowFillingGroupZoneCannotDrift() {
        var p = preferences; p.mode = .group
        let group = ImportedGroup(id: "g", name: "Group", zones: [LayoutZone(id: UUID(), name: "Left", x: 0, y: 0, width: 0.5, height: 1, groupId: nil)], padding: 0)
        XCTAssertTrue(plan([window("a", 0, 24, 600, 740)], p: p, group: group).moves.isEmpty)
    }
    func testAmbiguousGroupMembershipIsSkipped() {
        var p = preferences; p.mode = .group
        let zone = LayoutZone(id: UUID(), name: "All", x: 0, y: 0, width: 1, height: 1, groupId: nil)
        let group = ImportedGroup(id: "g", name: "Group", zones: [zone, zone], padding: 0)
        XCTAssertTrue(plan([window("a", 100, 100)], p: p, group: group).moves.isEmpty)
    }
    func testGroupRotationStaysWithinGroupZones() {
        var p = preferences; p.mode = .group; p.rotateGroup = true
        let zones = [LayoutZone(id: UUID(), name: "Left", x: 0, y: 0, width: 0.5, height: 0.8, groupId: nil),
                     LayoutZone(id: UUID(), name: "Right", x: 0.5, y: 0, width: 0.5, height: 0.8, groupId: nil)]
        let group = ImportedGroup(id: "g", name: "Group", zones: zones, padding: 0)
        let windows = [window("a", 20, 50), window("b", 650, 50)]
        let result = plan(windows, p: p, group: group)
        XCTAssertEqual(result.moves.count, 2)
        for step in result.steps { XCTAssertTrue(group.frames(on: display).contains { Geometry.contains($0, step.to) }) }
        XCTAssertTrue(MovementPlanner.safeFinal(moves: result.moves, world: windows, area: display.usableFrame))
    }
    func testMixedSnappedGroupingRearrangesEveryWindow() {
        let screen = DisplayInfo(id: "main", name: "Grouping screenshot", frame: CGRect(x: -1200, y: -900, width: 1200, height: 900),
                                 usableFrame: CGRect(x: -1200, y: -900, width: 1200, height: 900), scale: 1)
        var zones: [LayoutZone] = []
        for y in [0.0, 1.0 / 3] { for x in [0.0, 1.0 / 3, 2.0 / 3] {
            zones.append(LayoutZone(id: UUID(), name: "Tall", x: x, y: y, width: 1.0 / 3, height: 2.0 / 3, groupId: nil))
        } }
        for y in [0.0, 2.0 / 3] { for x in [0.0, 1.0 / 3] {
            zones.append(LayoutZone(id: UUID(), name: "Wide", x: x, y: y, width: 2.0 / 3, height: 1.0 / 3, groupId: nil))
        } }
        let group = ImportedGroup(id: "g", name: "Grouping 1", zones: zones, padding: 0)
        let windows = [window("wide", -1200, -900, 800, 300), window("left", -1200, -600, 400, 600),
                       window("middle", -800, -600, 400, 600), window("right", -400, -600, 400, 600)]
        var p = preferences; p.mode = .group; p.rotateGroup = true
        for seed in 1...100 {
            var rng = RNG(state: UInt64(seed))
            let result = MovementPlanner().plan(snapshot: DesktopSnapshot(displays: [screen], windows: windows),
                                                preferences: p, anchors: [:], group: group, rng: &rng)
            XCTAssertEqual(result.windowCount, 4)
            XCTAssertTrue(result.moves.allSatisfy { !Geometry.close($0.from, $0.to) && $0.from.size == $0.to.size })
            XCTAssertTrue(result.moves.allSatisfy { move in group.frames(on: screen).contains { Geometry.contains($0, move.to) } })
            XCTAssertTrue(MovementPlanner.safeFinal(moves: result.moves, world: windows, area: screen.usableFrame))
        }
        // A focused window stays a collision obstacle, and the configured cap remains binding.
        p.maximumWindows = 2
        var rng = RNG(state: 10)
        let capped = MovementPlanner().plan(snapshot: DesktopSnapshot(displays: [screen], windows: windows),
                                           preferences: p, anchors: [:], group: group, rng: &rng)
        XCTAssertLessThanOrEqual(capped.windowCount, 2)
        XCTAssertTrue(capped.moves.isEmpty || MovementPlanner.safeFinal(moves: capped.moves, world: windows, area: screen.usableFrame))
    }

    func testGroupCanUseEmptyZoneAndRespectsExcludedObstacle() {
        let zones = (0..<3).map { index in
            LayoutZone(id: UUID(), name: "Zone", x: Double(index) / 3, y: 0, width: 1.0 / 3, height: 1, groupId: nil)
        }
        let group = ImportedGroup(id: "g", name: "Group", zones: zones, padding: 0)
        var p = preferences; p.mode = .group; p.rotateGroup = true
        let windows = [window("a", 0, 24, 400, 740), window("obstacle", 400, 24, 400, 740)]
        p.excludedApps = ["app.obstacle"]
        let result = plan(windows, p: p, group: group)
        XCTAssertEqual(result.windowCount, 1)
        XCTAssertEqual(result.moves.first?.windowID, "a")
        XCTAssertEqual(result.moves.first?.to, CGRect(x: 800, y: 24, width: 400, height: 740))
        XCTAssertTrue(MovementPlanner.safeFinal(moves: result.moves, world: windows, area: display.usableFrame))
        let blocked = windows + [window("barrier", 800, 24, 400, 740, movable: false)]
        XCTAssertTrue(plan(blocked, p: p, group: group).moves.isEmpty)
    }

    func testGroupRotationHandlesRoundedThirdsWithoutResizing() {
        let screen = DisplayInfo(id: "main", name: "5120 display", frame: CGRect(x: -1239, y: -2160, width: 5120, height: 2160),
                                 usableFrame: CGRect(x: -1239, y: -2160, width: 5120, height: 2160), scale: 1)
        let zones = [0.0, 1.0 / 3, 2.0 / 3].map { x in
            LayoutZone(id: UUID(), name: "Third", x: x, y: 0, width: 1.0 / 3, height: 1, groupId: nil)
        }
        let group = ImportedGroup(id: "g", name: "Group", zones: zones, padding: 0)
        let windows = group.frames(on: screen).enumerated().map { index, frame in
            window(String(index), frame.minX, frame.minY, frame.width, frame.height)
        }
        var p = preferences; p.mode = .group; p.rotateGroup = true
        var rng = RNG(state: 1)
        let result = MovementPlanner().plan(snapshot: DesktopSnapshot(displays: [screen], windows: windows),
                                           preferences: p, anchors: [:], group: group, rng: &rng)
        // Two wider thirds can exchange; the narrower middle third must remain still.
        XCTAssertEqual(result.windowCount, 2)
        XCTAssertTrue(MovementPlanner.safeFinal(moves: result.moves, world: windows, area: screen.usableFrame))
    }

    func testStagingCannotLeaveRestrictedRegions() {
        let windows = [window("a", 0, 24), window("b", 300, 24)]
        let moves = [Move(windowID: "a", from: windows[0].frame, to: windows[1].frame),
                     Move(windowID: "b", from: windows[1].frame, to: windows[0].frame)]
        XCTAssertNil(MovementPlanner.safeSteps(moves: moves, world: windows, area: display.usableFrame,
                                              allowTransientOverlap: false, stagingAreas: windows.map(\.frame)))
    }
    func testRandomDesktopPlansNeverIntroduceOverlapOrOffscreenSteps() {
        for seed in 1...300 {
            var rng = RNG(state: UInt64(seed))
            let windows = (0..<8).map { i in window("\(i)", CGFloat(Int.random(in: 0...1000, using: &rng)), CGFloat(Int.random(in: 24...610, using: &rng)), 180, 150) }
            var p = preferences; p.mode = seed.isMultiple(of: 2) ? .drift : .swap
            let result = plan(windows, p: p, seed: UInt64(seed))
            assertSafeSteps(result.steps, world: windows)
            if !result.moves.isEmpty { XCTAssertTrue(MovementPlanner.safeFinal(moves: result.moves, world: windows, area: display.usableFrame)) }
        }
    }
    private func assertSafeSteps(_ steps: [Move], world: [WindowInfo], file: StaticString = #filePath, line: UInt = #line) {
        var world = world
        for step in steps {
            XCTAssertTrue(Geometry.contains(display.usableFrame, step.to), file: file, line: line)
            XCTAssertTrue(world.contains { $0.id == step.windowID && Geometry.close($0.frame, step.from) }, file: file, line: line)
            XCTAssertFalse(world.contains { $0.id != step.windowID && Geometry.overlaps($0.frame, step.to) }, file: file, line: line)
            world = MovementPlanner.applying([step], to: world)
        }
    }
}
