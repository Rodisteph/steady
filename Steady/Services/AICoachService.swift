import Foundation

/// Service du coach : phrase de motivation du jour (variée, jamais répétitive sur la journée).
/// Ton : bienveillant mais taquin — le coach encourage ET met au défi.
struct AICoachService {
    func dailyMotivation(bestStreak: Int) -> String {
        // Rotation stable sur la journée (pas d'aléatoire qui change à chaque ouverture).
        let index = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0

        if bestStreak >= 14 {
            let pool = [
                L("\(bestStreak) jours d'affilée. À ce niveau, ce n'est plus une habitude, c'est un mode de vie."),
                L("\(bestStreak) jours. Officiellement inarrêtable. Officieusement : on veut voir jusqu'où ça monte."),
                L("Sérieusement, \(bestStreak) jours ? Même ton téléphone est impressionné.")
            ]
            return pool[index % pool.count]
        }
        if bestStreak >= 7 {
            let pool = [
                L("Une semaine complète. Le toi d'il y a 7 jours n'y croyait pas trop — il avait tort."),
                L("7 jours et plus. On vise les 14, ou on s'arrête en si bon chemin ? (C'était un piège.)"),
                L("Une semaine de régularité, c'est énorme. La deuxième est plus facile. Prouve-le.")
            ]
            return pool[index % pool.count]
        }
        if bestStreak >= 3 {
            let pool = [
                L("\(bestStreak) jours d'affilée. Le cap des 7, c'est maintenant que ça se joue."),
                L("Ta série prend de l'élan. Ce serait dommage de la lâcher juste avant que ça devienne intéressant."),
                L("Jour \(bestStreak). La motivation a démarré le moteur, la discipline tient le volant. Garde le cap.")
            ]
            return pool[index % pool.count]
        }

        let pool = [
            L("Le plus dur, c'est de commencer. Le reste suit, doucement."),
            L("Tu n'as pas besoin d'être parfait, juste régulier. Un petit pas suffit."),
            L("Chaque jour validé est une brique. Tu bâtis quelque chose de solide."),
            L("Avance à ta vitesse. La constance bat l'intensité."),
            L("Ton canapé mène 1 à 0. Tu as toute la journée pour égaliser."),
            L("La motivation arrive rarement avant l'action. Commence, elle te rattrapera en route."),
            L("Petit défi : valide UNE habitude dans les 10 prochaines minutes. Chrono."),
            L("Le toi de ce soir te remerciera. Ou te fera la tête. À toi de choisir."),
            L("Personne n'a jamais regretté d'avoir validé une habitude. Statistique inventée, mais tu vois l'idée."),
            L("Les excuses ne cochent pas les cases. Toi, si."),
            L("Sois fier de te montrer, même les jours sans envie."),
            L("Les petites actions répétées deviennent qui tu es.")
        ]
        return pool[index % pool.count]
    }
}
