import XCTest
@testable import OLEDWindowGuard

final class SpaceDimmingResetTests: XCTestCase {
    let lg = CGRect(x:-1200,y:-2160,width:5120,height:2160)
    let laptop = CGRect(x:0,y:0,width:2624,height:1696)

    func testNewSpaceClearsDesktopHoldAndRestartsBothTimers() {
        var clicks = DesktopClickDimmingState(), scope = DimmingInteractionScope()
        clicks.click(on:"lg",behavior:.keepBright)
        XCTAssertFalse(clicks.eligibility(on:"lg",windows:true,display:true).display)
        // The presenter's scoped Space reset clears the previous Desktop's hold.
        clicks.windowClicked(on:"lg")
        scope.spaceChanged(on:lg)
        let resolved = scope.resolve(reported:nil,fallback:laptop)
        XCTAssertTrue(resolved.restartTimers)
        let eligible = clicks.eligibility(on:"lg",windows:resolved.restartTimers,display:resolved.restartTimers)
        var windows = DimmingDelay(), display = DimmingDelay()
        for t: Double in [0,4,5,9,10,20] {
            XCTAssertEqual(windows.ready(eligible.windows ? ["window"] : [],delay:5,now:t), t >= 5 ? ["window"] : [])
            XCTAssertEqual(display.ready(eligible.display ? ["lg"] : [],delay:10,now:t), t >= 10 ? ["lg"] : [])
        }
    }
    func testSpaceRestoresOnlyChangedDisplayAndRetainsOtherFade() {
        var restore = SpaceDimmingRestore(), delay = DimmingDelay(), fade = DimmingFade()
        _ = delay.ready(["lg"],delay:30,now:0)
        _ = fade.progress(ready:delay.ready(["lg"],delay:30,now:30),duration:2,now:30)
        restore.restart("laptop",now:31)
        XCTAssertTrue(restore.isRestoring("laptop",now:31.5))
        XCTAssertFalse(restore.isRestoring("lg",now:31.5))
        XCTAssertEqual(delay.ready(["lg"],delay:30,now:32),["lg"])
        XCTAssertEqual(fade.progress(ready:["lg"],duration:2,now:32)["lg"],1)
        XCTAssertFalse(restore.isRestoring("laptop",now:32))
    }
    func testChangedLGSpaceWaitsForAnimationThenAllowsFreshDelays() {
        var restore = SpaceDimmingRestore()
        restore.restart("lg",now:100)
        XCTAssertTrue(restore.isRestoring("lg",now:100.5))
        // The completion notification extends only this display's settling hold.
        restore.restart("lg",now:100.4)
        XCTAssertTrue(restore.isRestoring("lg",now:101))
        XCTAssertFalse(restore.isRestoring("lg",now:101.2))
        XCTAssertFalse(restore.isRestoring("laptop",now:101))
    }
    func testOldSpaceFocusIsRejectedButRealNewSpaceWindowStaysFocused() {
        let old = CGRect(x:0,y:-1800,width:900,height:800)
        let new = CGRect(x:1000,y:-1800,width:900,height:800)
        var scope = DimmingInteractionScope()
        scope.spaceChanged(on:lg)
        XCTAssertTrue(scope.isSpaceScoped)
        let stale = DimmingInteractionScope.spaceFocus(reported:old,visibleWindows:[new])
        XCTAssertNil(stale)
        XCTAssertTrue(scope.resolve(reported:stale,fallback:old).restartTimers)
        let current = DimmingInteractionScope.spaceFocus(reported:new,visibleWindows:[new])
        XCTAssertEqual(current,new)
        XCTAssertFalse(scope.resolve(reported:current,fallback:old).restartTimers)
        // A subsequent explicit desktop click retains its chosen behavior.
        scope.desktopClicked(on:lg)
        XCTAssertFalse(scope.isSpaceScoped)
        XCTAssertFalse(scope.resolve(reported:nil,fallback:old).restartTimers)
    }
}
