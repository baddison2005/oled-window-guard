import XCTest
import AppKit
@testable import OLEDWindowGuard

final class InstantDimmingTests: XCTestCase {
    func testManualDimmingAndInteractionStayOnSelectedMonitor() {
        var state = InstantDimming()
        state.dim("lg")
        state.interact(on:["laptop"])
        XCTAssertTrue(state.contains("lg"))
        XCTAssertFalse(state.contains("laptop"))
        state.dim("second")
        state.interact(on:["lg"])
        XCTAssertFalse(state.contains("lg"))
        XCTAssertTrue(state.contains("second"))
        state.reset()
        XCTAssertTrue(state.displays.isEmpty)
    }
    func testDimmingTargetMustRemainSelectedAndConnected() {
        XCTAssertEqual(InstantDimming.target(requested:"lg",selected:["lg","laptop"],connected:["lg","laptop"]),"lg")
        XCTAssertEqual(InstantDimming.target(requested:"removed",selected:["lg"],connected:["lg","removed"]),"lg")
        XCTAssertNil(InstantDimming.target(requested:"lg",selected:["lg"],connected:["laptop"]))
        var state = InstantDimming(); state.dim("lg"); state.dim("removed")
        state.retain(["lg"])
        XCTAssertEqual(state.displays,["lg"])
    }
    @MainActor func testDockMenuIncludesManualActionsWithSafetyAvailability() {
        let delegate = AppDelegate()
        let menu = delegate.applicationDockMenu(NSApplication.shared)!
        XCTAssertNotNil(menu.items.first { $0.title == "Move now…" })
        XCTAssertEqual(menu.items.first { $0.title == "Restore last move…" }?.isEnabled,false)
        XCTAssertEqual(menu.items.first { $0.title.hasPrefix("Dim monitor now") }?.isEnabled,false)
        XCTAssertNotNil(menu.items.first { $0.title == "Start movement" })
        XCTAssertNotNil(menu.items.first { $0.title == "Start dimming" })
        XCTAssertFalse(menu.autoenablesItems)
    }
}
