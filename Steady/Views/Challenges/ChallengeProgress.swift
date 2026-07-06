import SwiftUI

/// Barre de progression d'un défi (composant réutilisable).
struct ChallengeProgress: View {
    let progress: Int
    let target: Int
    let tint: Color

    private var ratio: Double { target > 0 ? min(Double(progress) / Double(target), 1) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule().fill(tint).frame(width: max(10, geo.size.width * ratio))
                }
            }
            .frame(height: 10)

            HStack {
                Text("\(progress)/\(target)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                Spacer()
                Text("\(Int(ratio * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
    }
}
