import SwiftUI

/// Плашка-спидометр: крупная цифра км/ч с цветом по скорости (#40).
struct SpeedBadge: View {
    let speedKmh: Double

    /// #40 — цвет по скорости.
    private var speedColor: Color {
        switch speedKmh {
        case ..<25:  return .green
        case ..<45:  return .yellow
        case ..<80:  return .orange
        default:     return .red
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(speedKmh.rounded()))")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(speedColor)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.25), value: speedKmh)
            Text("км/ч")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 88, height: 88)
        .glassEffect(.regular, in: .circle)
        .overlay(
            Circle().stroke(speedColor.opacity(0.6), lineWidth: 3)
                .animation(.easeOut(duration: 0.25), value: speedKmh)
        )
    }
}

#Preview {
    HStack {
        SpeedBadge(speedKmh: 18)
        SpeedBadge(speedKmh: 55)
        SpeedBadge(speedKmh: 95)
    }
    .padding()
}
