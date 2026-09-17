import XCTest
@testable import OLEDWindowGuard

final class DisplayMovementTests: XCTestCase {
    func testIndependentSettingsRetainSharedSafety() throws {
        var p = Preferences(); p.selectedDisplays = ["lg", "laptop"]; p.quietSeconds = 9; p.warningSeconds = 15
        var lg = DisplayMovementSettings(p); lg.mode = .swap; lg.interval = 2; lg.keepGroups = true
        var laptop = DisplayMovementSettings(p); laptop.mode = .group; laptop.groupID = "group-one"; laptop.interval = 12; laptop.rotateGroup = true
        p.movementOverrides = ["lg":lg,"laptop":laptop]
        let restored = try JSONDecoder().decode(Preferences.self, from:JSONEncoder().encode(p))
        let a = restored.movementSettings(for:"lg"), b = restored.movementSettings(for:"laptop")
        XCTAssertEqual(a.mode,.swap); XCTAssertEqual(b.mode,.group)
        XCTAssertEqual(a.selectedDisplays,["lg"]); XCTAssertEqual(b.selectedDisplays,["laptop"])
        XCTAssertTrue(a.keepSimilarWindowsTogether); XCTAssertEqual(b.groupID,"group-one")
        XCTAssertEqual(a.warningSeconds,15); XCTAssertEqual(b.quietSeconds,9)
        XCTAssertEqual(a.intervalMinutes,2); XCTAssertEqual(b.intervalMinutes,12)
    }
    func testLegacyDefaultsRemainAvailable() {
        var p = Preferences(); p.mode = .swap; p.intervalMinutes = 22
        XCTAssertEqual(p.movementSettings(for:"lg").mode,.swap)
        XCTAssertEqual(p.movementSettings(for:"lg").intervalMinutes,22)
        XCTAssertNil(p.movementOverrides)
    }
    func testRestartOnlyCompletesAffectedDisplay() {
        let start = Date(timeIntervalSince1970:0)
        var schedule = DisplayMovementSchedule()
        schedule.sync(["lg":60,"laptop":120],now:start)
        XCTAssertEqual(schedule.next?.id,"lg")
        schedule.restart("lg",now:start.addingTimeInterval(80))
        XCTAssertEqual(schedule.deadlines["laptop"],start.addingTimeInterval(120))
        XCTAssertEqual(schedule.deadlines["lg"],start.addingTimeInterval(140))
        XCTAssertEqual(schedule.next?.id,"laptop")
    }
    func testChangingIntervalAndReconnectOnlyRestartsChangedMonitor() {
        let start = Date(timeIntervalSince1970:0)
        var schedule = DisplayMovementSchedule()
        schedule.sync(["lg":60,"laptop":120],now:start)
        schedule.sync(["lg":180,"laptop":120],now:start.addingTimeInterval(20))
        XCTAssertEqual(schedule.deadlines["lg"],start.addingTimeInterval(200))
        XCTAssertEqual(schedule.deadlines["laptop"],start.addingTimeInterval(120))
        schedule.sync(["laptop":120],now:start.addingTimeInterval(30))
        XCTAssertNil(schedule.deadlines["lg"])
        schedule.sync(["lg":180,"laptop":120],now:start.addingTimeInterval(40))
        XCTAssertEqual(schedule.deadlines["lg"],start.addingTimeInterval(220))
        XCTAssertEqual(schedule.deadlines["laptop"],start.addingTimeInterval(120))
    }
    func testPauseStartsFreshIntervals() {
        var schedule = DisplayMovementSchedule()
        schedule.sync(["lg":60],now:Date(timeIntervalSince1970:0))
        schedule.stop()
        XCTAssertNil(schedule.next)
        schedule.sync(["lg":60],now:Date(timeIntervalSince1970:500))
        XCTAssertEqual(schedule.next?.date,Date(timeIntervalSince1970:560))
    }
    func testDockDesktopSurfaceIsNotAnObstacleButRealDockIs() {
        let screen = CGRect(x:0,y:0,width:2624,height:1696)
        XCTAssertTrue(DimmingInteractionScope.isDesktopSurface(owner:"Dock",layer:20,frame:screen,displays:[screen]))
        XCTAssertFalse(DimmingInteractionScope.isDesktopSurface(owner:"Dock",layer:20,frame:CGRect(x:400,y:1596,width:1800,height:100),displays:[screen]))
        XCTAssertFalse(DimmingInteractionScope.isDesktopSurface(owner:"Other App",layer:0,frame:screen,displays:[screen]))
        let usable = CGRect(x:0,y:28,width:2624,height:1568)
        XCTAssertFalse(Geometry.contains(usable,CGRect(x:0,y:1550,width:300,height:100)))
    }
}
