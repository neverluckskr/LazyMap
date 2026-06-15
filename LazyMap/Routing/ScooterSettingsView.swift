import SwiftUI

/// Настройки самоката: модель, крейсерская скорость, запас хода, текущий заряд.
struct ScooterSettingsView: View {
    @ObservedObject var profile: ScooterProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Мой самокат") {
                    LabeledContent("Модель", value: profile.model.name)
                    LabeledContent("Макс. скорость", value: "\(Int(profile.model.maxSpeedKmh)) км/ч")
                    LabeledContent("Запас хода", value: "до \(Int(profile.model.rangeKm)) км")
                    LabeledContent("Мотор", value: profile.model.motor)
                    LabeledContent("Батарея", value: profile.model.battery)
                    LabeledContent("Колёса", value: profile.model.wheels)
                    LabeledContent("Макс. нагрузка", value: "\(profile.model.maxLoadKg) кг")
                }

                Section("Крейсерская скорость") {
                    sliderRow(value: $profile.speedKmh, range: 5...profile.model.maxSpeedKmh, unit: "км/ч")
                    Text("Для расчёта времени в пути. Не максимум, а комфортная скорость езды.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Запас хода (полный заряд)") {
                    sliderRow(value: $profile.rangeKm, range: 10...100, unit: "км")
                }

                Section("Текущий заряд") {
                    sliderRow(value: $profile.batteryPercent, range: 0...100, unit: "%")
                    LabeledContent("Реальный запас сейчас", value: "~\(Int(profile.usableRangeKm)) км")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Реальный пробег ~85% от паспортного — учитываем вес, рельеф и ветер.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Сбросить под \(profile.model.name)") {
                        withAnimation { profile.resetToModel() }
                    }
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
