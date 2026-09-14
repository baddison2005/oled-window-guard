import XCTest
@testable import OLEDWindowGuard

final class StateAndIntegrationTests: XCTestCase {
    func testActivityOnOtherDisplayDoesNotCancel() {
        let now = Date()
        var activity = DisplayActivityHistory(started: now.addingTimeInterval(-100))
        activity.record(on: ["macbook"], at: now)
        XCTAssertTrue(activity.isQuiet(on: ["LG"], at: now, seconds: 5))
        XCTAssertFalse(activity.isQuiet(on: ["macbook"], at: now, seconds: 5))
        activity.record(on: ["LG"], at: now)
        XCTAssertFalse(activity.isQuiet(on: ["LG"], at: now, seconds: 5))
        XCTAssertTrue(activity.isQuiet(on: ["LG"], at: now.addingTimeInterval(5), seconds: 5))
    }

    func testBuiltInGroupsMatchWindowLayoutsGeometry() {
        let groups = LayoutGroupReader.builtInGroups(padding: 8)
        XCTAssertEqual(groups.map(\.zones.count), [4, 2, 2, 4, 3, 3])
        XCTAssertEqual(Set(groups.map(\.id)).count, 6)
        XCTAssertEqual(groups, LayoutGroupReader.builtInGroups(padding: 8))
        let thirds = groups.first { $0.id == "builtin.two-thirds" }!
        XCTAssertEqual(thirds.zones[1].x, 1.0 / 6)
        XCTAssertEqual(thirds.zones[1].width, 2.0 / 3)
        XCTAssertTrue(groups.allSatisfy { $0.padding == 8 })
    }

    func testLegacyPreferencesRetainSettingsAndDefaultToTenPercent() throws {
        var old = Preferences(); old.groupID = "retained"; old.maximumExcursionPixels = 512
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
        json.removeValue(forKey: "driftPercent")
        let migrated = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(migrated.groupID, "retained")
        XCTAssertEqual(migrated.driftRangePercent, 10)
        var p = migrated; p.driftRangePercent = 100
        XCTAssertEqual(p.validated().driftRangePercent, 100)
    }

    func testActivityAtCountdownEndCancelsUntilQuietPeriodHasElapsed() {
        XCTAssertFalse(ActivityPolicy.permitsMove(idleSeconds: 4.9, quietSeconds: 5, mouseButtonDown: false))
        XCTAssertTrue(ActivityPolicy.permitsMove(idleSeconds: 5, quietSeconds: 5, mouseButtonDown: false))
        XCTAssertFalse(ActivityPolicy.permitsMove(idleSeconds: 100, quietSeconds: 5, mouseButtonDown: true))
        // A 10-second warning cannot supply 15 seconds of quiet after activity at its start.
        XCTAssertFalse(ActivityPolicy.permitsMove(idleSeconds: 10, quietSeconds: 15, mouseButtonDown: false))
        // The longer setting does not unconditionally cancel an already-idle desktop.
        XCTAssertTrue(ActivityPolicy.permitsMove(idleSeconds: 20, quietSeconds: 15, mouseButtonDown: false))
        XCTAssertTrue(ActivityPolicy.permitsMove(idleSeconds: 0, quietSeconds: 0, mouseButtonDown: false))
    }

    func testSnapshotRestrictionIgnoresOtherDisplaysAndKeepsSpanningObstacles() {
        let tests = MovementTests()
        let other = DisplayInfo(id: "other", name: "Other", frame: CGRect(x: 1200, y: 0, width: 1000, height: 800),
                                usableFrame: CGRect(x: 1200, y: 24, width: 1000, height: 740), scale: 1)
        let snapshot = DesktopSnapshot(displays: [tests.display, other], windows: [
            tests.window("selected", 100, 100),
            tests.window("other", 1400, 100, display: "other"),
            tests.window("spanning", 1100, 100, 250, 200, display: "missing")
        ])
        let restricted = snapshot.restricted(to: ["main"])
        XCTAssertEqual(restricted.displays.map(\.id), ["main"])
        XCTAssertEqual(Set(restricted.windows.map(\.id)), ["selected", "spanning"])
    }

