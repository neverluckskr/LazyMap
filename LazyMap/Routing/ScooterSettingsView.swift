import SwiftUI

/// Настройки самоката: крейсерская скорость, запас хода, текущий заряд.
struct ScooterSettingsView: View {
    @ObservedObject var profile: ScooterProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Крейсерская скорость") {
                    sliderRow(value: $profile.speedKmh, range: 5...40, unit: "км/ч")
                }
                Section("Запас хода (полный заряд)") {
                    sliderRow(value: $profile.rangeKm, range: 5...80, unit: "км")
                }
                Section("Текущий заряд") {
                    sliderRow(value: $profile.batteryPercent, range: 0...100, unit: "%")
                    Text("Реальный запас сейчас: ~\(Int(profile.usableRangeKm)) км")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Мой самокат")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private func sliderRow(value: Binding<Double>, range: ClosedRange<Double>, unit: String) -> some View {
        VStack(spacing: 6) {
            Text("\(Int(value.wrappedValue)) \(unit)")
                .font(.title3.weight(.bold).monospacedDigit())
            Slider(value: value, in: range, step: 1)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ScooterSettingsView(profile: ScooterProfile())
}
