import SwiftUI
import WatchKit

struct WatchHomeView: View {
    @State private var sync = WatchSyncService.shared

    private var total: Int { sync.habits.count }
    private var done: Int { sync.habits.filter { $0.completed }.count }

    var body: some View {
        NavigationStack {
            Group {
                if sync.habits.isEmpty {
                    placeholder
                } else {
                    List {
                        progressHeader
                            .listRowBackground(Color.clear)
                        ForEach(sync.habits) { habit in
                            Button {
                                WKInterfaceDevice.current().play(.click)
                                sync.toggle(habit.id)
                            } label: {
                                row(habit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Steady")
            .onAppear {
                sync.start()
                sync.refresh()
            }
        }
        .tint(.green)
    }

    // MARK: - Sous-vues

    private var progressHeader: some View {
        HStack {
            ZStack {
                Circle().stroke(Color.green.opacity(0.2), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: total == 0 ? 0 : CGFloat(done) / CGFloat(total))
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: done)
                Text("\(done)/\(total)")
                    .font(.caption2.weight(.bold))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 1) {
                Text("Aujourd'hui").font(.headline)
                Text(done == total && total > 0 ? "Tout est validé 🎉" : "\(done) sur \(total)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func row(_ habit: WatchHabitDTO) -> some View {
        HStack(spacing: 10) {
            Image(systemName: habit.icon)
                .font(.body)
                .foregroundStyle(habit.completed ? .black : .green)
                .frame(width: 30, height: 30)
                .background(Circle().fill(habit.completed ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.green.opacity(0.18))))

            VStack(alignment: .leading, spacing: 1) {
                Text(habit.name)
                    .font(.body)
                    .lineLimit(1)
                if habit.streak > 0 {
                    Label("\(habit.streak) j", systemImage: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Image(systemName: habit.completed ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(habit.completed ? .green : .secondary)
                .symbolEffect(.bounce, value: habit.completed)
        }
        .padding(.vertical, 2)
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: sync.reachable ? "hourglass" : "iphone.slash")
                .font(.title2)
                .foregroundStyle(.green)
            Text(sync.reachable ? "Chargement…" : "Ouvre Steady sur l'iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Réessayer") { sync.refresh() }
                .font(.caption2)
        }
        .padding()
    }
}

#Preview {
    WatchHomeView()
}
