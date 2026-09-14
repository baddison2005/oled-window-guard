import Foundation

enum LayoutSource: String, CaseIterable, Identifiable {
    case automatic, standard, experimental
    var id: String { rawValue }
    var title: String {
        switch self { case .automatic: "Automatic (running version)"; case .standard: "Window Layouts"; case .experimental: "Window Layouts Experimental" }
    }
    var bundleID: String {
        self == .experimental ? "com.astrobrett.WindowLayouts.Experimental" : "com.astrobrett.WindowLayouts"
    }
    var libraryDirectory: String { self == .experimental ? "Window Layouts Experimental" : "Window Layouts" }
    static func resolve(_ choice: LayoutSource, installed: Set<LayoutSource>, running: Set<LayoutSource>) -> LayoutSource? {
        let available = installed.union(running).subtracting([.automatic])
        if choice != .automatic { return available.contains(choice) ? choice : nil }
        let active = available.intersection(running)
        if active.count == 1 { return active.first }
        if active.isEmpty && available.count == 1 { return available.first }
        return nil
    }
}
