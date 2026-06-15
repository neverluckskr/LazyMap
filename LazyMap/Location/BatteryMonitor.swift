import UIKit
import Combine

/// Следит за зарядом телефона, чтобы предложить эконом-режим (#77).
@MainActor
final class BatteryMonitor: ObservableObject {
    @Published var level: Double = 1
    @Published var isCharging = false

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()

        let center = NotificationCenter.default
        center.addObserver(forName: UIDevice.batteryLevelDidChangeNotification,
                           object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        center.addObserver(forName: UIDevice.batteryStateDidChangeNotification,
                           object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    private func refresh() {
        let l = UIDevice.current.batteryLevel
        level = l < 0 ? 1 : Double(l)   // -1 на симуляторе = считаем полным
        let state = UIDevice.current.batteryState
        isCharging = (state == .charging || state == .full)
    }

    /// Низкий заряд и не на зарядке.
    var isLow: Bool { level < 0.2 && !isCharging }
}
