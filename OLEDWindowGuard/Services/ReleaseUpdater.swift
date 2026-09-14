import AppKit
import Combine
import CryptoKit
import Security

struct ReleaseVersion: Comparable {
    let parts: [Int]
    init?(_ text: String) {
        let value = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let chunks = value.split(separator: ".", omittingEmptySubsequences: false)
        guard chunks.count == 3, chunks.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }) else { return nil }
        let numbers = chunks.compactMap { Int($0) }
        guard numbers.count == 3 else { return nil }
        parts = numbers
    }
    static func < (a: Self, b: Self) -> Bool { a.parts.lexicographicallyPrecedes(b.parts) }
}

struct ReleaseMetadata: Decodable {
    struct Asset: Decodable {
        let name: String
        let browser_download_url: URL
        let size: Int
        let digest: String?
    }
    let tag_name: String
    let draft: Bool
    let prerelease: Bool
    let assets: [Asset]
}

enum UpdateFailure: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

@MainActor
final class ReleaseUpdater: ObservableObject {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—" }
    // Set in the release build once the repository has been created. Never infer a repository.
    let repository = Bundle.main.object(forInfoDictionaryKey: "OLEDUpdateRepository") as? String ?? ""
    let includesPrereleases = Bundle.main.object(forInfoDictionaryKey: "OLEDUpdateChannel") as? String == "beta"
    @Published private(set) var status = "Check for a newer release on GitHub."
    @Published private(set) var busy = false
    @Published private(set) var available: ReleaseMetadata?
    var configured: Bool { Self.validRepository(repository) }
    static func validRepository(_ value: String) -> Bool {
        let pieces = value.split(separator: "/", omittingEmptySubsequences: false)
        return pieces.count == 2 && pieces.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." && $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "-_.".contains($0)) } }
    }
    static func asset(for release: ReleaseMetadata, repository: String, includesPrereleases: Bool = false) throws -> ReleaseMetadata.Asset {
        guard validRepository(repository), !release.draft, (includesPrereleases || !release.prerelease),
              ReleaseVersion(release.tag_name) != nil else { throw UpdateFailure.invalid("Invalid release metadata.") }
        let version = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
        let name = "OLED-Window-Guard-\(version)-macOS.zip"
        guard let asset = release.assets.first(where: { $0.name == name }),
              asset.size > 0, asset.size <= 50_000_000,
              asset.browser_download_url.absoluteString == "https://github.com/\(repository)/releases/download/\(release.tag_name)/\(name)",
              let digest = asset.digest, digest.hasPrefix("sha256:"), digest.count == 71,
              digest.dropFirst(7).allSatisfy(\.isHexDigit) else {
            throw UpdateFailure.invalid("The release needs the expected macOS ZIP and a GitHub SHA-256 digest.")
        }
        return asset
    }
    static func newestRelease(_ releases: [ReleaseMetadata], includesPrereleases: Bool) -> ReleaseMetadata? {
        releases.filter { !$0.draft && (includesPrereleases || !$0.prerelease) && ReleaseVersion($0.tag_name) != nil }
            .max { ReleaseVersion($0.tag_name)! < ReleaseVersion($1.tag_name)! }
    }
    func check() {
        guard configured, !busy else { return }
        busy = true; available = nil; status = "Checking GitHub…"
        Task {
            defer { busy = false }
            do {
                let endpoint = includesPrereleases ? "releases?per_page=100" : "releases/latest"
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/\(endpoint)")!)
                request.timeoutInterval = 15
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let response = response as? HTTPURLResponse, response.statusCode == 200, data.count < 1_000_000 else {
                    throw UpdateFailure.invalid("No published release is available, or GitHub could not be reached.")
                }
                let releases = includesPrereleases
                    ? try JSONDecoder().decode([ReleaseMetadata].self, from: data)
                    : [try JSONDecoder().decode(ReleaseMetadata.self, from: data)]
                guard let release = Self.newestRelease(releases, includesPrereleases: includesPrereleases) else {
                    throw UpdateFailure.invalid("No compatible published release is available.")
                }
                guard let latest = ReleaseVersion(release.tag_name), let current = ReleaseVersion(Self.version) else {
                    throw UpdateFailure.invalid("Could not compare release versions.")
                }
                if latest > current {
                    _ = try Self.asset(for: release, repository: repository, includesPrereleases: includesPrereleases)
                    available = release; status = "Version \(release.tag_name) is available."
                } else { status = "You’re up to date (\(Self.version))." }
            } catch { status = error.localizedDescription }
        }
    }
    func install() {
        guard let release = available, !busy else { return }
        busy = true; status = "Downloading and verifying update…"
        let repository = repository
        Task {
            defer { busy = false }
            do {
                let current = Bundle.main.bundleURL
                let prepared = try await UpdateInstaller().install(release, repository: repository, current: current, includesPrereleases: includesPrereleases)
                status = "Restarting…"
                do {
                    let config = NSWorkspace.OpenConfiguration()
                    config.createsNewApplicationInstance = true
                    config.arguments = ["--updated-relaunch"]
                    _ = try await NSWorkspace.shared.openApplication(at: current, configuration: config)
                    NSApp.terminate(nil)
                } catch {
                    try? FileManager.default.moveItem(at: current, to: prepared.deletingLastPathComponent().appendingPathComponent("failed-update.app"))
                    try? FileManager.default.moveItem(at: prepared, to: current)
                    throw UpdateFailure.invalid("Restart failed. The previous app was restored where possible; please reopen it.")
                }
            } catch { status = error.localizedDescription }
        }
    }
}

