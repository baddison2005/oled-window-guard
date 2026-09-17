import XCTest
@testable import OLEDWindowGuard

final class DimmingFadeTests: XCTestCase {
    let lg = CGRect(x: 0,y: 0,width: 5120,height: 2160)
    let laptop = CGRect(x: 5120,y: 0,width: 2624,height: 1696)
    func testOtherDesktopDoesNotClearLGWindowDimming() {
        XCTAssertTrue(DimmingFocusScope.dimsWindows(on: lg, focused: nil, desktopScope: laptop))
        XCTAssertFalse(DimmingFocusScope.dimsWindows(on: laptop, focused: nil, desktopScope: laptop))
        XCTAssertFalse(DimmingFocusScope.dimsWindows(on: lg, focused: nil, desktopScope: lg))
    }
    func testIndependentDurations() {
        var windows = DimmingFade(), displays = DimmingFade()
        XCTAssertEqual(windows.progress(ready: ["a"], duration: 1, now: 0)["a"],0)
        _ = displays.progress(ready: ["lg"], duration: 3, now: 0)
        XCTAssertEqual(windows.progress(ready: ["a"], duration: 1, now: 0.5)["a"],0.5)
        XCTAssertEqual(displays.progress(ready: ["lg"], duration: 3, now: 1.5)["lg"],0.5)
        XCTAssertEqual(windows.progress(ready: ["a"], duration: 1, now: 3)["a"],1)
    }
    func testOtherDisplayChangesDoNotRestartFade() {
        var fade = DimmingFade()
        _ = fade.progress(ready: ["lg","laptop"], duration: 3, now: 0)
        XCTAssertEqual(fade.progress(ready: ["lg"], duration: 3, now: 1.5)["lg"],0.5)
        XCTAssertEqual(fade.progress(ready: ["lg","laptop"], duration: 3, now: 3)["lg"],1)
    }
    func testZeroAndRegainingFocus() {
        var fade = DimmingFade()
        XCTAssertEqual(fade.progress(ready: ["a"], duration: 0, now: 0)["a"],1)
        XCTAssertTrue(fade.progress(ready: [], duration: 3, now: 10).isEmpty)
        XCTAssertEqual(fade.progress(ready: ["a"], duration: 3, now: 11)["a"],0)
    }
    func testDisplayFadeDoesNotFlashExistingDimWindow() {
        let screen = CGRect(x: 0,y: 0,width: 100,height: 100)
        let window = CGRect(x: 0,y: 0,width: 50,height: 100)
        let frames = [DimmingWindow(frame: window,dimmable: true)]
        let start = DimmingPlan.regions(display: screen, windows: frames, focused: nil, windowAmount: 0.5, displayAmount: 0.4, displayProgress: 0)
        XCTAssertEqual(start.first(where: { $0.frame == window })?.amount,0.5)
        let middle = DimmingPlan.regions(display: screen, windows: frames, focused: nil, windowAmount: 0.5, displayAmount: 0.4, displayProgress: 0.5)
        XCTAssertEqual(middle.first(where: { $0.frame == window })!.amount,0.45,accuracy: 0.00001)
        XCTAssertEqual(middle.first(where: { $0.frame.minX == 50 })?.amount,0.2)
    }
    func testWindowFadeAndFocusedWindowProtection() {
        let frame = CGRect(x: 0,y: 0,width: 100,height: 100)
        let windows = [DimmingWindow(frame: frame,dimmable: true,fadeProgress: 0.5)]
        XCTAssertEqual(DimmingPlan.regions(display: lg,windows: windows,focused: nil,windowAmount: 0.6,displayAmount: 0).first?.amount,0.3)
        XCTAssertTrue(DimmingPlan.regions(display: lg,windows: windows,focused: frame,windowAmount: 0.6,displayAmount: 0).isEmpty)
    }
    func testFadeDefaultsStepsAndPersistence() throws {
        var p = Preferences()
        XCTAssertEqual(p.windowDimmingFade,0); XCTAssertEqual(p.displayDimmingFade,0)
        p.windowDimmingFade = 1.3; p.displayDimmingFade = 99
        p = p.validated()
        XCTAssertEqual(p.windowDimmingFade,1.5); XCTAssertEqual(p.displayDimmingFade,3)
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self,from: JSONEncoder().encode(p)),p)
    }
}
