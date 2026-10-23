import XCTest
import AppKit
@testable import OLEDWindowGuard

final class GuardMenuCommandsTests: XCTestCase {
    private func display(_ id: String, _ name: String) -> DisplayInfo {
        DisplayInfo(id: id, name: name, frame: CGRect(x:0,y:0,width:1920,height:1080),
                    usableFrame: CGRect(x:0,y:25,width:1920,height:1055), scale:1)
    }
    private var lg: DisplayInfo { display("uuid-lg", "LG UltraWide") }
    private var laptop: DisplayInfo { display("uuid-mac", "Built-in Display") }
    private func commands(displays: [DisplayInfo]? = nil, movement: Bool = true, dimming: Bool = true,
                          operational: Bool = true, busy: Bool = false, warning: Bool = false,
                          updating: Bool = false, undo: DisplayInfo? = nil) -> GuardMenuCommands {
        GuardMenuCommands(displays: displays ?? [lg, laptop], movementIDs:[lg.id], dimmingIDs:[lg.id,laptop.id],
            movementRunning:movement, dimmingRunning:dimming, operational:operational,
            busy:busy, warning:warning, updating:updating, lastMovedDisplay:undo, canUndo:undo != nil)
    }

    func testIndependentSelectionsAndPauseState() {
        let active = commands()
        XCTAssertEqual(active.moves.map(\.id), [.move(lg.id)])
        XCTAssertEqual(active.dims.map(\.id), [.dim(lg.id), .dim(laptop.id)])
        XCTAssertTrue(active.pauseAll.enabled)
        let movementPaused = commands(movement:false)
        XCTAssertTrue(movementPaused.moves.isEmpty)
        XCTAssertEqual(movementPaused.dims.count,2)
        let dimmingPaused = commands(dimming:false)
        XCTAssertEqual(dimmingPaused.moves.count,1)
        XCTAssertTrue(dimmingPaused.dims.isEmpty)
        XCTAssertFalse(dimmingPaused.dimAll.enabled)
        XCTAssertTrue(dimmingPaused.restoreAll.enabled)
        XCTAssertFalse(commands(movement:false,dimming:false).pauseAll.enabled)
    }

    func testWarningBusyPermissionAndUpdateSafety() {
        let warning = commands(warning:true,undo:lg)
        XCTAssertFalse(warning.moves[0].enabled)
        XCTAssertFalse(warning.restoreLastMove.enabled)
        XCTAssertTrue(warning.pauseAll.enabled) // Cancels the countdown as well as both guards.
        XCTAssertTrue(warning.dimAll.enabled)
        let busy = commands(busy:true,undo:lg)
        XCTAssertFalse(busy.pauseAll.enabled)
        XCTAssertFalse(busy.moves[0].enabled)
        XCTAssertFalse(busy.restoreLastMove.enabled)
        XCTAssertTrue(busy.restoreAll.enabled)
        let denied = commands(operational:false,undo:lg)
        XCTAssertFalse(denied.moves[0].enabled)
        XCTAssertFalse(denied.dimAll.enabled)
        XCTAssertTrue(denied.restoreAll.enabled) // Brightness can always be restored without Accessibility.
        let updating = commands(updating:true,undo:lg)
        XCTAssertFalse(updating.moves[0].enabled)
        XCTAssertFalse(updating.dimAll.enabled)
        XCTAssertFalse(updating.restoreAll.enabled)
        XCTAssertFalse(updating.pauseAll.enabled)
    }

    func testDisconnectReorderAndReconnectKeepUUIDTargets() {
        let disconnected = commands(displays:[laptop],undo:lg)
        XCTAssertTrue(disconnected.moves.isEmpty)
        XCTAssertEqual(disconnected.dims.map(\.id),[.dim(laptop.id)])
        XCTAssertFalse(disconnected.restoreLastMove.enabled)
        XCTAssertEqual(disconnected.restoreLastMove.title,"Restore last move — LG UltraWide…")
        let reconnected = commands(displays:[laptop,lg],undo:lg)
        XCTAssertEqual(reconnected.moves.map(\.id),[.move(lg.id)])
        XCTAssertEqual(reconnected.restores.map(\.id),[.restoreBrightness(laptop.id),.restoreBrightness(lg.id)])
        XCTAssertTrue(reconnected.restoreLastMove.enabled)
        let replacement = commands(displays:[laptop,display("replacement-uuid",lg.name)],undo:lg)
        XCTAssertTrue(replacement.moves.isEmpty)
        XCTAssertFalse(replacement.restoreLastMove.enabled) // A matching model name cannot claim the previous move.
    }

    @MainActor func testDockAndPanelShareNamedUUIDCommandsIncludingIdenticalModels() {
        let first = display("uuid-first", "LG UltraWide")
        let second = display("uuid-second", "LG UltraWide")
        let model = GuardMenuCommands(displays:[first,second],movementIDs:[first.id,second.id],
            dimmingIDs:[first.id,second.id],movementRunning:true,dimmingRunning:true,operational:true,
            busy:false,warning:false,updating:false,lastMovedDisplay:second,canUndo:true)
        XCTAssertNotEqual(model.dims[0].title,model.dims[1].title)
        XCTAssertTrue(model.restoreLastMove.title.contains(second.id))
        let menu = NSMenu(); menu.autoenablesItems = false
        AppDelegate().appendMonitorCommands(to:menu,commands:model)
        for (title, expected) in [("Move now…",model.moves), ("Dim now",model.dims), ("Restore brightness",model.restores)] {
            let children = menu.items.first { $0.title == title }!.submenu!
            XCTAssertFalse(children.autoenablesItems)
            for (item, command) in zip(children.items,expected) {
                XCTAssertEqual(item.title,command.title)
                XCTAssertEqual(item.representedObject as? GuardMenuCommand.Action,command.id)
                XCTAssertEqual(item.isEnabled,command.enabled)
            }
        }
        XCTAssertEqual(menu.items.first { $0.title == "Dim now" }!.submenu!.items.last!.representedObject as? GuardMenuCommand.Action,.dimAll)
        XCTAssertEqual(menu.items.first { $0.title == "Restore brightness" }!.submenu!.items.last!.representedObject as? GuardMenuCommand.Action,.restoreAllBrightness)
        XCTAssertEqual(menu.items.last!.title,model.restoreLastMove.title)
    }
}
