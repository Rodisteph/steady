import Foundation

/// Analyse locale d'une entrée de journal (aucune API externe).
struct JournalAnalysis: Identifiable {
    let id = UUID()
    let summary: String
    let positives: [String]
    let improvements: [String]
    let motivation: String
}

/// Décompose le texte du journal en sentiment + thèmes pour produire une
/// petite analyse « coach » : résumé, points positifs, axes, motivation.
struct JournalAIService {

    private struct Theme {
        let keywords: [String]
        let positive: String   // formulation si présent côté positif
    }

    // Thèmes détectés (FR + quelques mots EN courants).
    private let positiveThemes: [Theme] = [
        Theme(keywords: ["sport", "courir", "couru", "gym", "muscu", "marche", "vélo", "workout", "run"],
              positive: "Tu as bougé ton corps, excellent pour le moral."),
        Theme(keywords: ["médit", "respir", "calme", "yoga", "pause", "mindful"],
              positive: "Tu as pris un moment pour t'apaiser."),
        Theme(keywords: ["fier", "réussi", "accompli", "validé", "fini", "terminé", "proud", "done"],
              positive: "Tu as accompli ce qui comptait. Sois fier."),
        Theme(keywords: ["gratitude", "reconnaissant", "merci", "chance", "grateful"],
              positive: "Tu as cultivé la gratitude aujourd'hui."),
        Theme(keywords: ["ami", "famille", "proche", "ensemble", "appel", "friend", "family"],
              positive: "Tu as nourri tes liens, ça compte beaucoup."),
        Theme(keywords: ["dormi", "sommeil", "reposé", "repos", "sleep", "rest"],
              positive: "Tu as pris soin de ton repos.")
    ]

    private let negativeThemes: [Theme] = [
        Theme(keywords: ["fatigué", "fatigue", "épuisé", "tired", "exhausted"],
              positive: "Tu sembles fatigué. Accorde-toi du vrai repos demain."),
        Theme(keywords: ["stress", "anxieux", "anxiété", "pression", "stressed", "anxious"],
              positive: "Le stress était présent. Une respiration lente peut aider."),
        Theme(keywords: ["raté", "manqué", "échoué", "abandonné", "pas réussi", "failed", "missed"],
              positive: "Un objectif a glissé. Recommence petit, sans te juger."),
        Theme(keywords: ["procrastin", "remis", "flemme", "reporté", "lazy"],
              positive: "La procrastination a pointé. Découpe la tâche en mini-pas."),
        Theme(keywords: ["triste", "déçu", "mal", "down", "sad"],
              positive: "Journée plus lourde émotionnellement. Sois doux avec toi.")
    ]

    private let motivations: [String] = [
        "Demain est une page neuve. Un petit pas suffira.",
        "Tu fais déjà l'essentiel : tu reviens. Continue.",
        "La régularité bat la perfection. À ton rythme.",
        "Sois fier d'avoir pris ce temps pour toi ce soir.",
        "Demain, vise juste 1 % de mieux. C'est largement assez."
    ]

    func analyze(_ rawText: String) -> JournalAnalysis? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 8 else { return nil }
        let lower = text.lowercased()

        let pos = positiveThemes.filter { theme in theme.keywords.contains { lower.contains($0) } }
        let neg = negativeThemes.filter { theme in theme.keywords.contains { lower.contains($0) } }
        let score = pos.count - neg.count

        // Résumé selon le sentiment global.
        let summary: String
        if score > 0 { summary = L("Une journée plutôt positive d'après tes mots.") }
        else if score < 0 { summary = L("Une journée difficile, et c'est totalement ok.") }
        else { summary = L("Une journée en demi-teinte, avec du bon à retenir.") }

        var positives = pos.map { $0.positive }
        if positives.isEmpty { positives = [L("Tu as pris le temps d'écrire ce soir, déjà une belle habitude.")] }

        var improvements = neg.map { $0.positive }
        if improvements.isEmpty { improvements = [L("Rien de lourd ne ressort. Continue sur cette lancée.")] }

        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        let motivation = L("\(motivations[day % motivations.count])")

        return JournalAnalysis(
            summary: summary,
            positives: Array(positives.prefix(3)),
            improvements: Array(improvements.prefix(3)),
            motivation: motivation
        )
    }
}
