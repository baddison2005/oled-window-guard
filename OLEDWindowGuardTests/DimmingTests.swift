import XCTest
@testable import OLEDWindowGuard

final class DimmingTests: XCTestCase {
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 600)
    func area(_ regions: [DimmingRegion]) -> CGFloat { regions.reduce(0) { $0 + $1.frame.width * $1.frame.height } }
    func testFocusedWindowAndOcclusionRemainClear() {
        let front = CGRect(x: 200, y: 100, width: 300, height: 300)
        let regions = DimmingPlan.regions(display: screen, windows: [.init(frame: front, dimmable: true), .init(frame: screen, dimmable: true)], focused: front, windowAmount: 0.3, displayAmount: 0)
        XCTAssertEqual(area(regions), 510000)
        XCTAssertTrue(regions.allSatisfy { !Geometry.overlaps($0.frame, front) })
    }
    func testBackgroundWindowsDoNotStack() {
        let regions = DimmingPlan.regions(display: screen, windows: [.init(frame: CGRect(x: 100,y: 100,width: 300,height: 200), dimmable: true), .init(frame: screen, dimmable: true)], focused: nil, windowAmount: 0.3, displayAmount: 0)
        XCTAssertEqual(area(regions), 600000)
        for i in regions.indices { for j in regions.indices where i != j { XCTAssertFalse(Geometry.overlaps(regions[i].frame, regions[j].frame)) } }
    }
    func testWholeDisplayTakesPrecedenceAndProtectsControls() {
        let controls = CGRect(x: 0,y: 0,width: 100,height: 100)
        let regions = DimmingPlan.regions(display: screen, windows: [.init(frame: controls,dimmable: false), .init(frame: screen,dimmable: true)], focused: CGRect(x: -500,y: 0,width: 400,height: 600), windowAmount: 0.3, displayAmount: 0.4)
        XCTAssertEqual(area(regions), 590000)
        XCTAssertTrue(regions.allSatisfy { $0.amount == 0.4 && !Geometry.overlaps($0.frame,controls) })
    }
    func testSpanningFocusPreventsDisplayDimming() {
        XCTAssertTrue(DimmingPlan.regions(display: screen, windows: [], focused: CGRect(x: -200,y: 50,width: 400,height: 200), windowAmount: 0, displayAmount: 0.4).isEmpty)
    }
    func testNoFocusedWindowDimsEmptyDisplay() {
        XCTAssertEqual(DimmingPlan.regions(display: screen, windows: [], focused: nil, windowAmount: 0, displayAmount: 0.4), [.init(frame: screen, amount: 0.4)])
    }
    func testNegativeDisplayCoordinatesAndBounds() {
        let display = CGRect(x: -1000,y: -600,width: 1000,height: 600)
        let regions = DimmingPlan.regions(display: display, windows: [.init(frame: CGRect(x: -1100,y: -700,width: 500,height: 400),dimmable: true)], focused: nil, windowAmount: 0.3, displayAmount: 0)
        XCTAssertEqual(area(regions),120000)
        XCTAssertTrue(regions.allSatisfy { Geometry.contains(display,$0.frame) })
    }
    func testMigrationClampingAndRoundTrip() throws {
        var p = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(Preferences()))
        XCTAssertFalse(p.dimUnfocusedWindows); XCTAssertFalse(p.dimInactiveDisplays)
        XCTAssertEqual(p.windowDimmingPercent,30); XCTAssertEqual(p.displayDimmingPercent,40)
        p.dimUnfocusedWindows = true; p.dimInactiveDisplays = true
        p.windowDimmingPercent = 1000; p.displayDimmingPercent = -10
        p = p.validated()
        XCTAssertEqual(p.windowDimmingPercent,90); XCTAssertEqual(p.displayDimmingPercent,0)
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(p)),p)
    }
}
