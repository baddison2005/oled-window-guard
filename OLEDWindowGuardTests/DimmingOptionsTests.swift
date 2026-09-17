import XCTest
@testable import OLEDWindowGuard

final class DimmingOptionsTests: XCTestCase {
    func testLegacySelectionAndIndependentSelectionPersistence() throws {
        var p = Preferences(); p.selectedDisplays = ["lg"]
        XCTAssertEqual(p.dimmingDisplays, ["lg"])
        p.dimmingDisplays = p.selectedDisplays
        p.selectedDisplays = ["laptop"]
        XCTAssertEqual(p.dimmingDisplays, ["lg"])
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.dimmingDisplays, ["lg"])
        XCTAssertTrue(decoded.brightnessShortcutEnabled)
    }
    func testCustomMonitorSettingsAndMasterSwitches() throws {
        var p = Preferences(); p.dimUnfocusedWindows = true; p.dimInactiveDisplays = true
        var custom = DisplayDimmingSettings(defaults: p)
        custom.windowPercent = 65; custom.displayDelay = 120; custom.windowFade = 2.5
        p.displayDimmingOverrides = ["lg": custom]
        XCTAssertEqual(p.dimmingSettings(for: "lg").windowPercent,65)
        XCTAssertEqual(p.dimmingSettings(for: "laptop").windowPercent,30)
        p.dimUnfocusedWindows = false
        XCTAssertFalse(p.dimmingSettings(for: "lg").windows)
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.dimmingSettings(for: "lg").displayDelay,120)
        XCTAssertEqual(decoded.dimmingSettings(for: "lg").windowFade,2.5)
    }
    func testCustomBoundsValidation() {
        var p = Preferences(); var custom = DisplayDimmingSettings(defaults: p)
        custom.windowPercent = 400; custom.displayDelay = -10; custom.windowFade = 1.3
        p.displayDimmingOverrides = ["lg": custom]
        let validated = p.validated().displayDimmingOverrides!["lg"]!
        XCTAssertEqual(validated.windowPercent,90); XCTAssertEqual(validated.displayDelay,0); XCTAssertEqual(validated.windowFade,1.5)
    }
    func testDifferentMonitorTimersDoNotResetEachOther() {
        var lg = DisplayDimmingRuntime(), laptop = DisplayDimmingRuntime()
        _ = lg.display.ready(["lg"], delay:30, now:0)
        _ = laptop.display.ready(["laptop"], delay:60, now:0)
        XCTAssertEqual(lg.display.ready(["lg"], delay:30, now:40),["lg"])
        XCTAssertTrue(laptop.display.ready(["laptop"], delay:60, now:40).isEmpty)
        _ = laptop.display.ready([], delay:60, now:45)
        XCTAssertEqual(lg.display.ready(["lg"], delay:30, now:46),["lg"])
    }
    func testRestoreMinimumAndRepeatedRestore() {
        var restore = BrightnessRestore()
        restore.restore(now:100)
        XCTAssertTrue(restore.isActive(now:104.9)); XCTAssertFalse(restore.isActive(now:105))
        restore.restore(now:104)
        XCTAssertTrue(restore.isActive(now:108)); XCTAssertFalse(restore.isActive(now:109))
    }
    func testRestoreResetsDelayAndPreservesLongerWait() {
        var runtime = DisplayDimmingRuntime()
        _ = runtime.display.ready(["lg"],delay:30,now:0)
        runtime = DisplayDimmingRuntime() // Same reset used by restoreBrightness.
        XCTAssertTrue(runtime.display.ready(["lg"],delay:30,now:100).isEmpty)
        XCTAssertTrue(runtime.display.ready(["lg"],delay:30,now:105).isEmpty)
        XCTAssertEqual(runtime.display.ready(["lg"],delay:30,now:130),["lg"])
    }
    func testExclusionsDoNotLeakThroughForegroundWindows() {
        let screen = CGRect(x:0,y:0,width:100,height:100)
        let front = CGRect(x:0,y:0,width:50,height:100)
        let windows = [DimmingWindow(frame:front,dimmable:true),DimmingWindow(frame:screen,dimmable:false)]
        for whole in [0.0,0.6] {
            let regions = DimmingPlan.regions(display:screen, windows:windows, focused:nil, windowAmount:0.4, displayAmount:whole)
            XCTAssertEqual(regions.reduce(0) { $0 + $1.frame.width * $1.frame.height },5000)
            XCTAssertTrue(regions.allSatisfy { front.contains($0.frame) })
        }
    }
    func testExclusionsAreSeparateFromMovement() throws {
        var p = Preferences(); p.excludedApps = ["movement.app"]; p.dimmingExclusions = ["bright.app"]
        let decoded = try JSONDecoder().decode(Preferences.self, from:JSONEncoder().encode(p))
        XCTAssertEqual(decoded.excludedApps,["movement.app"]); XCTAssertEqual(decoded.dimmingExclusions,["bright.app"])
    }
}
