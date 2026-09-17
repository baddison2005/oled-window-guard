import SwiftUI

struct DisplayMovementCard: View {
    let display: DisplayInfo
    let groups: [ImportedGroup]
    @Binding var preferences: Preferences
    private var custom: Binding<Bool> {
        Binding(get: { preferences.movementOverrides?[display.id] != nil }, set: { enabled in
            var values = preferences.movementOverrides ?? [:]
            values[display.id] = enabled ? DisplayMovementSettings(preferences) : nil
            preferences.movementOverrides = values
        })
    }
    private func setting<T>(_ path: WritableKeyPath<DisplayMovementSettings,T>) -> Binding<T> {
        Binding(get: { (preferences.movementOverrides?[display.id] ?? DisplayMovementSettings(preferences))[keyPath:path] }, set: { value in
            var settings = preferences.movementOverrides?[display.id] ?? DisplayMovementSettings(preferences)
            settings[keyPath:path] = value
            var values = preferences.movementOverrides ?? [:]; values[display.id] = settings
            preferences.movementOverrides = values
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let effective = preferences.movementSettings(for: display.id)
            Text(display.name).font(.headline)
            Text("\(effective.mode.title) · every \(Int(effective.intervalMinutes)) minutes\(preferences.selectedDisplays.contains(display.id) ? "" : " · Movement off (select in Overview)")").font(.caption)
            Toggle("Custom movement for \(display.name)", isOn: custom)
            if custom.wrappedValue {
                Picker("Movement type", selection: setting(\.mode)) {
                    ForEach(MovementMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                Stepper("Interval: \(Int(effective.intervalMinutes)) minutes", value: setting(\.interval), in: 1...240)
                Stepper("Maximum windows: \(effective.maximumWindows)", value: setting(\.maximumWindows), in: 1...12)
                if effective.mode != .swap {
                    Text("Maximum shift range: \(Int(effective.driftRangePercent))%")
                    Slider(value: setting(\.range), in: 1...100, step: 1)
                }
                if effective.mode == .drift {
                    Toggle("Allow horizontal order changes", isOn: setting(\.horizontal))
                    Toggle("Allow vertical order changes", isOn: setting(\.vertical))
                }
                if effective.mode == .swap { Toggle("Keep similar-sized neighbours together", isOn: setting(\.keepGroups)) }
                if effective.mode == .group {
                    Picker("Layout group", selection: setting(\.groupID)) {
                        Text("Select group").tag("")
                        ForEach(groups) { group in Text(group.name).tag(group.id) }
                    }
                    Toggle("Rotate windows between group zones", isOn: setting(\.rotateGroup))
                    Text("Uses the Window Layouts source selected in Layout groups.").font(.caption)
                }
                Text("Size tolerance: \(Int(effective.sizeTolerance * 100))%")
                Slider(value: setting(\.tolerance), in: 0...0.25, step: 0.01)
            }
        }.padding(14).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius:10))
    }
}
