import SwiftUI
import AppKit

private enum Page: String, CaseIterable, Identifiable {
    case overview = "Overview", movement = "Movement", safety = "Safety & alerts", groups = "Layout groups", about = "About"
    var id: Self { self }
    var symbol: String {
        switch self { case .overview: "display.2"; case .movement: "arrow.up.and.down.and.arrow.left.and.right"; case .safety: "shield.lefthalf.filled"; case .groups: "rectangle.3.group"; case .about: "info.circle" }
    }
}

struct DashboardView: View {
    @EnvironmentObject private var model: GuardController
    @StateObject private var updater = ReleaseUpdater()
    @State private var page: Page = .overview
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "display").font(.system(size: 34, weight: .light)).foregroundStyle(.mint)
                    Text("OLED\nWindow Guard").font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text("Keep your windows moving.\nCare for your OLED.").font(.caption).foregroundStyle(.secondary)
                }.padding(24).padding(.top, 12)
                List(Page.allCases, selection: $page) { item in Label(item.rawValue, systemImage: item.symbol).tag(item).padding(.vertical, 5) }
                    .listStyle(.sidebar)
                VStack(alignment: .leading, spacing: 8) {
                    Label(model.running ? "Guarding" : "Paused", systemImage: model.running ? "circle.fill" : "pause.circle")
                        .font(.caption.weight(.medium)).foregroundStyle(model.running ? Color.mint : Color.secondary)
                    Text("Version \(ReleaseUpdater.version) · Beta").font(.caption2).foregroundStyle(.tertiary)
                }.padding(24)
            }
            .navigationSplitViewColumnWidth(230)
        } detail: {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(page.rawValue).font(.system(size: 26, weight: .semibold, design: .rounded))
                        Text(subtitle).font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(model.running ? "Pause guarding" : "Start guarding") { model.toggleRunning() }
                        .buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black).disabled(model.busy || updater.busy)
                }.padding(28)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if !model.trusted { permissionCard }
                        switch page {
                        case .overview: overview
                        case .movement: movement
                        case .safety: safety
                        case .groups: groups
                        case .about: about
                        }
                    }.padding(28).frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: model.warningActive ? "clock.badge.exclamationmark" : "info.circle").foregroundStyle(.mint)
                    Text(model.status).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    if model.warningActive { Button("Skip") { model.skip() }.controlSize(.small) }
                }.padding(16).background(.bar)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(.mint)
        .onChange(of: updater.busy) { _, busy in if !busy { model.updateInProgress = false } }
    }

    private var subtitle: String {
        switch page {
        case .overview: "Automatically shift and rotate application windows to reduce how long content stays in one place."
        case .movement: "Choose how far, how often, and how many."
        case .safety: "Predictable movement starts with sensible boundaries."
        case .groups: "Give your Window Layouts groups room to move."
        case .about: "Keep your windows moving. Care for your OLED."
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("OLED Window Guard", systemImage: "display").font(.largeTitle)
            Text("Keep your windows moving. Care for your OLED.").font(.title3)
            Text("Automatically shift and rotate application windows to reduce how long content stays in one place. Choose individual shifts, coordinated swaps or Window Layouts groups, with advance warnings and activity-aware cancellation.")
            Text("Version \(ReleaseUpdater.version) · Build \(ReleaseUpdater.build)").font(.headline)
            Text("Created by Brett Addison.").foregroundStyle(.secondary)
            Text("Display care & legal notice").font(.headline)
            Text("OLED Window Guard does not guarantee prevention of OLED burn-in, image retention or other display damage. Follow your display manufacturer’s care instructions, including recommended pixel-care features, brightness settings and display sleep, to help reduce these risks.")
            Text("To the maximum extent permitted by applicable law, OLED Window Guard is provided ‘as is’, without warranties of any kind, express or implied, and its developer is not liable for OLED burn-in, image retention, display damage or related loss arising from use of the app. Nothing in this notice excludes, restricts or modifies any consumer guarantee, right or remedy that cannot lawfully be excluded, including under the Australian Consumer Law.").foregroundStyle(.secondary)
            Divider()
            Text("Software updates").font(.headline)
            Text(updater.includesPrereleases ? "Update channel: Public beta (includes prereleases)" : "Update channel: Stable").font(.caption).foregroundStyle(.secondary)
            Text(updater.status).accessibilityIdentifier("update-status")
            if !updater.configured {
                Text("GitHub releases are not configured yet. Update checks and installation will become available in a release connected to the official repository.").foregroundStyle(.secondary)
            }
            HStack {
                Button("Check for updates") { updater.check() }.disabled(!updater.configured || updater.busy)
                if updater.available != nil {
                    Button("Install update and restart") { model.updateInProgress = true; updater.install() }
                        .disabled(updater.busy || model.running || model.busy || model.warningActive)
                }
                if updater.busy { ProgressView().controlSize(.small) }
            }
            if updater.available != nil && model.running { Text("Pause guarding before installing an update.").font(.caption) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var permissionCard: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "hand.raised.fill").font(.title2).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text("Allow window control").font(.headline)
                Text("Accessibility access lets OLED Window Guard read window positions and move them. Window titles and screen contents are not recorded.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("Grant Accessibility access") { model.grantAccessibility() }
                    Button("Check again") { model.refresh() }
                }
            }
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private var overview: some View {
        Group {
            HStack(spacing: 16) {
                metric(model.phaseTitle, value: model.countdown, note: model.warningActive ? "until movement" : "until next check", symbol: "timer")
                metric("Selected displays", value: "\(model.snapshot.displays.filter { model.preferences.selectedDisplays.contains($0.id) }.count)", note: "of \(model.snapshot.displays.count) connected", symbol: "display.2")
                metric("Windows moved", value: "\(model.movedCount)", note: "this session", symbol: "arrow.triangle.swap")
            }
            sectionTitle("Your displays", trailing: "Select the screens to guard")
            ForEach(model.snapshot.displays) { display in
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Toggle(isOn: displayBinding(display.id)) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(display.name).font(.headline)
                                Text("\(Int(display.frame.width)) × \(Int(display.frame.height)) points · \(Int(display.scale))× backing scale")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }.toggleStyle(.checkbox)
                    }
                    DisplayMap(display: display, windows: model.snapshot.windows, plan: model.preview, group: model.preferences.mode == .group ? model.selectedGroup : nil)
                        .frame(height: 160)
                }.padding(18).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
            }
            if model.preferences.mode == .group {
                Label(importedPaddingDescription, systemImage: "rectangle.inset.filled")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if model.preferences.mode == .swap {
                HStack {
                    Label(model.preferences.keepSimilarWindowsTogether
                          ? "Swap grouping: On — adjacent similar-sized windows stay together."
                          : "Swap grouping: Off — windows move individually.", systemImage: "rectangle.3.group")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Movement settings") { page = .movement }.controlSize(.small)
                }
            }
            HStack(spacing: 10) {
                Button("Preview safe moves", systemImage: "viewfinder") { model.showPreview() }
                Button("Move after warning…", systemImage: "play") { model.moveSoon() }.disabled(!model.trusted || model.warningActive)
                    .help("Starts the warning immediately, then moves windows when the countdown ends if the safety and activity checks pass.")
                Button("Restore last move…", systemImage: "arrow.uturn.backward") { model.restoreLastMove() }.disabled(!model.canUndo)
                    .help("After a warning, restores the previous window positions and any sizes adjusted by the last move, if they can still be restored safely.")
                Spacer()
                Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh displays and windows")
            }.disabled(model.busy)
            VStack(alignment: .leading, spacing: 6) {
                Text("**Move after warning…** displays the move warning immediately, then moves the windows when the countdown ends. Activity on an affected display or a failed safety check can cancel the move.")
                Text("**Restore last move…** returns windows to their positions before the last successful move, including any sizes adjusted by group rotation. It also gives a warning first and cancels if the windows have changed or cannot be restored safely.")
            }.font(.caption).foregroundStyle(.secondary)
            Text("Preview outlines show possible destinations. A fresh plan is checked before movement. Grey windows remain obstacles; mint outlines are planned positions.")
                .font(.caption).foregroundStyle(.secondary)
            if let preview = model.preview { Text(preview.reason).font(.callout).foregroundStyle(.mint) }
            Text("Movement can vary static edge placement, but cannot guarantee prevention of OLED burn-in. Keep your display’s pixel care features and sleep settings enabled.")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
        }
    }

    private var movement: some View {
        Group {
            VStack(alignment: .leading, spacing: 14) {
                Text("Movement style").font(.headline)
                ForEach(MovementMode.allCases) { mode in
                    Button { model.preferences.mode = mode } label: {
                        HStack(spacing: 14) {
                            Image(systemName: mode.symbol).font(.title3).frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.title).font(.headline)
                                Text(modeDescription(mode)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: model.preferences.mode == mode ? "largecircle.fill.circle" : "circle")
                        }.padding(16).contentShape(Rectangle())
                    }.buttonStyle(.plain).background(model.preferences.mode == mode ? Color.mint.opacity(0.12) : Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            settingsCard {
                numberRow("Check every", value: $model.preferences.intervalMinutes, range: 1...240, unit: "minutes")
                Divider()
                Stepper("Up to \(model.preferences.maximumWindows) windows per cycle", value: $model.preferences.maximumWindows, in: 1...12)
                if model.preferences.mode == .swap {
                    Toggle("Keep adjacent similar-sized windows together", isOn: $model.preferences.keepSimilarWindowsTogether)
                    Text("Only similarly sized windows that touch or have gaps up to 8 points form a group. Larger or smaller neighbours move independently. Groups keep their spacing and arrangement, and may move into suitable empty space as well as exchange positions. If a group cannot move intact, it stays in place. The window limit counts every member.").font(.caption).foregroundStyle(.secondary)
                }
                Text(model.preferences.keepSimilarWindowsTogether && model.preferences.mode == .swap
                     ? "An individual window or an intact group can move into free space without a swap partner. Each window stays on its selected display and keeps its size."
                     : "Swapping needs at least two eligible windows. Each window stays on its selected display and keeps its size.").font(.caption).foregroundStyle(.secondary)
            }
            settingsCard {
                numberRow("Maximum shift range", value: $model.preferences.driftRangePercent, range: 1...100, unit: "%")
                Text("A percentage of each display’s usable width and height. Destinations are randomized within this range of the original position; each move is also limited to this range. At 100%, any on-screen position that fits is within range. Previous destinations are avoided when another safe location is available.").font(.caption).foregroundStyle(.secondary)
                Text("For example, 10% on a 5120 × 2160 display permits up to 512 points horizontally and 216 vertically. Available space, other windows and group boundaries can reduce movement. Moving a window yourself resets its origin.").font(.caption).foregroundStyle(.secondary)
            }
            settingsCard {
                HStack {
                    Text("Preferred swap / group-zone size tolerance")
                    Spacer()
                    Text("\(Int(model.preferences.sizeTolerance * 100))%").monospacedDigit()
                }
                Slider(value: $model.preferences.sizeTolerance, in: 0...0.25, step: 0.01)
                Text("Swap positions tries similar-sized exchanges first, then coordinated arrangements of different-sized windows. Group rotation uses this tolerance to match zones. Swap positions preserves sizes. Group rotation may shrink resizable windows to fit padding: twice the imported padding plus 2 rounding points, capped at 32 points per dimension.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var safety: some View {
        Group {
            settingsCard {
                Text("Before every move").font(.headline)
                numberRow("Advance warning", value: $model.preferences.warningSeconds, range: 3...60, unit: "seconds")
                Toggle("Play a gentle sound when the warning starts", isOn: $model.preferences.soundEnabled)
                Toggle("Also send a macOS notification", isOn: Binding(get: { model.preferences.systemNotifications }, set: model.setNotifications))
                Text("A notice with a Skip button appears on each affected display. System notifications may be silenced by Focus; the on-screen notice remains available.").font(.caption).foregroundStyle(.secondary)
            }
            settingsCard {
                Text("Protect your workflow").font(.headline)
                Toggle("Leave the currently focused window alone", isOn: $model.preferences.avoidFocusedWindow)
                numberRow("Wait after typing, clicking or scrolling", value: $model.preferences.quietSeconds, range: 0...60, unit: "seconds")
                Text("Warnings appear at the scheduled interval even while you work. Movement requires this much quiet time when the countdown ends; recent activity on an affected display cancels the move and shows a notice.").font(.caption).foregroundStyle(.secondary)
                if model.preferences.quietSeconds > model.preferences.warningSeconds {
                    Text("Your quiet time is longer than the advance warning. Activity just before or during the warning can cancel the move, even if you stop as soon as the notice appears.")
                        .font(.caption).foregroundStyle(.orange)
                }
                Toggle("Allow brief overlap in Swap positions mode", isOn: $model.preferences.allowTransientOverlap)
                Text("Swap positions mode needs staging space when this is off. Group rotation always allows brief overlap during placement so snapped layouts can rearrange. All completed arrangements must be on-screen and free of overlap.").font(.caption).foregroundStyle(.secondary)
                Divider()
                Label("Full-screen, maximised, minimised, dialog and unsupported windows are always skipped.", systemImage: "checkmark.shield").font(.callout)
                Label("Sleep, Space changes and display changes cancel pending moves.", systemImage: "moon.zzz").font(.callout)
                Label("Existing overlaps are left alone. Make space before guarding.", systemImage: "rectangle.on.rectangle.slash").font(.callout)
            }
            settingsCard {
                HStack { Text("App exclusions").font(.headline); Spacer(); Button("Add app…") { addExcludedApp() } }
                Text("Excluded applications stay in place and still count as obstacles.").font(.caption).foregroundStyle(.secondary)
                ForEach(model.preferences.excludedApps.sorted(), id: \.self) { id in
                    HStack {
                        Text(appName(id)).lineLimit(1)
                        Spacer()
                        Button("Remove") { model.preferences.excludedApps.remove(id) }.controlSize(.small)
                    }
                }
            }
            settingsCard {
                Toggle("Launch at login", isOn: Binding(get: { model.loginEnabled }, set: model.setLogin))
                Text("The app launches paused, so you can review displays before starting. Install it in Applications before enabling launch at login.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var importedPaddingDescription: String {
        guard let padding = model.groups.first?.padding else {
            return "Window Layouts padding: unavailable. Select a readable layout source in Layout groups."
        }
        return "Window Layouts padding: \(padding.formatted()) logical points per internal edge (\((padding * 2).formatted())-point gap between adjacent padded zones), read from the active layout source. Group resize allowance: \(GroupPaddingPolicy.resizeLimit(padding).formatted()) points per dimension."
    }

    private var groups: some View {
        Group {
            settingsCard {
                HStack {
                    Label("Window Layouts for macOS", systemImage: "rectangle.3.group").font(.headline)
                    Spacer()
                    Button("Reload groups") { model.refreshGroups() }
                }
                Text(model.integrationStatus).font(.callout).foregroundStyle(.secondary)
                Picker("Layout source", selection: $model.preferences.layoutSource) {
                    ForEach(LayoutSource.allCases) { Text($0.title).tag($0) }
                }
                Text("Automatic uses the only running version, or the only installed version when neither is running. If both are running, or both are installed but neither is running, choose a source. Layouts and padding always come from the same library; changes are checked before each move.").font(.caption).foregroundStyle(.secondary)
                Text(importedPaddingDescription).font(.caption).foregroundStyle(.secondary)
                Text("Windows must fit the padded destination. The resize allowance is twice the imported padding plus 2 rounding points, capped at 32 points per dimension.").font(.caption).foregroundStyle(.secondary)
                if !model.groups.isEmpty {
                    Picker("Layout group", selection: $model.preferences.groupID) {
                        Text("Choose a group").tag("")
                        ForEach(model.groups) { Text($0.name).tag($0.id) }
                    }
                    Toggle("Rotate windows between group zones", isOn: $model.preferences.rotateGroup)
                    Text(model.preferences.rotateGroup ? "Plans the whole arrangement together, moving as many eligible windows as possible to other similarly sized zones, including empty zones. Mixed window shapes can move in the same cycle. Resizable windows may shrink to fit padding (twice the padding plus 2 points, capped at 32 per dimension); Restore also restores their sizes. Windows may briefly overlap during placement; the completed arrangement never overlaps." : "Each window drifts inside the single group zone that fully contains it. Add padding or leave extra space inside each zone to allow movement.")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Use this group for movement") { model.preferences.mode = .group }.disabled(model.selectedGroup == nil)
                }
            }
            if let group = model.selectedGroup {
                ForEach(model.snapshot.displays.filter { model.preferences.selectedDisplays.contains($0.id) }) { display in
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(group.name) · \(display.name)").font(.headline)
                        DisplayMap(display: display, windows: model.snapshot.windows, plan: nil, group: group).frame(height: 200)
                    }
                }
                Text("\(group.zones.count) zones. Rotation treats overlapping zones as alternative destinations and checks the complete arrangement. Drift requires a single containing zone and spare space within it. The window limit, exclusions and focused-window setting still apply.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Text("The integration reads the built-in groups, saved custom groups and padding from Window Layouts. It does not modify the library or invoke layouts. Changes saved in Window Layouts are reloaded before each cycle.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func metric(_ title: String, value: String, note: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: symbol).foregroundStyle(.mint); Text(title).font(.caption).lineLimit(1) }
            Text(value).font(.system(size: 30, weight: .medium, design: .rounded)).monospacedDigit()
            Text(note).font(.caption).foregroundStyle(.secondary)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }
    private func sectionTitle(_ title: String, trailing: String) -> some View {
        HStack { Text(title).font(.headline); Spacer(); Text(trailing).font(.caption).foregroundStyle(.secondary) }
    }
    private func settingsCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16, content: content).padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }
    private func numberRow(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: Binding(get: { value.wrappedValue }, set: { input in
                guard input.isFinite else { return }
                value.wrappedValue = min(max(input.rounded(), range.lowerBound), range.upperBound)
            }), format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 64)
                .accessibilityLabel(title)
            Text(unit).foregroundStyle(.secondary)
            Stepper(title, value: value, in: range, step: 1).labelsHidden()
        }
    }
    private func displayBinding(_ id: String) -> Binding<Bool> {
        Binding(get: { model.preferences.selectedDisplays.contains(id) }, set: { selected in
            if selected { model.preferences.selectedDisplays.insert(id) } else { model.preferences.selectedDisplays.remove(id) }
        })
    }
    private func modeDescription(_ mode: MovementMode) -> String {
        switch mode {
        case .drift: "Random positions within 1–100% of the display dimensions. At 100%, any free position on the display can be considered."
        case .swap: "Rearrange two or more windows together, including different sizes, without resizing."
        case .group: "Drift inside saved zones, or rotate windows between them."
        }
    }
    private func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application to keep still"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier {
            model.preferences.excludedApps.insert(id)
        }
    }
    private func appName(_ id: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)?.deletingPathExtension().lastPathComponent ?? id
    }
}

private struct DisplayMap: View {
    let display: DisplayInfo
    let windows: [WindowInfo]
    let plan: MovementPlan?
    let group: ImportedGroup?
    var body: some View {
        Canvas { context, size in
            let scale = min((size.width - 20) / display.frame.width, (size.height - 20) / display.frame.height)
            let origin = CGPoint(x: (size.width - display.frame.width * scale) / 2, y: (size.height - display.frame.height * scale) / 2)
            func transform(_ frame: CGRect) -> CGRect {
                CGRect(x: origin.x + (frame.minX - display.frame.minX) * scale,
                       y: origin.y + (frame.minY - display.frame.minY) * scale,
                       width: frame.width * scale, height: frame.height * scale)
            }
            context.fill(Path(roundedRect: transform(display.frame), cornerRadius: 6), with: .color(.black.opacity(0.16)))
            context.stroke(Path(transform(display.usableFrame)), with: .color(.secondary.opacity(0.35)), lineWidth: 1)
            for zone in group?.frames(on: display) ?? [] {
                context.stroke(Path(transform(zone)), with: .color(.orange.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            for window in windows where Geometry.overlaps(window.frame, display.frame) {
                let rect = transform(window.frame.intersection(display.frame))
                context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.gray.opacity(0.28)))
                context.stroke(Path(roundedRect: rect, cornerRadius: 3), with: .color(.gray.opacity(0.6)), lineWidth: 1)
                if rect.width > 65 && rect.height > 25 {
                    context.draw(Text(window.appName).font(.system(size: 10)).foregroundColor(.secondary), at: CGPoint(x: rect.midX, y: rect.midY))
                }
            }
            for move in plan?.moves ?? [] where Geometry.contains(display.usableFrame, move.to) {
                context.stroke(Path(roundedRect: transform(move.to), cornerRadius: 3), with: .color(.mint), lineWidth: 2)
            }
        }
        .accessibilityLabel("\(display.name), \(windows.filter { $0.displayID == display.id }.count) windows. Planned destinations are outlined in mint.")
    }
}
