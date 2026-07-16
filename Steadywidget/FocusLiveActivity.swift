import ActivityKit
import WidgetKit
import SwiftUI

/// Minuteur de révision sur l'écran verrouillé et dans la Dynamic Island.
///
/// Le décompte utilise `Text(timerInterval:)` et la barre `ProgressView(timerInterval:)` :
/// le système les anime seul, l'app n'a aucune mise à jour à pousser.
struct FocusLiveActivity: Widget {

    /// Vert Steady, écrit en dur : le widget n'a pas accès au Theme de l'app.
    private static let accent = Color(red: 0.18, green: 0.44, blue: 0.33)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Révision", systemImage: "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Self.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.attributes.startDate...context.state.endDate,
                         countsDown: true)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(width: 62)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.attributes.examTitle)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        ProgressView(timerInterval: context.attributes.startDate...context.state.endDate,
                                     countsDown: false) {
                            EmptyView()
                        } currentValueLabel: {
                            EmptyView()
                        }
                        .tint(Self.accent)
                    }
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(Self.accent)
            } compactTrailing: {
                Text(timerInterval: context.attributes.startDate...context.state.endDate,
                     countsDown: true)
                    .font(.caption2.monospacedDigit())
                    .frame(width: 40)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(Self.accent)
            }
            .keylineTint(Self.accent)
        }
    }

    // MARK: - Écran verrouillé

    private func lockScreen(_ context: ActivityViewContext<FocusActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Self.accent))

            VStack(alignment: .leading, spacing: 5) {
                Text("Révision focus")
                    .font(.subheadline.weight(.bold))
                Text(context.attributes.examTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ProgressView(timerInterval: context.attributes.startDate...context.state.endDate,
                             countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(Self.accent)
            }

            Spacer(minLength: 4)

            Text(timerInterval: context.attributes.startDate...context.state.endDate,
                 countsDown: true)
                .font(.title2.weight(.heavy).monospacedDigit())
                .foregroundStyle(Self.accent)
                .frame(width: 74)
        }
        .padding(16)
    }
}
