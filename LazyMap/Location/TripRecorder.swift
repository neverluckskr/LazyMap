import Foundation
import CoreLocation
import Combine

/// Считает статистику поездки: время, средняя/макс скорость, дистанция (#43, #44, #46).
@MainActor
final class TripRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var maxSpeedKmh: Double = 0
    @Published var distanceM: Double = 0
    @Published var movingTime: TimeInterval = 0
    @Published var elapsed: TimeInterval = 0

    private var startDate: Date?
    private var lastUpdate: Date?
    private var lastCoord: CLLocationCoordinate2D?

    func start() {
        isRecording = true
        maxSpeedKmh = 0
        distanceM = 0
        movingTime = 0
        elapsed = 0
        startDate = Date()
        lastUpdate = Date()
        lastCoord = nil
    }

    func stop() {
        isRecording = false
    }

    /// Вызывается на каждом обновлении GPS во время поездки.
    func update(speedKmh: Double, coordinate: CLLocationCoordinate2D?) {
        guard isRecording, let start = startDate else { return }
        let now = Date()
        let dt = now.timeIntervalSince(lastUpdate ?? now)

        if speedKmh > 1 { movingTime += dt }            // время в движении (#46)
        maxSpeedKmh = max(maxSpeedKmh, speedKmh)         // макс (#44)

        if let last = lastCoord, let c = coordinate {
            distanceM += CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
        }
        if let c = coordinate { lastCoord = c }

        lastUpdate = now
        elapsed = now.timeIntervalSince(start)
    }

    /// Средняя скорость по времени в движении (#43).
    var avgSpeedKmh: Double {
        movingTime > 0 ? (distanceM / movingTime) * 3.6 : 0
    }

    var elapsedText: String { Self.timeString(elapsed) }

    var distanceText: String {
        distanceM >= 1000 ? String(format: "%.1f км", distanceM / 1000) : "\(Int(distanceM)) м"
    }

    static func timeString(_ t: TimeInterval) -> String {
        let s = Int(t)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}
