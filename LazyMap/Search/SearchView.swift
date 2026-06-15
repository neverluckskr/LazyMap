import SwiftUI
import MapKit

/// Стеклянное поле поиска + выпадающий список подсказок (#21, #22).
struct SearchView: View {
    @ObservedObject var service: SearchService
    @FocusState private var focused: Bool
    var onSelect: (MKMapItem) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Куда едем?", text: $service.query)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                if !service.query.isEmpty {
                    Button { service.clear() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .glassEffect(.regular, in: Capsule())

            if focused && !service.results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(service.results.prefix(6).enumerated()), id: \.offset) { _, item in
                        Button { select(item) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                if !item.subtitle.isEmpty {
                                    Text(item.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().opacity(0.3)
                    }
                }
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }

    private func select(_ completion: MKLocalSearchCompletion) {
        focused = false
        Task {
            if let item = await service.resolve(completion) {
                onSelect(item)
            }
            service.clear()
        }
    }
}
