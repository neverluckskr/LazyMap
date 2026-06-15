import Foundation
import MapKit
import Combine

/// Считает автомобильный маршрут от точки А (пользователь) до точки Б.
/// Поддерживает альтернативные маршруты (#23), тип маршрута (#24),
/// ETA (#34) и проверку схода с пути (#35).
@MainActor
final class RouteService: ObservableObject {

    @Published var destination: CLLocationCoordinate2D?
    @Published var destinationName: String?

    /// Все найденные маршруты (первый — рекомендованный).
    @Published var routes: [MKRoute] = []
    /// Индекс выбранного маршрута.
    @Published var selectedIndex: Int = 0

    @Published var isCalculating = false
    @Published var errorMessage: String?

    // #24 — настройки маршрута
    @Published var avoidTolls = false
    @Published var avoidHighways = false

    /// Сигнал «вписать маршрут в экран» (растёт при новом расчёте/смене маршрута).
    @Published var fitTick = 0

    var selectedRoute: MKRoute? {
        routes.indices.contains(selectedIndex) ? routes[selectedIndex] : nil
    }

    func setDestination(_ coord: CLLocationCoordinate2D, name: String?, from origin: CLLocationCoordinate2D?) {
        destination = coord
        destinationName = name
        routes = []
        selectedIndex = 0
        errorMessage = nil

        guard let origin else {
            errorMessage = "Нет вашей позиции — включите геолокацию."
            return
        }
        calculate(from: origin, to: coord)
    }

    /// Пересчитать (смена настроек или сход с маршрута).
    func recalculate(from origin: CLLocationCoordinate2D) {
        guard let dest = destination else { return }
        calculate(from: origin, to: dest)
    }

    func clear() {
        destination = nil
        destinationName = nil
        routes = []
        selectedIndex = 0
        errorMessage = nil
        isCalculating = false
    }

    private func calculate(from origin: CLLocationCoordinate2D, to dest: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
        request.transportType = .automobile
        request.requestsAlternateRoutes = true                       // #23
        request.tollPreference = avoidTolls ? .avoid : .any          // #24
        request.highwayPreference = avoidHighways ? .avoid : .any    // #24

        isCalculating = true
        let directions = MKDirections(request: request)

        Task {
            defer { isCalculating = false }
            do {
                let response = try await directions.calculate()
                routes = response.routes
                selectedIndex = 0
                if routes.isEmpty {
                    errorMessage = "Маршрут не найден."
                } else {
                    fitTick &+= 1
                }
            } catch {
                errorMessage = "Не удалось построить маршрут."
            }
        }
    }

    /// #35 — съехал ли пользователь с выбранного маршрута дальше порога.
    func isOffRoute(_ coord: CLLocationCoordinate2D, threshold: CLLocationDistance = 60) -> Bool {
        guard let line = selectedRoute?.polyline else { return false }
        let user = MKMapPoint(coord)
        let points = line.points()
        var minDist = Double.greatestFiniteMagnitude
        for i in 0..<line.pointCount {
            minDist = min(minDist, user.distance(to: points[i]))
        }
        return minDist > threshold
    }

    // MARK: - Форматирование

    func distanceText(_ route: MKRoute) -> String {
        let km = route.distance / 1000
        return km >= 10 ? String(format: "%.0f км", km) : String(format: "%.1f км", km)
    }

    func durationText(_ route: MKRoute) -> String {
        let minutes = Int((route.expectedTravelTime / 60).rounded())
        if minutes >= 60 { return "\(minutes / 60) ч \(minutes % 60) мин" }
        return "\(max(minutes, 1)) мин"
    }

    /// #34 — время прибытия (во сколько приедешь).
    func arrivalText(_ route: MKRoute) -> String {
        let arrival = Date().addingTimeInterval(route.expectedTravelTime)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: arrival)
    }
}
