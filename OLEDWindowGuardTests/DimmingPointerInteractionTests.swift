import XCTest
@testable import OLEDWindowGuard

final class DimmingPointerInteractionTests: XCTestCase {
    let laptop = CGRect(x:0,y:0,width:2624,height:1696)
    let dock = CGRect(x:500,y:1600,width:1200,height:96)

    func testCapturedFullScreenDockUsesActualEventRecipient() {
        let surfaces = [DimmingPointerSurface(owner:"Dock",layer:20,frame:laptop,windowID:9),
                        DimmingPointerSurface(owner:"Google Chrome",layer:0,frame:CGRect(x:0,y:49,width:1750,height:1572),windowID:71)]
        XCTAssertEqual(DimmingPointerInteraction.resolve(at:CGPoint(x:478.61328125,y:1645.37109375),surfaces:surfaces,display:laptop,handlingWindowID:9),.dockControl)
        // The same full-screen Dock surface also covers Chrome and empty desktop
        // geometrically, but neither click was delivered to the Dock.
        XCTAssertEqual(DimmingPointerInteraction.resolve(at:CGPoint(x:1671.69140625,y:1003.60546875),surfaces:surfaces,display:laptop,handlingWindowID:71),.window)
        XCTAssertEqual(DimmingPointerInteraction.resolve(at:CGPoint(x:2400,y:900),surfaces:surfaces,display:laptop,handlingWindowID:999),.desktop)
        XCTAssertEqual(DimmingPointerInteraction.resolve(at:CGPoint(x:2400,y:900),surfaces:surfaces,display:laptop,handlingWindowID:0),.desktop)
    }

    func testCapturedDockHelperSubmenuPreservesManualDim() {
        let surfaces = [DimmingPointerSurface(owner:"DockHelper",layer:101,frame:CGRect(x:712,y:1357,width:186,height:117),windowID:3786),
                        DimmingPointerSurface(owner:"Dock",layer:20,frame:laptop,windowID:9)]
        let point = CGPoint(x:747.15625,y:1376.33203125)
        XCTAssertEqual(DimmingPointerInteraction.resolve(at:point,surfaces:surfaces,display:laptop,handlingWindowID:3786),.dockControl)
        XCTAssertEqual(DimmingPointerInteraction.resolve(at:point,surfaces:surfaces,display:laptop),.dockControl)
    }

    func testDockControlPreservesManualDimWhileApplicationWindowInteractionDoesNot() {
        let surfaces = [DimmingPointerSurface(owner:"Dock",layer:20,frame:dock),
                        DimmingPointerSurface(owner:"TextEdit",layer:0,frame:laptop)]
        // Every icon belongs to the Dock surface, regardless of the app it opens
        // or whether the user left-clicks, right-clicks or Control-clicks it.
        for x: CGFloat in [550,700,1600] {
            XCTAssertEqual(DimmingPointerInteraction.resolve(at:CGPoint(x:x,y:1650),surfaces:surfaces,display:laptop),.dockControl)
        }
        // Clicking an application window is still real application interaction.
        XCTAssertEqual(DimmingPointerInteraction.resolve(at:CGPoint(x:700,y:900),surfaces:surfaces,display:laptop),.window)
    }

    func testDockMenuAndSubmenuSelectionsDoNotClearManualDim() {
        let menu = CGRect(x:600,y:1100,width:300,height:500)
        let submenu = CGRect(x:900,y:1200,width:400,height:150)
        let surfaces = [DimmingPointerSurface(owner:"Dock",layer:101,frame:submenu),
                        DimmingPointerSurface(owner:"Dock",layer:101,frame:menu),
                        DimmingPointerSurface(owner:"Dock",layer:20,frame:dock),
                        DimmingPointerSurface(owner:"TextEdit",layer:0,frame:laptop)]
        for point in [CGPoint(x:700,y:1400),CGPoint(x:1000,y:1250)] {
            XCTAssertEqual(DimmingPointerInteraction.resolve(at:point,surfaces:surfaces,display:laptop),.dockControl)
        }
        // Another app's context menu remains normal interaction.
        let appMenu = [DimmingPointerSurface(owner:"TextEdit",layer:101,frame:menu)]
        XCTAssertEqual(DimmingPointerInteraction.resolve(at:CGPoint(x:700,y:1400),surfaces:appMenu,display:laptop),.window)
    }

    func testDesktopSurfaceCannotBeMistakenForDockContextMenu() {
        let surfaces = [DimmingPointerSurface(owner:"Dock",layer:20,frame:laptop)]
        XCTAssertEqual(DimmingPointerInteraction.resolve(at:CGPoint(x:500,y:500),surfaces:surfaces,display:laptop),.desktop)
        XCTAssertEqual(DimmingPointerInteraction.resolve(at:CGPoint(x:500,y:500),surfaces:[],display:laptop),.desktop)
    }

    func testTopmostWindowAndSideDocksUseGeometryRatherThanBottomScreenAssumption() {
        let lg = CGRect(x:-1239,y:-2160,width:5120,height:2160)
        let side = CGRect(x:lg.minX,y:-1800,width:90,height:1200)
        let point = CGPoint(x:lg.minX+40,y:-1200)
        let surfaces = [DimmingPointerSurface(owner:"Dock",layer:20,frame:side)]
        XCTAssertEqual(DimmingPointerInteraction.resolve(at:point,surfaces:surfaces,display:lg),.dockControl)
        let front = DimmingPointerSurface(owner:"Another app",layer:102,frame:side)
        XCTAssertEqual(DimmingPointerInteraction.resolve(at:point,surfaces:[front]+surfaces,display:lg),.window)
    }
}
