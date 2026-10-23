import XCTest
@testable import OLEDWindowGuard

final class DimmingSurfacePolicyTests: XCTestCase {
    let display = CGRect(x:0,y:0,width:1000,height:600)
    let dock = CGRect(x:200,y:550,width:600,height:50)

    func testWholeDisplayIncludesDockButLeavesContextMenuReadable() {
        let menu = CGRect(x:200,y:300,width:200,height:250)
        let windows = [DimmingWindow(frame:menu,dimmable:DimmingSurfacePolicy.includesInDimming(owner:"Dock",layer:101),ready:false),
                       DimmingWindow(frame:dock,dimmable:DimmingSurfacePolicy.includesInDimming(owner:"Dock",layer:20),ready:false)]
        let regions = DimmingPlan.regions(display:display,windows:windows,focused:nil,windowAmount:0.3,displayAmount:0.5)
        XCTAssertEqual(regions.reduce(0) { $0 + $1.frame.width * $1.frame.height },550_000)
        XCTAssertTrue(regions.contains { $0.frame.contains(CGPoint(x:500,y:575)) && $0.amount == 0.5 })
        XCTAssertTrue(regions.allSatisfy { !Geometry.overlaps($0.frame,menu) })
    }
    func testWindowOnlyDimmingDoesNotDimDock() {
        // The Dock is not an eligible application window and has no window timer.
        let window = DimmingWindow(frame:dock,dimmable:DimmingSurfacePolicy.includesInDimming(owner:"Dock",layer:20),ready:false)
        XCTAssertTrue(DimmingPlan.regions(display:display,windows:[window],focused:nil,windowAmount:0.3,displayAmount:0).isEmpty)
        XCTAssertFalse(DimmingSurfacePolicy.includesInDimming(owner:"SystemUIServer",layer:20))
        XCTAssertTrue(DimmingSurfacePolicy.includesInDimming(owner:"TextEdit",layer:0))
    }
    func testWholeDisplayOverlayCoversDockButRemainsBelowMenus() {
        XCTAssertGreaterThan(DimmingSurfacePolicy.displayOverlayLevel,Int(CGWindowLevelForKey(.dockWindow)))
        XCTAssertLessThan(DimmingSurfacePolicy.displayOverlayLevel,Int(CGWindowLevelForKey(.mainMenuWindow)))
        XCTAssertLessThan(DimmingSurfacePolicy.displayOverlayLevel,Int(CGWindowLevelForKey(.popUpMenuWindow)))
        XCTAssertLessThan(DimmingSurfacePolicy.windowOverlayLevel,Int(CGWindowLevelForKey(.dockWindow)))
    }
}
