import SwiftUI

/// Bibliothèque d'icônes SF Symbols, organisée par catégorie + favoris.
enum IconCategory: String, CaseIterable, Identifiable {
    case popular, sport, food, study, finance, travel, health, sleep, pets, work, music, gaming
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .popular: return "Populaires"
        case .sport: return "Sport"
        case .food: return "Cuisine"
        case .study: return "Études"
        case .finance: return "Finance"
        case .travel: return "Voyage"
        case .health: return "Santé"
        case .sleep: return "Sommeil"
        case .pets: return "Animaux"
        case .work: return "Travail"
        case .music: return "Musique"
        case .gaming: return "Jeux"
        }
    }

    var symbols: [String] {
        switch self {
        case .popular:
            return ["star.fill", "flame.fill", "leaf.fill", "sun.max.fill", "moon.fill", "bolt.fill",
                    "drop.fill", "heart.fill", "checkmark.seal.fill", "sparkles", "book.fill", "figure.run",
                    "brain.head.profile", "cup.and.saucer.fill", "pencil", "music.note"]
        case .sport:
            return ["figure.run", "figure.walk", "figure.strengthtraining.traditional", "figure.core.training",
                    "figure.flexibility", "figure.yoga", "figure.cooldown", "figure.hiking", "figure.jumprope",
                    "figure.pool.swim", "dumbbell.fill", "sportscourt.fill", "bicycle", "soccerball",
                    "basketball.fill", "tennis.racket", "trophy.fill", "medal.fill"]
        case .food:
            return ["fork.knife", "cup.and.saucer.fill", "mug.fill", "takeoutbag.and.cup.and.straw.fill",
                    "carrot.fill", "fish.fill", "birthday.cake.fill", "wineglass.fill", "drop.fill",
                    "leaf.fill", "flame.fill"]
        case .study:
            return ["book.fill", "books.vertical.fill", "graduationcap.fill", "pencil", "pencil.and.ruler.fill",
                    "brain.head.profile", "lightbulb.fill", "text.book.closed.fill", "character.book.closed.fill",
                    "backpack.fill", "globe", "newspaper.fill"]
        case .finance:
            return ["dollarsign.circle.fill", "eurosign.circle.fill", "creditcard.fill", "banknote.fill",
                    "chart.line.uptrend.xyaxis", "chart.pie.fill", "building.columns.fill", "bag.fill",
                    "cart.fill", "bitcoinsign.circle.fill"]
        case .travel:
            return ["airplane", "car.fill", "bus.fill", "tram.fill", "bicycle", "map.fill",
                    "globe.europe.africa.fill", "suitcase.fill", "beach.umbrella.fill", "mountain.2.fill",
                    "fuelpump.fill", "ferry.fill", "tent.fill"]
        case .health:
            return ["heart.fill", "cross.case.fill", "pills.fill", "stethoscope", "bandage.fill",
                    "lungs.fill", "drop.fill", "allergens", "figure.mind.and.body", "brain.head.profile",
                    "waveform.path.ecg"]
        case .sleep:
            return ["moon.fill", "moon.stars.fill", "bed.double.fill", "zzz", "powersleep",
                    "alarm.fill", "sunrise.fill", "sunset.fill", "clock.fill"]
        case .pets:
            return ["pawprint.fill", "dog.fill", "cat.fill", "bird.fill", "fish.fill",
                    "tortoise.fill", "hare.fill", "ant.fill", "ladybug.fill"]
        case .work:
            return ["briefcase.fill", "laptopcomputer", "desktopcomputer", "keyboard.fill", "envelope.fill",
                    "calendar", "checklist", "doc.fill", "folder.fill", "paperclip", "building.2.fill",
                    "chevron.left.forwardslash.chevron.right"]
        case .music:
            return ["music.note", "music.mic", "guitars.fill", "pianokeys", "headphones",
                    "speaker.wave.2.fill", "metronome.fill", "music.quarternote.3"]
        case .gaming:
            return ["gamecontroller.fill", "dice.fill", "puzzlepiece.fill", "flag.checkered", "target",
                    "paintbrush.fill", "camera.fill", "die.face.5.fill"]
        }
    }

    /// Toutes les icônes (sans doublons), pour la recherche.
    static var allSymbols: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for category in allCases where category != .popular {
            for s in category.symbols where !seen.contains(s) {
                seen.insert(s); result.append(s)
            }
        }
        return result
    }
}

/// Favoris persistés (noms de SF Symbols).
@MainActor
@Observable
final class IconFavorites {
    static let shared = IconFavorites()
    private let key = "steady_favorite_icons"

    private(set) var symbols: Set<String>

    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: key) ?? []
        symbols = Set(saved)
    }

    func toggle(_ symbol: String) {
        if symbols.contains(symbol) { symbols.remove(symbol) } else { symbols.insert(symbol) }
        UserDefaults.standard.set(Array(symbols), forKey: key)
    }

    func contains(_ symbol: String) -> Bool { symbols.contains(symbol) }
}
