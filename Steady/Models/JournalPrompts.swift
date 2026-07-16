import Foundation

/// Invites de réflexion pour le journal (contre la page blanche). Tournent chaque jour.
enum JournalPrompts {
    static func all() -> [String] {
        [
            L("Qu'est-ce qui t'a rendu fier aujourd'hui ?"),
            L("Quel petit progrès as-tu remarqué ?"),
            L("Pour quoi es-tu reconnaissant aujourd'hui ?"),
            L("Quelle habitude t'a fait du bien aujourd'hui ?"),
            L("Qu'aimerais-tu faire un peu mieux demain ?"),
            L("Quel moment veux-tu retenir de cette journée ?"),
            L("Comment te sens-tu, là, maintenant ?"),
            L("Qu'est-ce qui t'a donné de l'énergie aujourd'hui ?"),
            L("Qu'est-ce qui t'a pesé, et c'est ok ?"),
            L("Une petite victoire d'aujourd'hui ?"),
            L("Qu'as-tu appris sur toi aujourd'hui ?"),
            L("Qu'est-ce qui mérite un peu plus d'attention demain ?"),
            L("Décris ta journée en trois mots."),
            L("Qu'est-ce qui t'a fait sourire aujourd'hui ?"),
            L("Qu'as-tu envie de lâcher avant de dormir ?"),
            L("Qu'est-ce qui compte vraiment pour toi en ce moment ?")
        ]
    }

    /// Invite stable sur la journée (même invite toute la journée).
    static func today() -> String {
        let pool = all()
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return pool[day % pool.count]
    }

    static func random() -> String { all().randomElement() ?? today() }
}
