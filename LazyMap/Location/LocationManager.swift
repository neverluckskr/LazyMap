import Foundation
import CoreLocation
import Combine

/// Обёртка над CoreLocation: даёт текущую позицию, скорость (км/ч) и статус доступа.
/// Запись пройденного пути добавим на следующем этапе.
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    /// Текущая координата пользователя (nil пока нет фикса).
    @Published var coordinate: CLLocationCoordinate2D?

    /// Текущая скорость в км/ч (0, если стоим или сигнал недостоверный).
    @Published var speedKmh: Double = 0

    /// Направление движения в градусах (для режима «карта по движению»).
    @Published var course: CLLocationDirection = 0

    /// Счётчик обновлений — удобно слушать через onChange (координата не Equatable).
    @Published var updateTick: Int = 0

    /// Статус разрешения на геолокацию.
    @Published var authorizationStatus: CLAuthorizationStatus

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
    }

    /// Запросить доступ и начать получать обновления.
    func start() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        coordinate = location.coordinate

        // location.speed в м/с; отрицательное значение = недостоверно.
        let speed = max(location.speed, 0)
        speedKmh = speed * 3.6

        // course = направление движения; -1 означает недостоверно.
        if location.course >= 0 { course = location.course }

        updateTick &+= 1
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Тихо игнорируем разовые ошибки (например, kCLErrorLocationUnknown).
    }
}
