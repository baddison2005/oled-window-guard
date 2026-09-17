import SwiftUI

struct DisplayDimmingCard: View {
    let display: DisplayInfo
    @Binding var preferences: Preferences
    private var included: Binding<Bool> {
        Binding(get: { preferences.dimmingDisplays.contains(display.id) }, set: { value in
            var ids = preferences.dimmingDisplays
            if value { ids.insert(display.id) } else { ids.remove(display.id) }
            preferences.dimmingDisplays = ids
        })
    }
    private var custom: Binding<Bool> {
        Binding(get: { preferences.displayDimmingOverrides?[display.id] != nil }, set: { value in
            var overrides = preferences.displayDimmingOverrides ?? [:]
            overrides[display.id] = value ? DisplayDimmingSettings(defaults: preferences) : nil
            preferences.displayDimmingOverrides = overrides
        })
    }
    private func setting<T>(_ path: WritableKeyPath<DisplayDimmingSettings, T>) -> Binding<T> {
        Binding(get: { (preferences.displayDimmingOverrides?[display.id] ?? DisplayDimmingSettings(defaults: preferences))[keyPath: path] }, set: { value in
            var settings = preferences.displayDimmingOverrides?[display.id] ?? DisplayDimmingSettings(defaults: preferences)
            settings[keyPath: path] = value
            var overrides = preferences.displayDimmingOverrides ?? [:]
            overrides[display.id] = settings
            preferences.displayDimmingOverrides = overrides
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Dim on \(display.name)", isOn: included).font(.headline)
            Text("\(Int(display.frame.width)) × \(Int(display.frame.height)) points · Display \(display.id.suffix(8))").font(.caption).foregroundStyle(.secondary)
            if included.wrappedValue {
                let effective = preferences.dimmingSettings(for: display.id)
                Text("Windows: \(effective.windows ? "\(Int(effective.windowPercent))%" : "Off") · Display: \(effective.display ? "\(Int(effective.displayPercent))%" : "Off")\(custom.wrappedValue ? " · Custom settings" : " · Uses defaults below")").font(.caption)
                Toggle("Custom settings for \(display.name)", isOn: custom)
                if custom.wrappedValue {
                    Toggle("Window dimming on this display", isOn: setting(\.windows))
                    valueRow("Window dimming", path: \.windowPercent, range: 0...90, unit: "%")
                    valueRow("Window activation delay", path: \.windowDelay, range: 0...600, unit: "seconds")
                    fadeRow("Window", path: \.windowFade)
                    Toggle("Display dimming on this display", isOn: setting(\.display))
                    valueRow("Display dimming", path: \.displayPercent, range: 0...90, unit: "%")
                    valueRow("Display activation delay", path: \.displayDelay, range: 0...600, unit: "seconds")
                    fadeRow("Display", path: \.displayFade)
                    Text("The main window/display dimming switches below must also be enabled.").font(.caption).foregroundStyle(.secondary)
                }
            } else { Text("Dimming is off on this display.").font(.caption).foregroundStyle(.secondary) }
        }.padding(14).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }
    private func valueRow(_ title: String, path: WritableKeyPath<DisplayDimmingSettings, Double>, range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(title); Spacer()
            TextField(title, value: setting(path), format: .number).frame(width: 65)
            Stepper(unit, value: setting(path), in: range).fixedSize()
        }
    }
    private func fadeRow(_ title: String, path: WritableKeyPath<DisplayDimmingSettings, Double>) -> some View {
        VStack(alignment: .leading) {
            Text("\(title) fade: \(setting(path).wrappedValue, specifier: "%.1f") seconds")
            Slider(value: setting(path), in: 0...3, step: 0.5).accessibilityLabel("\(display.name) \(title) fade duration")
        }
    }
}
