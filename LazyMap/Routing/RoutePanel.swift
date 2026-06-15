import SwiftUI

/// Нижняя панель предпросмотра маршрута (как в Waze): время, расстояние, кнопки.
struct RoutePanel: View {
    let distanceText: String?
    let durationText: String?
    let isCalculating: Bool
    let errorMessage: String?
    var onStart: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 40, height: 5)

            if isCalculating {
                ProgressView("Строю маршрут…")
                    .padding(.vertical, 8)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Закрыть", action: onCancel)
                    .buttonStyle(.glass)
            } else {
                HStack(spacing: 28) {
                    stat(value: durationText ?? "—", label: "в пути")
                    Divider().frame(height: 36)
                    stat(value: distanceText ?? "—", label: "расстояние")
                }

                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Отмена")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)

                    Button(action: onStart) {
                        Label("Начать поездку", systemImage: "location.north.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.blue)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    RoutePanel(distanceText: "8.4 км", durationText: "14 мин",
               isCalculating: false, errorMessage: nil,
               onStart: {}, onCancel: {})
}
