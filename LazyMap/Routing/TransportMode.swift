import MapKit

/// Режим передвижения (#36). Самокат — основной, остальные попроще.
enum TransportMode: String, CaseIterable, Identifiable {
    case scooter     // электросамокат (основной)
    case car         // машина
    case pedestrian  // пешком
    case bus         // автобус / транспорт

    var id: String { rawValue }

    var label: String {
        switch self {
        case .scooter:    return "Самокат"
        case .car:        return "Машина"
        case .pedestrian: return "Пешком"
        case .bus:        return "Автобус"
        }
    }

    var iconName: String {
        switch self {
        case .scooter:    return "scooter"
        case .car:        return "car.fill"
        case .pedestrian: return "figure.walk"
        case .bus:        return "bus.fill"
        }
    }

    /// Чем строим путь в MapKit. Самокат едет по дорожкам/тротуарам → walking.
    var mkType: MKDirectionsTransportType {
        switch self {
        case .scooter, .pedestrian: return .walking
        case .car:                  return .automobile
        case .bus:                  return .transit
        }
    }

    /// Самокат: время считаем по своей скорости, а не пешеходное из MapKit.
    var usesCustomSpeed: Bool { self == .scooter }
}
