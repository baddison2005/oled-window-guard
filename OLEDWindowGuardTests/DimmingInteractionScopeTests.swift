import XCTest
@testable import OLEDWindowGuard

final class DimmingInteractionScopeTests: XCTestCase {
    let laptop = CGRect(x: 0, y: 0, width: 2624, height: 1696)
    let lg = CGRect(x: -1239, y: -2160, width: 5120, height: 2160)
    let finder = CGRect(x: 2174, y: -1440, width: 854, height: 720)

    func testDesktopClickOverridesStaleFinderFocusAcrossRepeatedPolls() {
        var tracker = DimmingInteractionScope()
        tracker.desktopClicked(on: laptop)
        for _ in 0..<10 {
            let result = tracker.resolve(reported: finder, fallback: finder)
            XCTAssertNil(result.focused)
            XCTAssertEqual(result.scope, laptop)
            XCTAssertTrue(DimmingFocusScope.dimsWindows(on: lg, focused: result.focused, desktopScope: result.scope))
        }
    }
    func testOtherSpaceRetainsLGDelayAndFadeDespiteStaleFocus() {
        var tracker = DimmingInteractionScope(), delay = DimmingDelay(), fade = DimmingFade()
        _ = delay.ready(["lg"], delay: 30, now: 0)
        _ = fade.progress(ready: delay.ready(["lg"], delay: 30, now: 30), duration: 3, now: 30)
        tracker.spaceChanged(on: laptop)
        let scope = tracker.resolve(reported: finder, fallback: finder).scope!
        let eligible: Set<String> = scope.intersection(lg).height > 0 ? [] : ["lg"]
        XCTAssertEqual(delay.ready(eligible, delay: 30, now: 34), ["lg"])
        XCTAssertEqual(fade.progress(ready: eligible, duration: 3, now: 34)["lg"], 1)
    }
    func testFinderVirtualDesktopDoesNotResetOtherDisplayDelay() {
        var tracker = DimmingInteractionScope(), delay = DimmingDelay()
        _ = delay.ready(["lg"], delay: 30, now: 0)
        tracker.spaceChanged(on: laptop)
        let desktop = CGRect(x: -1239, y: -2160, width: 5120, height: 3856)
        let focus = DimmingInteractionScope.applicationFocus(reported: desktop, isFinder: true, visibleFinderWindows: [finder])
        XCTAssertNil(focus)
        let resolved = tracker.resolve(reported: focus, fallback: finder)
        XCTAssertNil(resolved.focused)
        XCTAssertEqual(resolved.scope, laptop)
        let eligible: Set<String> = resolved.scope!.intersects(lg) ? [] : ["lg"]
        XCTAssertEqual(delay.ready(eligible, delay: 30, now: 40), ["lg"])
    }
    func testRealFinderAndSpanningWindowsRemainFocused() {
        XCTAssertEqual(DimmingInteractionScope.applicationFocus(reported: finder, isFinder: true, visibleFinderWindows: [finder]), finder)
        let spanning = CGRect(x: 0, y: -200, width: 1000, height: 1000)
        XCTAssertEqual(DimmingInteractionScope.applicationFocus(reported: spanning, isFinder: true, visibleFinderWindows: [spanning]), spanning)
        XCTAssertEqual(DimmingInteractionScope.applicationFocus(reported: spanning, isFinder: false, visibleFinderWindows: []), spanning)
    }
    func testRealWindowInteractionReleasesDesktopOverride() {
        var tracker = DimmingInteractionScope()
        tracker.desktopClicked(on: laptop)
        tracker.windowInteraction()
        XCTAssertEqual(tracker.resolve(reported: finder, fallback: nil).focused, finder)
    }
    func testSpaceAcceptsFocusOnAffectedScreen() {
        var tracker = DimmingInteractionScope()
        tracker.spaceChanged(on: lg)
        XCTAssertEqual(tracker.resolve(reported: finder, fallback: nil).focused, finder)
    }
    func testSlidingSpaceSurfacesAreIgnoredEvenWithOnlyPartialDisplayOverlap() {
        // Geometry captured during a MacBook Space swipe; these surfaces cover the LG.
        for x: CGFloat in [-4193, 1183, 3871] {
            XCTAssertTrue(DimmingInteractionScope.isDesktopSurface(owner: "Dock", layer: 4,
                frame: CGRect(x: x, y: -2160, width: 5120, height: 2160), displays: [laptop, lg]))
        }
    }
    func testDesktopSurfaceDoesNotMaskScreenButDockAndMenusRemainProtected() {
        XCTAssertTrue(DimmingInteractionScope.isDesktopSurface(owner: "Dock", layer: 20, frame: laptop, displays: [laptop,lg]))
        XCTAssertFalse(DimmingInteractionScope.isDesktopSurface(owner: "Dock", layer: 20, frame: CGRect(x: 0,y: 1500,width: 500,height: 196), displays: [laptop,lg]))
        XCTAssertFalse(DimmingInteractionScope.isDesktopSurface(owner: "Finder", layer: 0, frame: lg, displays: [laptop,lg]))
        XCTAssertFalse(DimmingInteractionScope.isDesktopSurface(owner: "SystemUIServer", layer: 20, frame: laptop, displays: [laptop,lg]))
    }
}
