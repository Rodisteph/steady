import SwiftUI
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers

// MARK: - Image partageable
//
// Emballe l'UIImage rendue dans un type « Transferable » pour que le bouton
// natif « Partager » (ShareLink) sache l'exporter en PNG (Photos, Messages,
// WhatsApp, Instagram, etc.).

struct ShareableImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { shareable in
            shareable.image.pngData() ?? Data()
        }
        .suggestedFileName("Steady-ma-semaine.png")
    }
}

// MARK: - Écran « Partager ma semaine »
//
// Affiche un aperçu de la carte, puis propose le partage via la feuille de
// partage native d'iOS.

struct ShareProgressSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Habit.creationDate) private var habits: [Habit]

    var store: HabitStore

    @State private var shareable: ShareableImage?

    private var stats: WeeklyShareStats {
        WeeklyShareStats.make(from: habits, store: store)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    ShareCardView(stats: stats)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: Color.black.opacity(0.15), radius: 16, y: 8)
                        .padding(.top, Theme.Spacing.md)

                    if let shareable {
                        ShareLink(
                            item: shareable,
                            preview: SharePreview(
                                "Ma semaine sur Steady",
                                image: Image(uiImage: shareable.image)
                            )
                        ) {
                            Label("Partager", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Capsule().fill(Color.steadySageGradient))
                        }
                        .padding(.horizontal)
                    } else {
                        ProgressView()
                            .padding(.vertical, Theme.Spacing.lg)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .background(Color.steadyBackground.ignoresSafeArea())
            .navigationTitle("Partager ma semaine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .task { renderImage() }
        }
    }

    /// Transforme la carte SwiftUI en image PNG nette (×3 pour les écrans Retina).
    @MainActor
    private func renderImage() {
        let renderer = ImageRenderer(content: ShareCardView(stats: stats))
        renderer.scale = 3
        if let ui = renderer.uiImage {
            shareable = ShareableImage(image: ui)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Habit.self, DailyRecord.self, configurations: config)
    return ShareProgressSheet(store: HabitStore())
        .modelContainer(container)
}