actor UpdateInstaller {
    func install(_ release: ReleaseMetadata, repository: String, current: URL, includesPrereleases: Bool = false) async throws -> URL {
        guard current.standardizedFileURL.path == "/Applications/OLED Window Guard.app" else {
            throw UpdateFailure.invalid("Install OLED Window Guard in Applications before updating.")
        }
        let asset = try await ReleaseUpdater.asset(for: release, repository: repository, includesPrereleases: includesPrereleases)
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("oled-update-" + UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        var request = URLRequest(url: asset.browser_download_url); request.timeoutInterval = 120
        let (download, response) = try await URLSession.shared.download(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateFailure.invalid("Update download failed.") }
        let size = try download.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard size == asset.size else { throw UpdateFailure.invalid("Update size did not match the release.") }
        let data = try Data(contentsOf: download, options: .mappedIfSafe)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard "sha256:" + hash == asset.digest?.lowercased() else { throw UpdateFailure.invalid("Update checksum failed.") }
        try UpdateArchive.validate(data)
        let archive = root.appendingPathComponent("update.zip")
        try fm.moveItem(at: download, to: archive)
        let extracted = root.appendingPathComponent("extracted")
        try run("/usr/bin/ditto", ["-x", "-k", archive.path, extracted.path])
        let app = extracted.appendingPathComponent("OLED Window Guard.app")
        try validate(app, version: release.tag_name)
        let backupRoot = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("OLED Window Guard/Updates/" + UUID().uuidString)
        try fm.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        let backup = backupRoot.appendingPathComponent("previous.app")
        let staged = current.deletingLastPathComponent().appendingPathComponent(".oled-update-" + UUID().uuidString + ".app")
        defer { try? fm.removeItem(at: staged) }
        try run("/usr/bin/ditto", [app.path, staged.path])
        try validate(staged, version: release.tag_name)
        try fm.moveItem(at: current, to: backup)
        do { try fm.moveItem(at: staged, to: current) }
        catch { try? fm.moveItem(at: backup, to: current); throw error }
        return backup
    }
    private func validate(_ url: URL, version: String) throws {
        guard let bundle = Bundle(url: url), bundle.bundleIdentifier == "com.astrobrett.OLEDWindowGuard",
              let actual = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              ReleaseVersion(actual) == ReleaseVersion(version) else { throw UpdateFailure.invalid("Unexpected application identity or version.") }
        var code: SecStaticCode?, requirement: SecRequirement?
        let rule = "anchor apple generic and identifier \"com.astrobrett.OLEDWindowGuard\" and certificate leaf[subject.OU] = \"SRNLN9U724\""
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              SecRequirementCreateWithString(rule as CFString, [], &requirement) == errSecSuccess,
              let code, let requirement,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSRestrictSymlinks), requirement) == errSecSuccess else {
            throw UpdateFailure.invalid("The update’s developer signature could not be verified.")
        }
        try run("/usr/sbin/spctl", ["--assess", "--type", "execute", url.path])
    }
    private func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateFailure.invalid("Update extraction, validation or installation failed. The previous version is retained.") }
    }
}
