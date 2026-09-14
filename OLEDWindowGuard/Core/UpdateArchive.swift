import Foundation

enum UpdateArchive {
    /// Reject links, traversal, oversized expansion and unsupported ZIP64 archives
    /// before invoking the system extractor on a downloaded archive.
    static func validate(_ data: Data) throws {
        let bytes = [UInt8](data)
        func number(_ offset: Int, _ length: Int) throws -> Int {
            guard offset >= 0, offset <= bytes.count - length else { throw UpdateFailure.invalid("Invalid ZIP structure.") }
            return (0..<length).reduce(0) { $0 | (Int(bytes[offset + $1]) << ($1 * 8)) }
        }
        guard bytes.count >= 22 else { throw UpdateFailure.invalid("Invalid ZIP archive.") }
        var end: Int?
        for i in stride(from: bytes.count - 22, through: max(0, bytes.count - 65557), by: -1) {
            if try number(i, 4) == 0x06054b50 { end = i; break }
        }
        guard let end, try number(end + 4, 2) == 0, try number(end + 6, 2) == 0 else { throw UpdateFailure.invalid("Unsupported ZIP archive.") }
        let count = try number(end + 10, 2)
        var offset = try number(end + 16, 4)
        guard count > 0, count < 10_000, offset < end else { throw UpdateFailure.invalid("Unsupported ZIP directory.") }
        var total = 0
        for _ in 0..<count {
            guard try number(offset, 4) == 0x02014b50 else { throw UpdateFailure.invalid("Invalid ZIP directory.") }
            let nameSize = try number(offset + 28, 2)
            let extra = try number(offset + 30, 2), comment = try number(offset + 32, 2)
            let mode = try number(offset + 38, 4) >> 16
            total += try number(offset + 24, 4)
            guard total <= 300_000_000, mode & 0xf000 != 0xa000,
                  offset + 46 + nameSize <= end else { throw UpdateFailure.invalid("Archive has links or exceeds the extraction limit.") }
            let name = String(decoding: bytes[(offset + 46)..<(offset + 46 + nameSize)], as: UTF8.self)
            let parts = name.split(separator: "/", omittingEmptySubsequences: false)
            guard !name.hasPrefix("/"), !name.contains("\\"), !name.contains("\0"),
                  !parts.contains(".."), !parts.contains("."),
                  parts.first == "OLED Window Guard.app" || parts.first == "__MACOSX" else {
                throw UpdateFailure.invalid("Archive contains unexpected paths.")
            }
            offset += 46 + nameSize + extra + comment
        }
    }
}
