import SwiftUI

/// Круглая кнопка-иконка для оверлеев поверх карты (тема, центрирование и т.д.).
/// Использует нативный стеклянный стиль кнопки (iOS 26) — он сам рисует Liquid Glass
/// и делает кликабельным весь круг.
struct MapControlButton: View {
    let systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 50, height: 50)
                .contentShape(.circle)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }
}

#Preview {
    MapControlButton(systemName: "location.fill") {}
        .padding()
}
