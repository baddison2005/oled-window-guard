import XCTest
@testable import OLEDWindowGuard

final class AutomaticMovementDeadlineTests: XCTestCase {
    func testRepeatedPollingKeepsExpiredDeadlineDue() {
        let start = Date(timeIntervalSince1970:0)
        var schedule = DisplayMovementSchedule(), clock = MovementClock()
        schedule.sync(["lg":60,"laptop":120],now:start)
        for seconds in [59.9,60.0,60.5,61.0] {
            let poll = start.addingTimeInterval(seconds)
            // Dimming work happens between sampling time and syncing the movement clock.
            schedule.sync(["lg":60,"laptop":120],now:poll.addingTimeInterval(0.02))
            clock.wait(until:schedule.next!.date)
            XCTAssertEqual(clock.isDue(now:poll),seconds >= 60)
        }
    }
    func testDueDisplayLeadsToWarningAndNextDisplayRetainsDeadline() {
        let start = Date(timeIntervalSince1970:0)
        var schedule = DisplayMovementSchedule(), clock = MovementClock()
        schedule.sync(["lg":60,"laptop":120],now:start)
        clock.wait(until:schedule.next!.date)
        XCTAssertTrue(clock.isDue(now:start.addingTimeInterval(61)))
        clock.warn(now:start.addingTimeInterval(61),seconds:10)
        XCTAssertFalse(clock.isDue(now:start.addingTimeInterval(70)))
        XCTAssertTrue(clock.isDue(now:start.addingTimeInterval(71)))
        schedule.restart("lg",now:start.addingTimeInterval(75))
        XCTAssertEqual(schedule.next?.id,"laptop")
        XCTAssertEqual(schedule.next?.date,start.addingTimeInterval(120))
    }
    func testDockPreferenceDefaultsAndPersists() throws {
        var p = Preferences(); XCTAssertFalse(p.showsDockIcon)
        p.showsDockIcon = true
        XCTAssertTrue(try JSONDecoder().decode(Preferences.self,from:JSONEncoder().encode(p)).showsDockIcon)
    }
    func testSingleTextEditExplainsSwapButCanShift() {
        let helper = MovementTests()
        let d = DisplayInfo(id: "main", name: "MacBook", frame: CGRect(x:0,y:0,width:2624,height:1696), usableFrame:CGRect(x:0,y:49,width:2624,height:1572), scale:1)
        let w = helper.window("TextEdit",1749,573,875,1048)
        var p = helper.preferences; p.mode = .swap; p.driftRangePercent = 100
        var rng = MovementTests.RNG(state:1)
        let snapshot = DesktopSnapshot(displays:[d],windows:[w])
        let swap = MovementPlanner().plan(snapshot:snapshot,preferences:p,anchors:[:],group:nil,rng:&rng)
        XCTAssertTrue(swap.moves.isEmpty); XCTAssertTrue(swap.reason.contains("single window"))
        p.mode = .drift
        XCTAssertEqual(MovementPlanner().plan(snapshot:snapshot,preferences:p,anchors:[:],group:nil,rng:&rng).windowCount,1)
    }
    func testCurrentCintiqColumnsCanRotateAllThreeWindows() {
        let helper = MovementTests()
        let area = CGRect(x:2624,y:616,width:1920,height:1080)
        let d = DisplayInfo(id:"main",name:"Cintiq",frame:area,usableFrame:area,scale:1)
        let windows = [helper.window("Terminal",2624,616,639,1069),helper.window("Excel",3264,616,640,1080),helper.window("Word",3904,616,640,1080)]
        let zones = (0..<3).map { CGRect(x:2624 + CGFloat($0)*640,y:616,width:640,height:1080) }
        var rng = MovementTests.RNG(state:1)
        let plan = MovementPlanner.groupAssignment(candidates:windows,zones:zones,world:windows,display:d,limit:8,tolerance:0.05,rng:&rng)
        XCTAssertEqual(plan?.windowCount,3)
        XCTAssertTrue(MovementPlanner.safeFinal(moves:plan!.moves,world:windows,area:area))
    }
}
