import XCTest
@testable import OLEDWindowGuard

final class PreviewAndDesktopClickTests: XCTestCase {
    private func proposal() -> PreparedMovement {
        let helper = MovementTests()
        var p = helper.preferences
        p.avoidFocusedWindow = false
        let display = DisplayInfo(id: "main", name: "LG", frame: CGRect(x: -2000,y: -1000,width: 2000,height: 1000), usableFrame: CGRect(x: -2000,y: -1000,width: 2000,height: 1000), scale: 1)
        let window = helper.window("one", -1800,-800,500,400)
        let move = Move(windowID: window.id, from: window.frame, to: window.frame.offsetBy(dx: 600,dy: 0))
        return PreparedMovement(plan: MovementPlan(moves: [move], steps: [move], reason: "test"),
            baseline: DesktopSnapshot(displays: [display], windows: [window]), preferences: p, group: nil, layoutSource: nil)
    }
    func testPreviewRetainsExactMovesAcrossPollingAndUnrelatedDisplayChanges() {
        let cached = proposal()
        var live = cached.baseline
        let other = DisplayInfo(id: "laptop", name: "Laptop", frame: CGRect(x:0,y:0,width:1200,height:800), usableFrame:CGRect(x:0,y:0,width:1200,height:800), scale:2)
        live.displays.append(other)
        live.windows.append(MovementTests().window("unrelated",100,100,200,200))
        for _ in 0..<20 {
            XCTAssertTrue(cached.matches(snapshot:live,preferences:cached.preferences,group:nil,source:nil))
            XCTAssertEqual(cached.plan.moves.first?.to, CGRect(x:-1200,y:-800,width:500,height:400))
        }
    }
    func testChangedWindowObstacleSettingsSourceOrGroupInvalidatesPreview() {
        let cached = proposal()
        var live = cached.baseline
        let w = live.windows[0]
        live.windows[0] = WindowInfo(id:w.id,appID:w.appID,appName:w.appName,frame:w.frame.offsetBy(dx:10,dy:0),displayID:w.displayID,movable:w.movable,focused:false,skipReason:nil)
        XCTAssertFalse(cached.matches(snapshot:live,preferences:cached.preferences,group:nil,source:nil))
        live = cached.baseline
        live.windows.append(MovementTests().window("obstacle",-1200,-800,500,400))
        XCTAssertFalse(cached.matches(snapshot:live,preferences:cached.preferences,group:nil,source:nil))
        var settings = cached.preferences; settings.maximumWindows += 1
        XCTAssertFalse(cached.matches(snapshot:cached.baseline,preferences:settings,group:nil,source:nil))
        XCTAssertFalse(cached.matches(snapshot:cached.baseline,preferences:cached.preferences,group:nil,source:.standard))
        let group = LayoutGroupReader.builtInGroups()[0]
        XCTAssertFalse(cached.matches(snapshot:cached.baseline,preferences:cached.preferences,group:group,source:nil))
        live = cached.baseline; live.windows.removeAll()
        XCTAssertFalse(cached.matches(snapshot:live,preferences:cached.preferences,group:nil,source:nil))
    }
    func testDesktopClickChoicesStayScopedUntilThatDisplaysWindowIsClicked() {
        var state = DesktopClickDimmingState()
        state.click(on:"lg",behavior:.keepBright)
        state.click(on:"laptop",behavior:.restartTimers)
        XCTAssertEqual(state.behavior(on:"lg"),.keepBright)
        XCTAssertEqual(state.behavior(on:"laptop"),.restartTimers)
        state.windowClicked(on:"laptop")
        XCTAssertEqual(state.behavior(on:"lg"),.keepBright)
        XCTAssertNil(state.behavior(on:"laptop"))
        state.windowClicked(on:"lg")
        XCTAssertNil(state.behavior(on:"lg"))
    }
    func testDesktopClickPreferenceMigratesAndPersistsBothChoices() throws {
        XCTAssertEqual(Preferences().desktopClickBehavior,.keepBright)
        for choice in DesktopClickBehavior.allCases {
            var p = Preferences(); p.desktopClickBehavior = choice
            XCTAssertEqual(try JSONDecoder().decode(Preferences.self,from:JSONEncoder().encode(p)).desktopClickBehavior,choice)
        }
    }
    func testRestartClickAllowsIndependentWindowAndDisplayDelaysOnActiveDesktop() {
        var state = DesktopClickDimmingState()
        state.click(on:"lg",behavior:.restartTimers)
        var windows = DimmingDelay(), display = DimmingDelay()
        for t: Double in [0,4,5,9,10,20] {
            let e = state.eligibility(on:"lg",windows:false,display:false)
            XCTAssertEqual(windows.ready(e.windows ? ["window"] : [],delay:5,now:t), t >= 5 ? ["window"] : [])
            XCTAssertEqual(display.ready(e.display ? ["lg"] : [],delay:10,now:t), t >= 10 ? ["lg"] : [])
        }
        // Keep-bright suppresses both even when ordinary inactive-display rules would dim.
        state.click(on:"lg",behavior:.keepBright)
        let held = state.eligibility(on:"lg",windows:true,display:true)
        XCTAssertFalse(held.windows); XCTAssertFalse(held.display)
        XCTAssertTrue(state.eligibility(on:"other",windows:true,display:true).display)
        state.windowClicked(on:"lg")
        XCTAssertFalse(state.eligibility(on:"lg",windows:false,display:false).display)
    }
}
