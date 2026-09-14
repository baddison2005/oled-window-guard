import XCTest
@testable import OLEDWindowGuard

final class LayoutSourceTests: XCTestCase {
    func testAutomaticSelectsOnlyRunningVersion() {
        XCTAssertEqual(LayoutSource.resolve(.automatic, installed: [.standard, .experimental], running: [.experimental]), .experimental)
        XCTAssertEqual(LayoutSource.resolve(.automatic, installed: [.standard, .experimental], running: [.standard]), .standard)
        XCTAssertEqual(LayoutSource.resolve(.automatic, installed: [.experimental], running: []), .experimental)
    }
    func testAmbiguousSourcesRequireChoice() {
        XCTAssertNil(LayoutSource.resolve(.automatic, installed: [.standard, .experimental], running: []))
        XCTAssertNil(LayoutSource.resolve(.automatic, installed: [.standard, .experimental], running: [.standard, .experimental]))
        XCTAssertEqual(LayoutSource.resolve(.standard, installed: [.standard, .experimental], running: [.experimental]), .standard)
        XCTAssertNil(LayoutSource.resolve(.experimental, installed: [.standard], running: []))
    }
    func testLegacyPreferencesDefaultToAutomatic() throws {
        let p = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(Preferences()))
        XCTAssertEqual(p.layoutSource, .automatic)
        var explicit = p; explicit.layoutSource = .experimental
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(explicit)).layoutSource, .experimental)
    }
    func testExperimentalSchemaAndPadding() throws {
        let fixture = StateAndIntegrationTests().fixture(version: 6)
        let data = Data(String(decoding: fixture, as: UTF8.self).replacingOccurrences(of: "\"layoutPadding\":8", with: "\"layoutPadding\":4").utf8)
        let group = try XCTUnwrap(LayoutGroupReader.decode(data).first)
        XCTAssertEqual(group.padding, 4)
        XCTAssertEqual(group.frames(on: MovementTests().display)[0], CGRect(x: 0, y: 24, width: 596, height: 740))
        XCTAssertNotEqual(LayoutSource.standard.libraryDirectory, LayoutSource.experimental.libraryDirectory)
    }
    func testGroupMovesStayInsideFourPointPaddedZones() throws {
        let helper = MovementTests()
        let group = try XCTUnwrap(LayoutGroupReader.builtInGroups(padding: 4).first { $0.id == "builtin.horizontal-halves" })
        let frames = group.frames(on: helper.display)
        XCTAssertEqual(frames[1].minX - frames[0].maxX, 8)
        let windows = frames.enumerated().map { helper.window(String($0.offset), $0.element.minX, $0.element.minY, $0.element.width, $0.element.height) }
        var p = helper.preferences; p.mode = .group; p.rotateGroup = true
        let plan = helper.plan(windows, p: p, group: group)
        XCTAssertEqual(plan.windowCount, 2)
        XCTAssertTrue(plan.moves.allSatisfy { move in frames.contains { Geometry.contains($0, move.to) } })
        XCTAssertTrue(MovementPlanner.safeFinal(moves: plan.moves, world: windows, area: helper.display.usableFrame))
    }
}
