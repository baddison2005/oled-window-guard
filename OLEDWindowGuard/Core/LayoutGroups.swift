import Foundation
import CoreGraphics

enum GroupPaddingPolicy {
    static func resizeLimit(_ padding: CGFloat) -> CGFloat { min(32, max(0, padding) * 2 + 2) }
    static func sourceAllowance(_ padding: CGFloat) -> CGFloat { min(32, max(0, padding) + 2) }
}

struct LayoutZone: Decodable, Equatable {
    let id: UUID
    let name: String
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let groupId: UUID?

    var valid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite) && x >= 0 && y >= 0
        && width > 0 && height > 0 && x + width <= 1.000001 && y + height <= 1.000001
    }
    func rect(in area: CGRect, padding: CGFloat) -> CGRect {
        // Window Layouts applies padding only to internal zone edges.
        let left = (area.minX + area.width * x).rounded() + (x > 0.000001 ? padding : 0)
        let top = (area.minY + area.height * y).rounded() + (y > 0.000001 ? padding : 0)
        let right = (area.minX + area.width * (x + width)).rounded() - (x + width < 0.999999 ? padding : 0)
        let bottom = (area.minY + area.height * (y + height)).rounded() - (y + height < 0.999999 ? padding : 0)
        return CGRect(x: left, y: top, width: max(0, right - left), height: max(0, bottom - top))
    }
}

struct ImportedGroup: Identifiable, Equatable {
    let id: String
    let name: String
    let zones: [LayoutZone]
    let padding: CGFloat
    func frames(on display: DisplayInfo) -> [CGRect] {
        zones.map { $0.rect(in: display.usableFrame, padding: padding) }.filter(Geometry.valid)
    }
}

enum LayoutImportError: LocalizedError {
    case invalid
    var errorDescription: String? { "The Window Layouts library has an unsupported version or invalid groups. Its file has not been changed." }
}

enum LayoutGroupReader {
    static func builtInGroups(padding: CGFloat = 0) -> [ImportedGroup] {
        let halves: [(Double, Double, Double, Double)] = [(0,0,0.5,1),(0.5,0,0.5,1),(0,0,1,0.5),(0,0.5,1,0.5)]
        let definitions: [(String, String, [(Double, Double, Double, Double)])] = [
            ("halves", "Halves", halves),
            ("horizontal-halves", "Horizontal Halves", Array(halves.prefix(2))),
            ("vertical-halves", "Vertical Halves", Array(halves.suffix(2))),
            ("quarters", "Quarters", [(0,0,0.5,0.5),(0.5,0,0.5,0.5),(0,0.5,0.5,0.5),(0.5,0.5,0.5,0.5)]),
            ("thirds", "Thirds", [(0,0,1.0/3,1),(1.0/3,0,1.0/3,1),(2.0/3,0,1.0/3,1)]),
            ("two-thirds", "Two Thirds", [(0,0,2.0/3,1),(1.0/6,0,2.0/3,1),(1.0/3,0,2.0/3,1)])
        ]
        return definitions.enumerated().map { groupIndex, definition in
            ImportedGroup(id: "builtin." + definition.0, name: definition.1,
                zones: definition.2.enumerated().map { zoneIndex, r in
                    let suffix = String(format: "%012d", groupIndex * 100 + zoneIndex)
                    return LayoutZone(id: UUID(uuidString: "00000000-0000-0000-0000-" + suffix)!,
                        name: definition.1, x: r.0, y: r.1, width: r.2, height: r.3, groupId: nil)
                }, padding: padding)
        }
    }

    struct Library: Decodable {
        struct Group: Decodable { let id: UUID; let name: String }
        let schemaVersion: Int
        let customLayouts: [LayoutZone]
        let customGroups: [Group]
        let layoutPadding: Double?
    }
    static func decode(_ data: Data) throws -> [ImportedGroup] {
        let library = try JSONDecoder().decode(Library.self, from: data)
        let padding = library.layoutPadding ?? 0
        let ids = Set(library.customGroups.map(\.id))
        // Experimental schema 6 adds Space movement settings; zone coordinates,
        // custom group IDs and logical padding retain the schema 5 representation.
        guard (1...6).contains(library.schemaVersion), padding.isFinite, (0...200).contains(padding),
              ids.count == library.customGroups.count,
              Set(library.customLayouts.map(\.id)).count == library.customLayouts.count,
              library.customLayouts.allSatisfy({ $0.valid && ($0.groupId == nil || ids.contains($0.groupId!)) }),
              library.customGroups.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        else { throw LayoutImportError.invalid }
        return library.customGroups.map { group in
            ImportedGroup(id: group.id.uuidString, name: group.name,
                          zones: library.customLayouts.filter { $0.groupId == group.id }, padding: padding)
        }.filter { !$0.zones.isEmpty }
    }
}
