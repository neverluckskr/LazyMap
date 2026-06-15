import SwiftUI
import MapKit
import UIKit

struct ContentView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var location: LocationManager
    @StateObject private var route = RouteService()
    @StateObject private var search = SearchService()
    @StateObject private var scooter = ScooterProfile()
    @StateObject private var trip = TripRecorder()
    @StateObject private var nearby = NearbyService()
    @StateObject private var battery = BatteryMonitor()

    @State private var camera: MapCameraPosition = .userLocation(
        fallback: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 55.751244, longitude: 37.618423), // Москва как дефолт
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
    )

    @State private var appearance = MapAppearance()
    @State private var followMode: FollowMode = .off
    @State private var tripStarted = false
    @State private var themeFlash = 0.0

    private var showingPreview: Bool {
        route.destination != nil && !tripStarted
    }

    private var accentColor: Color { theme.accent.color }

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                UserAnnotation()

                // Альтернативные маршруты — приглушённые.
                ForEach(Array(route.routes.enumerated()), id: \.offset) { idx, r in
                    if idx != route.selectedIndex {
                        MapPolyline(r.polyline)
                            .stroke(.gray.opacity(0.5),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                }
                if let sel = route.selectedRoute {
                    MapPolyline(sel.polyline)
                        .stroke(accentColor,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }

                // Места «рядом» (#59) — тапни маркер, чтобы построить маршрут.
                ForEach(nearby.items) { item in
                    Annotation(item.name, coordinate: item.coordinate) {
                        Button { selectNearby(item) } label: {
                            Image(systemName: item.category.icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(item.category.color, in: Circle())
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let dest = route.destination {
                    Annotation(route.destinationName ?? "Точка Б", coordinate: dest) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundStyle(.red)
                            .shadow(radius: 3)
                    }
                }
            }
            .mapStyle(appearance.resolvedStyle)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .gesture(longPressGesture(proxy))
            .ignoresSafeArea()
            .onMapCameraChange(frequency: .onEnd) { context in
                search.setRegion(context.region)
            }
        }
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) { bottomArea }
        .overlay {
            // #20 — мягкая вспышка при смене темы.
            Color.gray.opacity(themeFlash).ignoresSafeArea().allowsHitTesting(false)
        }
        .tint(accentColor) // #13 — акцентный цвет приложения
        .onAppear {
            location.start()
            route.scooterSpeedKmh = scooter.speedKmh
        }
        .onChange(of: location.updateTick) { _, _ in handleLocationUpdate() }
        .onChange(of: followMode) { _, _ in updateFollowCamera() }
        .onChange(of: route.fitTick) { _, _ in fitRoute() }
        .onChange(of: scooter.speedKmh) { _, v in route.scooterSpeedKmh = v }
        .onChange(of: tripStarted) { _, on in
            UIApplication.shared.isIdleTimerDisabled = on // #81 — не гасить экран в поездке
        }
        .onChange(of: theme.preference) { _, _ in
            themeFlash = 0.18
            withAnimation(.easeOut(duration: 0.45)) { themeFlash = 0 }
        }
    }

    // MARK: - Жест: зажать точку на карте

    private func longPressGesture(_ proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.6)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onEnded { value in
                if case .second(true, let drag?) = value,
                   let coord = proxy.convert(drag.location, from: .local) {
                    tripStarted = false
                    followMode = .off
                    nearby.clear()
                    route.setDestination(coord, name: nil, from: location.coordinate)
                }
            }
    }

    // MARK: - Верхняя панель

    private var topBar: some View {
        HStack(alignment: .top, spacing: 8) {
            SearchView(service: search) { item in handleSelect(item) }
            MapControlButton(systemName: theme.preference.iconName) {
                withAnimation { theme.cycle() }
            }
            mapStyleMenu
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var mapStyleMenu: some View {
        Menu {
            Picker("Тип карты", selection: $appearance.style) {
                ForEach(MapStyleChoice.allCases) { choice in
                    Label(choice.label, systemImage: choice.iconName).tag(choice)
                }
            }
            Toggle("Объекты (кафе, заправки…)", isOn: $appearance.showPOI)
            Picker("Акцент", selection: accentBinding) {
                ForEach(ThemeManager.Accent.allCases) { accent in
                    Label(accent.label, systemImage: "circle.fill").tag(accent)
                }
            }
        } label: {
            Image(systemName: "map")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 50, height: 50)
                .contentShape(.circle)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }

    private var accentBinding: Binding<ThemeManager.Accent> {
        Binding(get: { theme.accent }, set: { theme.accent = $0 })
    }

    // MARK: - Нижняя зона

    @ViewBuilder
    private var bottomArea: some View {
        if showingPreview {
            RoutePanel(
                route: route,
                profile: scooter,
                accent: accentColor,
                onStart: { withAnimation { tripStarted = true; followMode = .headingUp; trip.start(); updateFollowCamera() } },
                onCancel: { withAnimation { route.clear() } },
                onRecalculate: { if let c = location.coordinate { route.recalculate(from: c) } },
                onTransportChange: { mode in
                    route.transport = mode
                    if let c = location.coordinate { route.recalculate(from: c) }
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            VStack(spacing: 10) {
                if location.authorizationStatus == .denied || location.authorizationStatus == .restricted {
                    permissionBanner
                }
                if battery.isLow && !location.ecoMode {
                    lowBatteryBanner
                }
                if tripStarted {
                    tripStatsBar
                } else {
                    nearbyChips
                }
                HStack(alignment: .bottom) {
                    SpeedBadge(speedKmh: location.speedKmh)
                    Spacer()
                    if tripStarted { endTripButton } else { followButton }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    /// #59 — чипсы категорий «рядом».
    private var nearbyChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NearbyCategory.allCases) { cat in
                    Button { toggleNearby(cat) } label: {
                        Label(cat.label, systemImage: cat.icon)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)
                    .tint(nearby.active == cat ? cat.color : nil)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var tripStatsBar: some View {
        HStack(spacing: 0) {
            tripStat(trip.elapsedText, "время")
            Divider().frame(height: 30)
            tripStat(trip.distanceText, "путь")
            Divider().frame(height: 30)
            tripStat(String(format: "%.0f", trip.avgSpeedKmh), "ср. км/ч")
            Divider().frame(height: 30)
            tripStat(String(format: "%.0f", trip.maxSpeedKmh), "макс км/ч")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
    }

    private func tripStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var followButton: some View {
        MapControlButton(systemName: followMode.iconName) {
            withAnimation {
                followMode = followMode.next()
                if followMode == .off { centerOnUser() }
            }
        }
    }

    private var endTripButton: some View {
        Button {
            withAnimation { route.clear(); tripStarted = false; followMode = .off; trip.stop() }
        } label: {
            Label("Завершить", systemImage: "xmark")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .buttonStyle(.glassProminent)
        .tint(.red)
        .buttonBorderShape(.capsule)
    }

    private var permissionBanner: some View {
        Text("Геолокация выключена — включите её в Настройках, чтобы видеть позицию и скорость.")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding(12)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
    }

    /// #77 — предложение эконом-режима при низком заряде.
    private var lowBatteryBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "battery.25")
                .foregroundStyle(.red)
            Text("Низкий заряд (\(Int(battery.level * 100))%)")
                .font(.subheadline)
            Spacer()
            Button("Эконом") { withAnimation { location.ecoMode = true } }
                .buttonStyle(.glassProminent)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
    }

    // MARK: - Логика

    private func handleSelect(_ item: MKMapItem) {
        tripStarted = false
        followMode = .off
        nearby.clear()
        route.setDestination(item.placemark.coordinate, name: item.name, from: location.coordinate)
    }

    private func selectNearby(_ item: NearbyItem) {
        tripStarted = false
        followMode = .off
        route.setDestination(item.coordinate, name: item.name, from: location.coordinate)
        nearby.clear()
    }

    private func toggleNearby(_ cat: NearbyCategory) {
        nearby.toggle(cat, around: location.coordinate)
        if nearby.active != nil, let c = location.coordinate {
            followMode = .off
            withAnimation {
                camera = .region(MKCoordinateRegion(center: c, latitudinalMeters: 4000, longitudinalMeters: 4000))
            }
        }
    }

    private func handleLocationUpdate() {
        updateFollowCamera()

        if trip.isRecording {
            trip.update(speedKmh: location.speedKmh, coordinate: location.coordinate)
        }

        if tripStarted, !route.isCalculating, let c = location.coordinate, route.isOffRoute(c) {
            route.recalculate(from: c)
        }
    }

    private func updateFollowCamera() {
        guard followMode != .off, let coord = location.coordinate else { return }
        switch followMode {
        case .off:
            break
        case .northUp:
            camera = .camera(MapCamera(centerCoordinate: coord, distance: 1200, heading: 0, pitch: 0))
        case .headingUp:
            camera = .camera(MapCamera(
                centerCoordinate: coord,
                distance: distanceForSpeed(location.speedKmh),
                heading: location.course,
                pitch: 0
            ))
        }
    }

    private func distanceForSpeed(_ kmh: Double) -> Double {
        let clamped = min(max(kmh, 0), 60)
        return 300 + (clamped / 60) * 1500
    }

    private func fitRoute() {
        guard let rect = route.selectedRoute?.polyline.boundingMapRect else { return }
        let padded = rect.insetBy(dx: -rect.size.width * 0.25, dy: -rect.size.height * 0.25)
        followMode = .off
        withAnimation { camera = .rect(padded) }
    }

    private func centerOnUser() {
        if let coord = location.coordinate {
            camera = .region(
                MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        } else {
            location.start()
            camera = .userLocation(fallback: camera)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
        .environmentObject(LocationManager())
}
