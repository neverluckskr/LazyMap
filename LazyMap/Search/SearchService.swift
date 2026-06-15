import Foundation
import MapKit
import Combine

/// Поиск адресов/мест с автодополнением (#21, #22).
@MainActor
final class SearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {

    /// Текст запроса (привязан к полю поиска).
    @Published var query: String = "" {
        didSet { completer.queryFragment = query }
    }

    /// Подсказки автодополнения.
    @Published var results: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Привязать поиск к видимой области (релевантнее результаты рядом).
    func setRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }

    func clear() {
        query = ""
        results = []
    }

    /// Превратить выбранную подсказку в конкретную точку на карте.
    func resolve(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        return try? await MKLocalSearch(request: request).start().mapItems.first
    }

    // MARK: - MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let res = completer.results
        Task { @MainActor in self.results = res }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.results = [] }
    }
}
