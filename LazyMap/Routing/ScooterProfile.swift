import Foundation
import Combine

/// Настройки самоката для углублённого расчёта (#36): скорость, запас хода, заряд.
/// Сохраняется между запусками.
final class ScooterProfile: ObservableObject {

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
        speedKmh = defaults.object(forKey: Keys.speed) as? Double ?? 20        // крейсерская скорость
        rangeKm = defaults.object(forKey: Keys.range) as? Double ?? 30          // запас хода на полном заряде
        batteryPercent = defaults.object(forKey: Keys.battery) as? Double ?? 100 // текущий заряд
    }

    /// Реальный запас хода с учётом текущего заряда (км).
    var usableRangeKm: Double { rangeKm * batteryPercent / 100 }

    /// Хватит ли заряда на дистанцию.
    func isEnough(forKm km: Double) -> Bool { usableRangeKm >= km }

    /// Сколько процентов заряда уйдёт на дистанцию.
    func batteryCost(forKm km: Double) -> Double {
        guard rangeKm > 0 else { return 0 }
        return min(km / rangeKm * 100, 100)
    }
}
