import Foundation
import Combine

/// Паспортные данные конкретной модели самоката.
struct ScooterModel {
    let name: String
    let maxSpeedKmh: Double
    let rangeKm: Double
    let motor: String
    let battery: String
    let wheels: String
    let maxLoadKg: Int

    /// Kugoo Kirin G2 Master (2026).
    static let g2master = ScooterModel(
        name: "Kugoo Kirin G2 Master",
        maxSpeedKmh: 60,
        rangeKm: 70,
        motor: "2× 1000 Вт (2000 Вт)",
        battery: "52 В · 20.8 А·ч (~1080 Вт·ч)",
        wheels: "10\" пневматические",
        maxLoadKg: 120
    )

    /// Рекомендуемая крейсерская скорость (комфортная городская, не максимум).
    var cruiseKmh: Double { 32 }
}

/// Настройки самоката для углублённого расчёта (#36): скорость, запас хода, заряд.
/// Сохраняется между запусками. По умолчанию подогнано под Kugoo Kirin G2 Master.
final class ScooterProfile: ObservableObject {

    /// Модель самоката (паспортные данные).
    let model = ScooterModel.g2master

    @Published var speedKmh: Double      { didSet { defaults.set(speedKmh, forKey: Keys.speed) } }
    @Published var rangeKm: Double       { didSet { defaults.set(rangeKm, forKey: Keys.range) } }
    @Published var batteryPercent: Double { didSet { defaults.set(batteryPercent, forKey: Keys.battery) } }

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let speed = "scooterSpeed"
        static let range = "scooterRange"
        static let battery = "scooterBattery"
    }

    init() {
        // Дефолты под Kugoo Kirin G2 Master: крейсер 32 км/ч, запас 70 км.
        speedKmh = defaults.object(forKey: Keys.speed) as? Double ?? ScooterModel.g2master.cruiseKmh
        rangeKm = defaults.object(forKey: Keys.range) as? Double ?? ScooterModel.g2master.rangeKm
        batteryPercent = defaults.object(forKey: Keys.battery) as? Double ?? 100
    }

    /// Сбросить настройки под паспорт модели.
    func resetToModel() {
        speedKmh = model.cruiseKmh
        rangeKm = model.rangeKm
    }

    /// Реальный пробег обычно меньше паспортного (вес, рельеф, ветер, режим).
    private let realismFactor = 0.85

    /// Реальный запас хода с учётом текущего заряда (км).
    var usableRangeKm: Double { rangeKm * realismFactor * batteryPercent / 100 }

    /// Хватит ли заряда на дистанцию.
    func isEnough(forKm km: Double) -> Bool { usableRangeKm >= km }

    /// Сколько процентов заряда уйдёт на дистанцию.
    func batteryCost(forKm km: Double) -> Double {
        let fullRealRange = rangeKm * realismFactor
        guard fullRealRange > 0 else { return 0 }
        return min(km / fullRealRange * 100, 100)
    }
}
