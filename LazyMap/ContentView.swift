import SwiftUI
import MapKit

struct ContentView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var location: LocationManager

    @State private var camera: MapCameraPosition = .userLocation(
        fallback: .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 55.751244, longitude: 37.618423), // Москва как дефолт
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
    )

    var body: some View {
        Map(position: $camera) {
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .flat))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) { themeButton }
        .overlay(alignment: .bottomTrailing) { recenterButton }
        .overlay(alignment: .bottomLeading) { speedBadge }
        .overlay(alignment: .top) { permissionBanner }
        .onAppear { location.start() }
    }

    // MARK: - Оверлеи

    private var themeButton: some View {
        MapControlButton(systemName: theme.preference.iconName) {
            withAnimation { theme.cycle() }
        }
        .padding(.top, 8)
        .padding(.trailing, 16)
    }

    private var recenterButton: some View {
        MapControlButton(systemName: "location.fill") {
            withAnimation {
                if let coord = location.coordinate {
                    camera = .region(
                        MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                } else {
                    // Нет фикса позиции — попросим систему и попробуем встать на пользователя.
                    location.start()
                    camera = .userLocation(fallback: camera)
                }
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 32)
    }

    private var speedBadge: some View {
        SpeedBadge(speedKmh: location.speedKmh)
            .padding(.leading, 16)
            .padding(.bottom, 32)
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
}

#Preview {
    ContentView()
        .environmentObject(ThemeManager())
        .environmentObject(LocationManager())
}
