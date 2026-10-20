import SwiftUI

struct GuardStatusLights: View {
    @ObservedObject var model: GuardController
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            light("Movement", enabled: model.running, active: model.movementActive)
            light("Dimming", enabled: model.dimmingRunning, active: model.dimmingActive)
        }.font(.caption.weight(.medium))
    }
    private func light(_ title: String, enabled: Bool, active: Bool) -> some View {
        HStack(spacing: 7) {
            Circle().fill(active ? Color.mint : enabled ? Color.orange : Color.secondary.opacity(0.5)).frame(width: 8, height: 8)
            Text("\(title): \(active ? "Active" : enabled ? "Waiting" : "Paused")")
        }.accessibilityElement(children: .combine)
    }
}
