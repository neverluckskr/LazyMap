import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var location: LocationManager
    @StateObject private var route = RouteService()

    @State private var camera: MapCameraPosition = .userLocation(
        fallback: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 55.751244, longitude: 37.618423), // Москва как дефолт
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
    )

    /// Внешний вид карты (тип, 3D, POI).
    @State private var appearance = MapAppearance()

    /// Режим следования камеры за пользователем.
    @State private var followMode: FollowMode = .off

    /// Поездка начата (панель предпросмотра скрыта, показываем спидометр).
    @State private var tripStarted = false

    private var showingPreview: Bool {
        route.destination != nil && !tripStarted
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                UserAnnotation()

                if let dest = route.destination {
                    Annotation("Точка Б", coordinate: dest) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundStyle(.red)
                            .shadow(radius: 3)
                    }
                }

                if let line = route.route {
                    MapPolyline(line.polyline)
                        .stroke(.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }
            }
            .mapStyle(appearance.resolvedStyle)
            .mapControls {
                MapCompass()       // #4 — сброс на север
                MapScaleView()
            }
            .gesture(longPressGesture(proxy))
            .ignoresSafeArea()
        }
        .overlay(alignment: .topTrailing) { topControls }
        .overlay(alignment: .top) { permissionBanner }
        .overlay(alignment: .bottom) { bottomArea }
        .onAppear { location.start() }
        // Двигаем камеру при каждом обновлении GPS, если включён режим следования.
        .onChange(of: location.updateTick) { _, _ in updateFollowCamera() }
        .onChange(of: followMode) { _, _ in updateFollowCamera() }
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
                    route.setDestination(coord, from: location.coordinate)
                }
            }
    }

    // MARK: - Верхние кнопки (тема + стиль карты)

    private var topControls: some View {
        VStack(spacing: 12) {
            MapControlButton(systemName: theme.preference.iconName) {
                withAnimation { theme.cycle() }
            }
            mapStyleMenu
        }
        .padding(.top, 8)
        .padding(.trailing, 16)
    }

    /// Меню выбора типа карты, 3D и POI (#1, #2, #8, #14).
    private var mapStyleMenu: some View {
        Menu {
            Picker("Тип карты", selection: $appearance.style) {
                ForEach(MapStyleChoice.allCases) { choice in
                    Label(choice.label, systemImage: choice.iconName).tag(choice)
                }
            }
            Toggle("3D-здания", isOn: $appearance.show3D)
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
                distanceText: route.distanceText,
                durationText: route.durationText,
                isCalculating: route.isCalculating,
                errorMessage: route.errorMessage,
                onStart: { withAnimation { tripStarted = true } },
                onCancel: { withAnimation { route.clear() } }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            HStack(alignment: .bottom) {
                SpeedBadge(speedKmh: location.speedKmh)
                Spacer()
                if tripStarted {
                    endTripButton
                } else {
                    followButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    /// Кнопка режима следования: off → север сверху → по движению (#5, #6).
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
            withAnimation { route.clear(); tripStarted = false }
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

    @ViewBuilder
    private var permissionBanner: some View {
        if location.authorizationStatus == .denied || location.authorizationStatus == .restricted {
            Text("Геолокация выключена — включите её в Настройках, чтобы видеть позицию и скорость.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding(12)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
                .padding(.top, 8)
        }
    }

    // MARK: - Камера

    /// Обновляет камеру в режиме следования (вызывается на каждый GPS-тик).
    private func updateFollowCamera() {
        guard followMode != .off, let coord = location.coordinate else { return }
        switch followMode {
        case .off:
            break
        case .northUp:
            camera = .camera(MapCamera(centerCoordinate: coord, distance: 1200, heading: 0, pitch: 0))
        case .headingUp:
            // #5 поворот по движению + #6 авто-зум по скорости.
            camera = .camera(MapCamera(
                centerCoordinate: coord,
                distance: distanceForSpeed(location.speedKmh),
                heading: location.course,
                pitch: appearance.show3D ? 45 : 0
            ))
        }
    }

    /// #6 — авто-зум: медленно → ближе, быстро → дальше.
    private func distanceForSpeed(_ kmh: Double) -> Double {
        let clamped = min(max(kmh, 0), 60)
        return 300 + (clamped / 60) * 1500   // 300 м (стоим) → 1800 м (60+ км/ч)
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
