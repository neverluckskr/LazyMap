import SwiftUI

/// Плашка-спидометр: крупная цифра км/ч.
struct SpeedBadge: View {
    let speedKmh: Double

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(speedKmh.rounded()))")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.25), value: speedKmh)
            Text("км/ч")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 88, height: 88)
        .glassEffect(.regular, in: .circle)
    }
}

#Preview {
    SpeedBadge(speedKmh: 67)
        .padding()
}
