import SwiftUI
import MapKit

/// Тип карты (#1).
enum MapStyleChoice: String, CaseIterable, Identifiable {
    case standard   // обычная
    case satellite  // спутник

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard:  return "Обычная"
        case .satellite: return "Спутник"
        }
    }

    var iconName: String {
        switch self {
        case .standard:  return "map"
        case .satellite: return "globe.americas.fill"
        }
    }
}

/// Режим следования камеры за пользователем.
enum FollowMode: CaseIterable {
    case off        // свободная камера
    case northUp    // центр на мне, север сверху
    case headingUp  // карта поворачивается по движению (#5) + авто-зум (#6)

    var iconName: String {
        switch self {
        case .off:       return "location"
        case .northUp:   return "location.fill"
        case .headingUp: return "location.north.line.fill"
        }
    }

    func next() -> FollowMode {
        switch self {
        case .off:       return .northUp
        case .northUp:   return .headingUp
        case .headingUp: return .off
        }
    }
}

/// Собирает итоговый MapStyle с системными метками Apple MapKit (#8).
struct MapAppearance {
    var style: MapStyleChoice = .standard
    var showPOI: Bool = true   // #8 объекты на карте (системные метки)

    var resolvedStyle: MapStyle {
        let poi: PointOfInterestCategories = showPOI ? .all : .excludingAll
        switch style {
        case .standard:
            return .standard(elevation: .flat, pointsOfInterest: poi)
        case .satellite:
            return .imagery(elevation: .flat)
        }
    }
}
