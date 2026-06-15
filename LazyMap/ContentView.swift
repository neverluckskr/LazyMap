import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var location: LocationManager
    @StateObject private var route = RouteService()
    @StateObject private var search = SearchService()
    @StateObject private var scooter = ScooterProfile()

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

    private var showingPreview: Bool {
        route.destination != nil && !tripStarted
    }

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
                // Выбранный маршрут — поверх, синим.
                if let sel = route.selectedRoute {
                    MapPolyline(sel.polyline)
                        .stroke(.blue,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
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
                MapCompass()       // #4 — сброс на север
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
        .onAppear {
            location.start()
            route.scooterSpeedKmh = scooter.speedKmh
        }
        .onChange(of: location.updateTick) { _, _ in handleLocationUpdate() }
        .onChange(of: followMode) { _, _ in updateFollowCamera() }
        .onChange(of: route.fitTick) { _, _ in fitRoute() }
        .onChange(of: scooter.speedKmh) { _, v in route.scooterSpeedKmh = v }
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
                    route.setDestination(coord, name: nil, from: location.coordinate)
                }
            }
    }

    // MARK: - Верхняя панель: поиск + тема + стиль

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
        } label: {
            Image(systemName: "map")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 50, height: 50)
                .contentShape(.circle)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }

    // MARK: - Нижняя зона

    @ViewBuilder
    private var bottomArea: some View {
        if showingPreview {
            RoutePanel(
                route: route,
                profile: scooter,
                onStart: { withAnimation { tripStarted = true; followMode = .headingUp; updateFollowCamera() } },
                onCancel: { withAnimation { route.clear() } },
                onRecalculate: { if let c = location.coordinate { route.recalculate(from: c) } },
                onTransportChange: { mode in
                    route.transport = mode
                    if let c = location.coordinate { route.recalculate(from: c) }
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            VStack(spacing: 8) {
                if location.authorizationStatus == .denied || location.authorizationStatus == .restricted {
                    permissionBanner
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
            withAnimation { route.clear(); tripStarted = false; followMode = .off }
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

    // MARK: - Логика

    private func handleSelect(_ item: MKMapItem) {
        tripStarted = false
        followMode = .off
        route.setDestination(item.placemark.coordinate, name: item.name, from: location.coordinate)
    }

    private func handleLocationUpdate() {
        updateFollowCamera()
        // #35 — пересчёт при сходе с маршрута во время поездки.
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

    /// #38-подобно — вписать выбранный маршрут в экран.
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