    func testOwnTransientWindowsAreExcludedButDashboardRemainsAnObstacle() {
        XCTAssertTrue(DesktopWindowFilter.includes(ownerPID: 20, ownPID: 10, title: nil))
        XCTAssertTrue(DesktopWindowFilter.includes(ownerPID: 10, ownPID: 10, title: "OLED Window Guard"))
        XCTAssertFalse(DesktopWindowFilter.includes(ownerPID: 10, ownPID: 10, title: "Window"))
        XCTAssertFalse(DesktopWindowFilter.includes(ownerPID: 10, ownPID: 10, title: nil))
    }

    func testTemporaryMatchingAmbiguityCanIgnoreOnlyParticipatingEligibility() {
        let tests = MovementTests()
        let before = DesktopSnapshot(displays: [tests.display], windows: [
            tests.window("a", 100, 100), tests.window("obstacle", 700, 100, movable: false)
        ])
        var ambiguous = before
        ambiguous.windows[0] = tests.window("a", 100, 100, movable: false, reason: "Unsupported window")
        XCTAssertFalse(SnapshotValidation.unchanged(before, ambiguous, moving: ["a"], avoidFocused: false))
        XCTAssertTrue(SnapshotValidation.unchanged(before, ambiguous, moving: ["a"], avoidFocused: false,
                                                   ignoringEligibilityFor: ["a"]))
        ambiguous.windows[1] = tests.window("obstacle", 700, 100, reason: "Changed")
        XCTAssertFalse(SnapshotValidation.unchanged(before, ambiguous, moving: ["a"], avoidFocused: false,
                                                    ignoringEligibilityFor: ["a"]))
    }

