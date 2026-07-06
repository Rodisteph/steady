import SwiftUI

/// Données affichées sur la carte partageable.
struct ShareCardData {
    let weeklyTotal: Int
    let bestStreak: Int
    let habits: [Line]

    struct Line: Identifiable {
        let id = UUID()
        let name: String
        let count: Int   // validations sur 7 jours
    }
}

/// Belle carte visuelle « Ma semaine sur Steady » — rendue en image pour le partage.
struct ShareCardView: View {
    let data: ShareCardData

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            statBlock
            if !data.habits.isEmpty { habitsBlock }
            Spacer(minLength: 0)
            footer
        }
        .padding(28)
        .frame(width: 340, height: 480, alignment: .topLeading)
        .background(Color.accentGradient)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.white.opacity(0.18)).frame(width: 40, height: 40)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            Text("Steady")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
            Spacer()
        }
    }

    private var statBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ma semaine")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(data.weeklyTotal)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
                Text("validations")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
            }

            streakBadge
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
            Text("\(data.bestStreak) jours de série")
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color.white.opacity(0.18)))
        .padding(.top, 4)
    }

    private var habitsBlock: some View {
        VStack(spacing: 12) {
            ForEach(data.habits.prefix(4)) { line in
                ShareHabitRow(line: line)
            }
        }
    }

    private var footer: some View {
        Text("Mes habitudes, en douceur. — Steady")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.8))
    }
}

private struct ShareHabitRow: View {
    let line: ShareCardData.Line

    var body: some View {
        HStack(spacing: 10) {
            Text(line.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
            Spacer(minLength: 8)
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(i < line.count ? 0.95 : 0.25))
                        .frame(width: 7, height: 7)
                }
            }
            Text("\(line.count)/7")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(width: 32, alignment: .trailing)
        }
    }
}

#Preview {
    ShareCardView(data: .init(
        weeklyTotal: 18,
        bestStreak: 7,
        habits: [
            .init(name: "Méditer", count: 7),
            .init(name: "Lire 10 pages", count: 5),
            .init(name: "Boire de l'eau", count: 6),
            .init(name: "Courir", count: 3)
        ]
    ))
}
