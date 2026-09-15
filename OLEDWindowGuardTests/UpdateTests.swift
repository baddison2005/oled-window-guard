import XCTest
@testable import OLEDWindowGuard

final class UpdateTests: XCTestCase {
    @MainActor func testBuiltAppContainsBetaUpdateConfiguration() {
        let updater = ReleaseUpdater()
        XCTAssertEqual(updater.repository, "baddison2005/oled-window-guard")
        XCTAssertTrue(updater.configured)
        XCTAssertFalse(updater.includesPrereleases)
    }

    func testVersionComparison() {
        XCTAssertGreaterThan(ReleaseVersion("v0.1.10")!, ReleaseVersion("0.1.9")!)
        for value in ["", "1.2", "1.2.3-beta", "../1.2.3", "1.2.-3"] { XCTAssertNil(ReleaseVersion(value)) }
    }

    @MainActor func testReleaseMustMatchRepositoryAndHaveDigest() throws {
        let name = "OLED-Window-Guard-0.1.8-macOS.zip"
        let url = URL(string: "https://github.com/owner/repo/releases/download/v0.1.8/" + name)!
        let asset = ReleaseMetadata.Asset(name: name, browser_download_url: url, size: 100, digest: "sha256:" + String(repeating: "a", count: 64))
        let release = ReleaseMetadata(tag_name: "v0.1.8", draft: false, prerelease: false, assets: [asset])
        XCTAssertNoThrow(try ReleaseUpdater.asset(for: release, repository: "owner/repo"))
        XCTAssertThrowsError(try ReleaseUpdater.asset(for: release, repository: "other/repo"))
        let missing = ReleaseMetadata.Asset(name: name, browser_download_url: url, size: 100, digest: nil)
        XCTAssertThrowsError(try ReleaseUpdater.asset(for: ReleaseMetadata(tag_name: "v0.1.8", draft: false, prerelease: false, assets: [missing]), repository: "owner/repo"))
        XCTAssertThrowsError(try ReleaseUpdater.asset(for: ReleaseMetadata(tag_name: "v0.1.8", draft: false, prerelease: true, assets: [asset]), repository: "owner/repo"))
        XCTAssertFalse(ReleaseUpdater.validRepository(""))
        XCTAssertFalse(ReleaseUpdater.validRepository("../repo"))
    }

    @MainActor func testBetaChannelSelectsNewestCompatibleRelease() throws {
        func release(_ version: String, beta: Bool = false, draft: Bool = false) -> ReleaseMetadata {
            ReleaseMetadata(tag_name: version, draft: draft, prerelease: beta, assets: [])
        }
        let releases = [release("v0.1.17", beta: true), release("v0.1.15"),
                        release("v0.1.99", draft: true), release("invalid"), release("v0.1.16", beta: true)]
        XCTAssertEqual(ReleaseUpdater.newestRelease(releases, includesPrereleases: true)?.tag_name, "v0.1.17")
        XCTAssertEqual(ReleaseUpdater.newestRelease(releases, includesPrereleases: false)?.tag_name, "v0.1.15")
        XCTAssertNil(ReleaseUpdater.newestRelease([release("invalid"), release("v0.1.99", draft: true)], includesPrereleases: true))
        let name = "OLED-Window-Guard-0.1.17-macOS.zip"
        let asset = ReleaseMetadata.Asset(name: name, browser_download_url: URL(string: "https://github.com/owner/repo/releases/download/v0.1.17/" + name)!, size: 100, digest: "sha256:" + String(repeating: "a", count: 64))
        let beta = ReleaseMetadata(tag_name: "v0.1.17", draft: false, prerelease: true, assets: [asset])
        XCTAssertNoThrow(try ReleaseUpdater.asset(for: beta, repository: "owner/repo", includesPrereleases: true))
        XCTAssertThrowsError(try ReleaseUpdater.asset(for: beta, repository: "wrong/repo", includesPrereleases: true))
        XCTAssertThrowsError(try ReleaseUpdater.asset(for: ReleaseMetadata(tag_name: "v0.1.17", draft: true, prerelease: true, assets: [asset]), repository: "owner/repo", includesPrereleases: true))
    }

    func testArchiveRejectsUnexpectedPathsAndLinks() {
        func directory(_ name: String, mode: Int = 0o100644) -> Data {
            var bytes = [UInt8](repeating: 0, count: 46)
            func put(_ value: Int, _ offset: Int, _ count: Int) {
                for i in 0..<count { bytes[offset + i] = UInt8((value >> (i * 8)) & 255) }
            }
            put(0x02014b50, 0, 4); put(name.utf8.count, 28, 2); put(mode << 16, 38, 4)
            bytes += name.utf8
            let end = bytes.count
            bytes += [UInt8](repeating: 0, count: 22)
            put(0x06054b50, end, 4); put(1, end + 8, 2); put(1, end + 10, 2)
            return Data(bytes)
        }
        XCTAssertNoThrow(try UpdateArchive.validate(directory("OLED Window Guard.app/Contents/Info.plist")))
        for path in ["/tmp/a", "OLED Window Guard.app/../../a", "other.app/a"] {
            XCTAssertThrowsError(try UpdateArchive.validate(directory(path)))
        }
        XCTAssertThrowsError(try UpdateArchive.validate(directory("OLED Window Guard.app/link", mode: 0o120777)))
        XCTAssertThrowsError(try UpdateArchive.validate(Data()))
    }
}
