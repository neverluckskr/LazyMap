import SwiftUI
import MapKit

/// Одно место (POI) для отрисовки своим маркером.
struct POIItem: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let category: MKPointOfInterestCategory?

    init?(mapItem: MKMapItem) {
        guard let name = mapItem.name else { return nil }
        self.name = name
        self.coordinate = mapItem.placemark.coordinate
        self.category = mapItem.pointOfInterestCategory
    }

    var iconName: String {
        switch category {
        case .restaurant:      return "fork.knife"
        case .cafe:            return "cup.and.saucer.fill"
        case .bakery:          return "birthday.cake.fill"
        case .gasStation:      return "fuelpump.fill"
        case .evCharger:       return "bolt.car.fill"
        case .pharmacy:        return "cross.case.fill"
        case .store:           return "bag.fill"
        case .parking:         return "parkingsign"
        case .atm, .bank:      return "banknote.fill"
        case .publicTransport: return "bus.fill"
        default:               return "mappin"
        }
    }

    var color: Color {
        switch category {
        case .restaurant:      return .orange
        case .cafe, .bakery:   return .brown
        case .gasStation:      return .green
        case .evCharger:       return .mint
        case .pharmacy:        return .red
        case .store:           return .purple
        case .parking:         return .blue
        case .atm, .bank:      return .indigo
        case .publicTransport: return .teal
        default:               return .gray
        }
    }
}

/// Грузит ближайшие места в видимой области и отдаёт их как маркеры (#8).
/// Так POI видны с раннего зума, а не только когда упрёшься в здание.
@MainActor
final class POIService: ObservableObject {
    @Published var items: [POIItem] = []

    private var searchTask: Task<Void, Never>?

    /// Категории, которые показываем.
    private static let categories: [MKPointOfInterestCategory] = [
        .restaurant, .cafe, .bakery, .gasStation, .evCharger,
        .pharmacy, .store, .parking, .atm, .publicTransport
    ]

    /// Обновить метки под видимую область карты.
    func update(for region: MKCoordinateRegion, enabled: Bool) {
        searchTask?.cancel()

        guard enabled else { items = []; return }
        // Слишком далеко — не грузим, иначе каша из тысяч точек.
        guard region.span.latitudeDelta < 0.15 else { items = []; return }

        searchTask = Task {
            let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: Self.categories)
            let search = MKLocalSearch(request: request)
            do {
                let response = try await search.start()
                if Task.isCancelled { return }
                items = response.mapItems.prefix(40).compactMap { POIItem(mapItem: $0) }
            } catch {
                // тихо игнорируем (в т.ч. отмену запроса)
            }
        }
    }
}
