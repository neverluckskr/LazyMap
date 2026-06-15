import SwiftUI
import MapKit

/// Нижняя панель маршрута (как в Waze): ETA, альтернативы, настройки, шаги.
struct RoutePanel: View {
    @ObservedObject var route: RouteService
    @ObservedObject var profile: ScooterProfile
    var accent: Color = .blue
    var onStart: () -> Void
    var onCancel: () -> Void
    var onRecalculate: () -> Void
    var onTransportChange: (TransportMode) -> Void

    @State private var expanded = false
    @State private var showingScooterSettings = false

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 40, height: 5)

            if route.isCalculating {
                ProgressView("Строю маршрут…").padding(.vertical, 8)
            } else if let err = route.errorMessage {
                Text(err)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Закрыть", action: onCancel).buttonStyle(.glass)
            } else if let sel = route.selectedRoute {
                content(sel)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height < -30 { withAnimation { expanded = true } }
                    else if value.translation.height > 30 { withAnimation { expanded = false } }
                }
        )
        .sheet(isPresented: $showingScooterSettings) {
            ScooterSettingsView(profile: profile)
                .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private func content(_ sel: MKRoute) -> some View {
        if let name = route.destinationName {
            Text(name).font(.headline).lineLimit(1)
        }

        // Режим транспорта (#36)
        transportSelector

        // Углублённая инфа по самокату (#36)
        if route.transport == .scooter {
            scooterCard(sel)
        }

        // Время · расстояние · прибытие (#34)
        HStack(spacing: 20) {
            stat(route.durationText(sel), "в пути")
            Divider().frame(height: 36)
            stat(route.distanceText(sel), "путь")
            Divider().frame(height: 36)
            stat(route.arrivalText(sel), "прибытие")
        }

        // Альтернативные маршруты (#23)
        if route.routes.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(route.routes.enumerated()), id: \.offset) { idx, r in
                        Button {
                            withAnimation { route.selectedIndex = idx; route.fitTick &+= 1 }
                        } label: {
                            Text("\(route.durationText(r)) · \(route.distanceText(r))")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.glass)
                        .tint(idx == route.selectedIndex ? accent : nil)
                    }
                }
            }
        }

        // Тип маршрута (#24)
        HStack(spacing: 8) {
            prefToggle("Без платных", isOn: route.avoidTolls) {
                route.avoidTolls.toggle(); onRecalculate()
            }
            prefToggle("Без шоссе", isOn: route.avoidHighways) {
                route.avoidHighways.toggle(); onRecalculate()
            }
            Spacer()
            Image(systemName: expanded ? "chevron.down" : "chevron.up")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        // Пошаговый список (#64) — по свайпу вверх
        if expanded {
            stepsList(sel)
        }

        // Действия
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Text("Отмена").frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.glass)

            Button(action: onStart) {
                Label("Начать поездку", systemImage: "location.north.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(accent)
        }
    }

    /// Переключатель транспорта (#36).
    private var transportSelector: some View {
        HStack(spacing: 8) {
            ForEach(TransportMode.allCases) { mode in
                Button {
                    onTransportChange(mode)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: mode.iconName).font(.system(size: 16, weight: .semibold))
                        Text(mode.label).font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.glass)
                .tint(route.transport == mode ? .blue : nil)
            }
        }
    }

    /// Самокатная карточка: запас хода и расход заряда (#36).
    private func scooterCard(_ sel: MKRoute) -> some View {
        let km = sel.distance / 1000
        let enough = profile.isEnough(forKm: km)
        let cost = profile.batteryCost(forKm: km)
        return HStack(spacing: 12) {
            Image(systemName: enough ? "bolt.fill" : "bolt.slash.fill")
                .font(.title3)
                .foregroundStyle(enough ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(enough ? "Заряда хватит" : "Заряда может не хватить")
                    .font(.subheadline.weight(.semibold))
                Text("Запас ~\(Int(profile.usableRangeKm)) км · потратишь ~\(Int(cost))% · заряд \(Int(profile.batteryPercent))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { showingScooterSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .contentShape(.circle)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
        .padding(12)
        .glassEffect(enough ? Glass.regular : Glass.regular.tint(.red.opacity(0.25)),
                     in: RoundedRectangle(cornerRadius: 18))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func prefToggle(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: isOn ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glass)
        .tint(isOn ? accent : nil)
    }

    @ViewBuilder
    private func stepsList(_ sel: MKRoute) -> some View {
        let steps = sel.steps.filter { !$0.instructions.isEmpty }
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.turn.up.right")
                            .font(.caption)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.instructions).font(.subheadline)
                            if step.distance > 0 {
                                Text(formatMeters(step.distance))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 220)
    }

    private func formatMeters(_ m: CLLocationDistance) -> String {
        m >= 1000 ? String(format: "%.1f км", m / 1000) : "\(Int(m)) м"
    }
}
