import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class WarningPresenter {
    private var panels: [NSPanel] = []
    private let notificationID = "upcoming-move"
    private var cancellationDismissal: Task<Void, Never>?

    func requestNotifications() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func show(count: Int, seconds: Int, displays: Set<String>, quietSeconds: Double, sound: Bool, notify: Bool, cancel: @escaping () -> Void) {
        dismiss()
        let all = DesktopService().displays()
        for (index, screen) in NSScreen.screens.enumerated() where index < all.count && displays.contains(all[index].id) {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 220),
                                styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.isReleasedWhenClosed = false
            panel.animationBehavior = .none
            panel.contentView = NSHostingView(rootView: WarningCard(count: count, deadline: Date().addingTimeInterval(Double(seconds)), quietSeconds: quietSeconds, cancel: cancel))
            panel.setFrameOrigin(CGPoint(x: screen.visibleFrame.maxX - 444, y: screen.visibleFrame.maxY - 244))
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        if sound { NSSound(named: "Glass")?.play() }
        if notify {
            let content = UNMutableNotificationContent()
            content.title = "OLED Window Guard"
            content.body = "\(count) window\(count == 1 ? "" : "s") will move in \(seconds) seconds. " + ActivityPolicy.explanation(quietSeconds: quietSeconds)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: notificationID, content: content, trigger: nil))
        }
    }

    func showCancellation(message: String, displays: Set<String>, notify: Bool) {
        dismiss()
        let all = DesktopService().displays()
        for (index, screen) in NSScreen.screens.enumerated() where index < all.count && displays.contains(all[index].id) {
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 140),
                                styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.isReleasedWhenClosed = false
            panel.animationBehavior = .none
            panel.contentView = NSHostingView(rootView:
                Text(message).font(.callout).fixedSize(horizontal: false, vertical: true)
                    .padding(24).frame(width: 420, height: 140)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18)))
            panel.setFrameOrigin(CGPoint(x: screen.visibleFrame.maxX - 444, y: screen.visibleFrame.maxY - 164))
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        if notify {
            let content = UNMutableNotificationContent()
            content.title = "OLED Window Guard"
            content.body = message
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: notificationID, content: content, trigger: nil))
        }
        cancellationDismissal = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(6)) } catch { return }
            self?.dismiss()
        }
    }

    @discardableResult
    func dismiss() -> Set<CGWindowID> {
        cancellationDismissal?.cancel()
        cancellationDismissal = nil
        let windowNumbers = Set(panels.compactMap { $0.windowNumber > 0 ? CGWindowID($0.windowNumber) : nil })
        // Close these transient windows entirely; an ordered-out panel can linger
        // in WindowServer metadata while its disappearance animation settles.
        panels.forEach { $0.close() }
        panels.removeAll()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationID])
        return windowNumbers
    }
}

private struct WarningCard: View {
    let count: Int
    let deadline: Date
    let quietSeconds: Double
    let cancel: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right").font(.title2).foregroundStyle(.mint)
            VStack(alignment: .leading, spacing: 6) {
                Text("Windows will move shortly").font(.headline)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("\(count) windows · \(max(0, Int(ceil(deadline.timeIntervalSince(context.date))))) seconds")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Text(ActivityPolicy.explanation(quietSeconds: quietSeconds))
                    .font(.callout).fixedSize(horizontal: false, vertical: true)
                Button("Skip this move", action: cancel).buttonStyle(.link)
            }
            Spacer(minLength: 0)
        }
        .padding(20).frame(width: 420, height: 220)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12)))
    }
}
