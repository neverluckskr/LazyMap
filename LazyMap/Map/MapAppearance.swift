import SwiftUI
import MapKit

/// Тип/стиль карты (#1 типы + #14 стили).
enum MapStyleChoice: String, CaseIterable, Identifiable {
    case standard   // обычная
    case muted      // приглушённая (минимал)
    case satellite  // спутник
    case hybrid     // гибрид (спутник + подписи)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard:  return "Обычная"
        case .muted:     return "Минимал"
        case .satellite: return "Спутник"
        case .hybrid:    return "Гибрид"
        }
    }

    var iconName: String {
        switch self {
        case .standard:  return "map"
        case .muted:     return "map.fill"
        case .satellite: return "globe.americas.fill"
        case .hybrid:    return "globe.americas"
        }
    }
}

/// Режим следования камеры за пользователем.
enum FollowMode: CaseIterable {
    case off        // свободная камера
    case northUp    // центр на мне, север сверху (#67-подобно)
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

/// Собирает итоговый MapStyle из выбора пользователя (#1, #2, #8, #14).
struct MapAppearance {
    var style: MapStyleChoice = .standard
    var show3D: Bool = false   // #2 3D-здания
    var showPOI: Bool = true   // #8 объекты на карте

    var resolvedStyle: MapStyle {
        let elevation: MapStyle.Elevation = show3D ? .realistic : .flat
        let poi: PointOfInterestCategories = showPOI ? .all : .excludingAll
        switch style {
        case .standard:
            return .standard(elevation: elevation, pointsOfInterest: poi)
        case .muted:
            return .standard(elevation: elevation, emphasis: .muted, pointsOfInterest: poi)
        case .satellite:
            return .imagery(elevation: elevation)
        case .hybrid:
            return .hybrid(elevation: elevation, pointsOfInterest: poi)
        }
    }
}
