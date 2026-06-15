import SwiftUI

/// Круглая кнопка-иконка для оверлеев поверх карты (тема, центрирование и т.д.).
/// Нативный Liquid Glass (iOS 26): интерактивное стекло реагирует на нажатие.
struct MapControlButton: View {
    let systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 50, height: 50)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MapControlButton(systemName: "location.fill") {}
        .padding()
}
