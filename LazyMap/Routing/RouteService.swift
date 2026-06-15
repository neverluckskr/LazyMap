import Foundation
import MapKit
import Combine

/// Считает автомобильный маршрут от точки А (пользователь) до точки Б (зажатая на карте).
/// Даёт линию маршрута, расстояние и время в пути.
@MainActor
final class RouteService: ObservableObject {

    /// Точка назначения (точка Б). nil = маршрута нет.
    @Published var destination: CLLocationCoordinate2D?

    /// Построенный маршрут (линия + метаданные).
    @Published var route: MKRoute?

    /// Идёт расчёт маршрута.
    @Published var isCalculating = false

    /// Текст ошибки, если маршрут не удалось построить.
    @Published var errorMessage: String?

    /// Поставить точку Б и запустить расчёт от текущей позиции.
    func setDestination(_ coord: CLLocationCoordinate2D, from origin: CLLocationCoordinate2D?) {
        destination = coord
        route = nil
        errorMessage = nil

        guard let origin else {
            errorMessage = "Нет вашей позиции — включите геолокацию."
            return
        }
        calculate(from: origin, to: coord)
    }

    /// Сбросить маршрут.
    func clear() {
        destination = nil
        route = nil
        errorMessage = nil
        isCalculating = false
    }

    private func calculate(from origin: CLLocationCoordinate2D, to dest: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: dest))
        request.transportType = .automobile

        isCalculating = true
        let directions = MKDirections(request: request)

        Task {
            defer { isCalculating = false }
            do {
                let response = try await directions.calculate()
                route = response.routes.first
                if route == nil { errorMessage = "Маршрут не найден." }
            } catch {
                errorMessage = "Не удалось построить маршрут."
            }
        }
    }

    /// Расстояние строкой: "8.4 км" или "23 км".
    var distanceText: String? {
        guard let route else { return nil }
        let km = route.distance / 1000
        return km >= 10 ? String(format: "%.0f км", km) : String(format: "%.1f км", km)
    }

    /// Время в пути строкой: "12 мин" или "1 ч 30 мин".
    var durationText: String? {
        guard let route else { return nil }
        let minutes = Int((route.expectedTravelTime / 60).rounded())
        if minutes >= 60 {
            return "\(minutes / 60) ч \(minutes % 60) мин"
        }
        return "\(max(minutes, 1)) мин"
    }
}