    func testWakeAndSkipUseFreshIntervals() {
        let now = Date(timeIntervalSince1970: 1000)
        var clock = MovementClock()
        clock.start(now: now, interval: 600)
        XCTAssertFalse(clock.isDue(now: now.addingTimeInterval(599)))
        XCTAssertTrue(clock.isDue(now: now.addingTimeInterval(600)))
        clock.warn(now: now.addingTimeInterval(600), seconds: 10)
        XCTAssertFalse(clock.isDue(now: now.addingTimeInterval(609)))
        XCTAssertTrue(clock.isDue(now: now.addingTimeInterval(610)))
        clock.stop()
        XCTAssertFalse(clock.isDue(now: now.addingTimeInterval(50000)))
        clock.start(now: now.addingTimeInterval(50000), interval: 600)
        XCTAssertEqual(clock.deadline, now.addingTimeInterval(50600))
    }
    func testApplyingCannotBeDueAgain() {
        var clock = MovementClock(); clock.applying()
        XCTAssertFalse(clock.isDue(now: .distantFuture))
        XCTAssertNil(clock.deadline)
    }
    func testRevalidationRejectsNewMovedClosedFocusedAndResizedWindows() {
        let tests = MovementTests()
        let a = tests.window("a", 100, 100)
        let before = DesktopSnapshot(displays: [tests.display], windows: [a])
        XCTAssertTrue(SnapshotValidation.unchanged(before, before, moving: ["a"], avoidFocused: true))
        for windows in [[], [a, tests.window("b", 700, 100)], [tests.window("a", 101, 100)],
                        [tests.window("a", 100, 100, 260)], [tests.window("a", 100, 100, focused: true)],
                        [tests.window("a", 100, 100, reason: "Full screen")]] {
            XCTAssertFalse(SnapshotValidation.unchanged(before, DesktopSnapshot(displays: before.displays, windows: windows), moving: ["a"], avoidFocused: true))
        }
        XCTAssertFalse(SnapshotValidation.unchanged(before, DesktopSnapshot(displays: [], windows: [a]), moving: ["a"], avoidFocused: false))
    }
    func testNonmovingObstacleChangesInvalidatePlan() {
        let tests = MovementTests()
        let before = DesktopSnapshot(displays: [tests.display], windows: [tests.window("a", 100, 100), tests.window("b", 700, 100, movable: false)])
        var after = before; after.windows[1] = tests.window("b", 700, 110, movable: false)
        XCTAssertFalse(SnapshotValidation.unchanged(before, after, moving: ["a"], avoidFocused: false))
    }
    func testReadbackToleranceDoesNotAllowActualCollision() {
        let tests = MovementTests()
        let before = DesktopSnapshot(displays: [tests.display], windows: [tests.window("a", 0, 100), tests.window("b", 250, 100)])
        var after = before; after.windows[0] = tests.window("a", 0.4, 100)
        XCTAssertTrue(SnapshotValidation.unchanged(before, after, moving: ["a"], avoidFocused: false))
        XCTAssertFalse(SnapshotValidation.safePositions(after, moving: ["a"]))
        XCTAssertTrue(SnapshotValidation.safePositions(before, moving: ["a"]))
    }
    func testReadbackToleranceDoesNotAllowActualOffscreenPosition() {
        let tests = MovementTests()
        let snapshot = DesktopSnapshot(displays: [tests.display], windows: [tests.window("a", -0.4, 100)])
        XCTAssertFalse(SnapshotValidation.safePositions(snapshot, moving: ["a"]))
    }
    func testActualPositionMustRemainInsideGroupRegion() {
        let tests = MovementTests()
        let snapshot = DesktopSnapshot(displays: [tests.display], windows: [tests.window("a", 0.4, 100)])
        let region = CGRect(x: 0, y: 24, width: 250, height: 740)
        XCTAssertFalse(SnapshotValidation.safePositions(snapshot, moving: ["a"], regions: ["main": [region]]))
    }
    func testPreferencesRejectUnsafeValues() {
        var p = Preferences()
        p.warningSeconds = 0; p.intervalMinutes = .nan; p.maximumWindows = -5
        p.distancePixels = .infinity; p.sizeTolerance = 1
        p = p.validated()
        XCTAssertEqual(p.warningSeconds, 3)
        XCTAssertEqual(p.intervalMinutes, 10)
        XCTAssertEqual(p.maximumWindows, 1)
        XCTAssertEqual(p.distancePixels, 16)
        XCTAssertEqual(p.sizeTolerance, 0.25)
        XCTAssertTrue(p.selectedDisplays.isEmpty)
    }
    func testPreferencesRoundTrip() throws {
        var p = Preferences(); p.selectedDisplays = ["monitor-uuid"]; p.excludedApps = ["com.example.app"]
        p.mode = .group; p.groupID = "saved-group"
        XCTAssertEqual(p, try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(p)))
    }
    func fixture(version: Int = 5, width: Double = 0.5, groupID: String = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA") -> Data {
        Data("""
        {"schemaVersion":\(version),"layoutPadding":8,"customGroups":[{"id":"AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA","name":"Work"}],"customLayouts":[{"id":"BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB","name":"Left","x":0,"y":0,"width":\(width),"height":1,"groupId":"\(groupID)"}],"unrelatedFutureSetting":true}
        """.utf8)
    }
    func testReadsWindowLayoutsSchemaAndInternalPadding() throws {
        let groups = try LayoutGroupReader.decode(fixture())
        XCTAssertEqual(groups.count, 1); XCTAssertEqual(groups[0].name, "Work")
        let frame = groups[0].frames(on: MovementTests().display)[0]
        XCTAssertEqual(frame, CGRect(x: 0, y: 24, width: 592, height: 740))
    }
    func testUnsupportedLibraryVersionIsRejected() { XCTAssertThrowsError(try LayoutGroupReader.decode(fixture(version: 7))) }
    func testInvalidGroupGeometryIsRejected() { XCTAssertThrowsError(try LayoutGroupReader.decode(fixture(width: 1.5))) }
    func testDanglingGroupReferenceIsRejected() { XCTAssertThrowsError(try LayoutGroupReader.decode(fixture(groupID: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"))) }
    func testCorruptLibraryIsRejected() { XCTAssertThrowsError(try LayoutGroupReader.decode(Data("{bad json".utf8))) }
}
