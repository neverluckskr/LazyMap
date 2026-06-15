import SwiftUI
import MapKit

/// Категория «найти рядом» (#59).
enum NearbyCategory: String, CaseIterable, Identifiable {
    case food, gas, charging, parking, pharmacy, store

    var id: String { rawValue }

    var label: String {
        switch self {
        case .food:     return "Еда"
        case .gas:      return "Заправки"
        case .charging: return "Зарядки"
        case .parking:  return "Парковки"
        case .pharmacy: return "Аптеки"
        case .store:    return "Магазины"
        }
    }

    var icon: String {
        switch self {
        case .food:     return "fork.knife"
        case .gas:      return "fuelpump.fill"
        case .charging: return "bolt.car.fill"
        case .parking:  return "parkingsign"
        case .pharmacy: return "cross.case.fill"
        case .store:    return "bag.fill"
        }
    }

    var color: Color {
        switch self {
        case .food:     return .orange
        case .gas:      return .green
        case .charging: return .mint
        case .parking:  return .blue
        case .pharmacy: return .red
        case .store:    return .purple
        }
    }

    var categories: [MKPointOfInterestCategory] {
        switch self {
        case .food:     return [.restaurant, .cafe, .bakery]
        case .gas:      return [.gasStation]
        case .charging: return [.evCharger]
        case .parking:  return [.parking]
        case .pharmacy: return [.pharmacy]
        case .store:    return [.store, .foodMarket]
        }
    }
}

struct NearbyItem: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let category: NearbyCategory
}

/// Ищет места выбранной категории рядом и отдаёт их маркерами (#59).
@MainActor
final class NearbyService: ObservableObject {
    @Published var items: [NearbyItem] = []
    @Published var active: NearbyCategory?

    private var task: Task<Void, Never>?

    /// Тап по категории: повторный тап выключает её.
    func toggle(_ category: NearbyCategory, around center: CLLocationCoordinate2D?) {
        if active == category { clear(); return }
        guard let center else { return }
        search(category, around: center)
    }

    func search(_ category: NearbyCategory, around center: CLLocationCoordinate2D) {
        active = category
        task?.cancel()
        task = Task {
            let request = MKLocalPointsOfInterestRequest(center: center, radius: 3000)
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: category.categories)
            do {
                let response = try await MKLocalSearch(request: request).start()
                if Task.isCancelled { return }
                items = response.mapItems.prefix(25).compactMap { item in
                    guard let name = item.name else { return nil }
                    return NearbyItem(name: name, coordinate: item.placemark.coordinate, category: category)
                }
            } catch {
                items = []
            }
        }
    }

    func clear() {
        active = nil
        items = []
        task?.cancel()
    }
}
