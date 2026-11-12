import XCTest
@testable import OLEDWindowGuard

final class WarningPositionTests: XCTestCase {
    private let size = CGSize(width: 420, height: 220)

    func testFixedPositionsRespectMenuBarAndSideDockOnSecondaryDisplay() {
        let screen = CGRect(x: -2560, y: 1000, width: 2560, height: 1440)
        let visible = CGRect(x: -2480, y: 1000, width: 2480, height: 1416)
        var rng = MovementTests.RNG(state: 1)

        for (position, expectedX) in [(WarningPosition.topLeft, -2456.0), (.topCenter, -1450), (.topRight, -444)] {
            let origin = position.origin(for: size, screenFrame: screen, visibleFrame: visible, rng: &rng)
            XCTAssertEqual(origin, CGPoint(x: expectedX, y: 2172))
        }
    }

    func testRandomPositionVariesOnBothAxesWithinTopQuarter() {
        let screen = CGRect(x: 100, y: -1600, width: 2400, height: 1600)
        let visible = CGRect(x: 100, y: -1550, width: 2400, height: 1526)
        var rng = MovementTests.RNG(state: 2)
        var xPositions: Set<CGFloat> = []
        var yPositions: Set<CGFloat> = []
        for _ in 0..<20 {
            let origin = WarningPosition.random.origin(for: size, screenFrame: screen, visibleFrame: visible, rng: &rng)
            XCTAssertTrue(visible.contains(CGRect(origin: origin, size: size)))
            XCTAssertGreaterThanOrEqual(origin.y, -400)
            xPositions.insert(origin.x)
            yPositions.insert(origin.y)
        }
        XCTAssertGreaterThan(xPositions.count, 1)
        XCTAssertGreaterThan(yPositions.count, 1)
    }

    func testRandomOnShortDisplayStaysVisibleAndVariesHorizontally() {
        let screen = CGRect(x: 0, y: 0, width: 1280, height: 720)
        let visible = CGRect(x: 0, y: 55, width: 1280, height: 641)
        var rng = MovementTests.RNG(state: 3)
        var xPositions: Set<CGFloat> = []
        for _ in 0..<20 {
            let origin = WarningPosition.random.origin(for: size, screenFrame: screen, visibleFrame: visible, rng: &rng)
            XCTAssertEqual(origin.y + size.height, visible.maxY)
            XCTAssertTrue(visible.contains(CGRect(origin: origin, size: size)))
            xPositions.insert(origin.x)
        }
        XCTAssertGreaterThan(xPositions.count, 1)
    }

    func testWarningPositionPersistsAndLegacyOrUnknownValuesUseTopRight() throws {
        var preferences = Preferences()
        let legacyData = try JSONEncoder().encode(preferences)
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: legacyData).warningPosition, .topRight)
        for position in WarningPosition.allCases {
            preferences.warningPosition = position
            let saved = try JSONEncoder().encode(preferences)
            XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: saved).warningPosition, position)
        }
        preferences.warningPositionID = "unknown"
        let saved = try JSONEncoder().encode(preferences)
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: saved).warningPosition, .topRight)
    }
}
