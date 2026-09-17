import XCTest
@testable import OLEDWindowGuard

final class DimmingDelayTests: XCTestCase {
    func testIndependentWindowAndDisplayDelays() {
        var windows = DimmingDelay(), displays = DimmingDelay()
        XCTAssertTrue(windows.ready(["window"], delay: 5, now: 100).isEmpty)
        XCTAssertTrue(displays.ready(["display"], delay: 10, now: 100).isEmpty)
        XCTAssertEqual(windows.ready(["window"], delay: 5, now: 105), ["window"])
        XCTAssertTrue(displays.ready(["display"], delay: 10, now: 105).isEmpty)
        XCTAssertEqual(displays.ready(["display"], delay: 10, now: 110), ["display"])
    }
    func testFocusResetsOnlyItsOwnTimer() {
        var gate = DimmingDelay()
        _ = gate.ready(["a","b"], delay: 5, now: 0)
        _ = gate.ready(["b"], delay: 5, now: 4)
        XCTAssertEqual(gate.ready(["a","b"], delay: 5, now: 5), ["b"])
        XCTAssertEqual(gate.ready(["a","b"], delay: 5, now: 10), ["a","b"])
    }
    func testZeroDelayChangesAndSuspension() {
        var gate = DimmingDelay()
        XCTAssertEqual(gate.ready(["a"], delay: 0, now: 0), ["a"])
        XCTAssertTrue(gate.ready(["a"], delay: 5, now: 10).isEmpty)
        gate.reset()
        XCTAssertTrue(gate.ready(["a"], delay: 5, now: 20).isEmpty)
        XCTAssertEqual(gate.ready(["a"], delay: 5, now: 25), ["a"])
        XCTAssertTrue(gate.ready([], delay: 5, now: 30).isEmpty)
    }
    func testPendingWindowDoesNotExposeOccludedBackgroundOrBlockWholeDisplayDimming() {
        let screen = CGRect(x: 0,y: 0,width: 100,height: 100)
        let windows: [DimmingWindow] = [.init(frame: screen,dimmable: true,ready: false), .init(frame: screen,dimmable: true)]
        XCTAssertTrue(DimmingPlan.regions(display: screen, windows: windows, focused: nil, windowAmount: 0.3, displayAmount: 0).isEmpty)
        XCTAssertEqual(DimmingPlan.regions(display: screen, windows: windows, focused: nil, windowAmount: 0.3, displayAmount: 0.4), [.init(frame: screen,amount: 0.4)])
    }
    func testMovingWindowKeepsElapsedDelayAndMaskFollowsItsFrame() {
        var gate = DimmingDelay()
        _ = gate.ready(["window"], delay: 5, now: 0)
        XCTAssertEqual(gate.ready(["window"], delay: 5, now: 5), ["window"])
        let display = CGRect(x: 0,y: 0,width: 1000,height: 600)
        for x in [0, 200, 600] {
            let frame = CGRect(x: x,y: 0,width: 100,height: 100)
            let ready = gate.ready(["window"], delay: 5, now: 6).contains("window")
            let regions = DimmingPlan.regions(display: display, windows: [.init(frame: frame,dimmable: true,ready: ready)], focused: CGRect(x: 800,y: 0,width: 100,height: 100), windowAmount: 0.5, displayAmount: 0)
            XCTAssertEqual(regions, [.init(frame: frame,amount: 0.5)])
        }
    }

    func testDelaySettingsDefaultsAndPersistence() throws {
        var p = Preferences()
        XCTAssertEqual(p.windowDimmingDelay,0); XCTAssertEqual(p.displayDimmingDelay,0)
        p.windowDimmingDelay = 5; p.displayDimmingDelay = 20
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.windowDimmingDelay,5); XCTAssertEqual(decoded.displayDimmingDelay,20)
        p.windowDimmingDelay = -10; p.displayDimmingDelay = 1000
        XCTAssertEqual(p.validated().windowDimmingDelay,0); XCTAssertEqual(p.validated().displayDimmingDelay,600)
    }
}
