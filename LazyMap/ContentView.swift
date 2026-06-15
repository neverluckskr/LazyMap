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

    /// Поездка начата (панель предпросмотра скрыта, показываем спидометр).
    @State private var tripStarted = false

    /// Показывать панель предпросмотра маршрута?
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
            .mapStyle(.standard(elevation: .flat))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .gesture(longPressGesture(proxy))
            .ignoresSafeArea()
        }
        .overlay(alignment: .topTrailing) { themeButton }
        .overlay(alignment: .top) { permissionBanner }
        .overlay(alignment: .bottom) { bottomArea }
        .onAppear { location.start() }
    }

    // MARK: - Жест: зажать точку на карте

    private func longPressGesture(_ proxy: MapProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.6)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onEnded { value in
                if case .second(true, let drag?) = value,
                   let coord = proxy.convert(drag.location, from: .local) {
                    tripStarted = false
                    route.setDestination(coord, from: location.coordinate)
                }
            }
    }

    // MARK: - Оверлеи

    private var themeButton: some View {
        MapControlButton(systemName: theme.preference.iconName) {
            withAnimation { theme.cycle() }
        }
        .padding(.top, 8)
        .padding(.trailing, 16)
    }

    /// Нижняя зона: либо панель маршрута, либо спидометр + кнопки.
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
                    recenterButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    private var recenterButton: some View {
        MapControlButton(systemName: "location.fill") {
            withAnimation { centerOnUser() }
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

    // MARK: - Помощники

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
