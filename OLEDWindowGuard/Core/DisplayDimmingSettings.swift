import Foundation

struct DisplayDimmingSettings: Codable, Equatable {
    var windows = true
    var display = true
    var windowPercent: Double
    var displayPercent: Double
    var windowDelay: Double
    var displayDelay: Double
    var windowFade: Double
    var displayFade: Double

    init(defaults p: Preferences) {
        windowPercent = p.windowDimmingPercent; displayPercent = p.displayDimmingPercent
        windowDelay = p.windowDimmingDelay; displayDelay = p.displayDimmingDelay
        windowFade = p.windowDimmingFade; displayFade = p.displayDimmingFade
    }
    func validated() -> Self {
        var p = Preferences()
        p.windowDimmingPercent = windowPercent; p.displayDimmingPercent = displayPercent
        p.windowDimmingDelay = windowDelay; p.displayDimmingDelay = displayDelay
        p.windowDimmingFade = windowFade; p.displayDimmingFade = displayFade
        var result = Self(defaults: p.validated())
        result.windows = windows; result.display = display
        return result
    }
}

extension Preferences {
    var dimmingDisplays: Set<String> { get { dimmingDisplayIDs ?? selectedDisplays } set { dimmingDisplayIDs = newValue } }
    var dimmingExclusions: Set<String> { get { dimmingExcludedApps ?? [] } set { dimmingExcludedApps = newValue } }
    func dimmingSettings(for id: String) -> DisplayDimmingSettings {
        var settings = (displayDimmingOverrides?[id] ?? DisplayDimmingSettings(defaults: self)).validated()
        settings.windows = settings.windows && dimUnfocusedWindows
        settings.display = settings.display && dimInactiveDisplays
        return settings
    }
}

struct DisplayDimmingRuntime {
    var windows = DimmingDelay()
    var display = DimmingDelay()
    var windowFade = DimmingFade()
    var displayFade = DimmingFade()
}

struct BrightnessRestore {
    private var deadlines: [String: TimeInterval] = [:]
    mutating func restore(on ids: Set<String>, now: TimeInterval) {
        for id in ids { deadlines[id] = now + 5 }
    }
    mutating func retain(_ ids: Set<String>) { deadlines = deadlines.filter { ids.contains($0.key) } }
    func isActive(on id: String, now: TimeInterval) -> Bool { now < (deadlines[id] ?? 0) }
}
