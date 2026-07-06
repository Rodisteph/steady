import SwiftUI
import SwiftData
import Observation

@MainActor
@Observable
final class ChallengeManager {
    var templates: [ChallengeTemplate] { ChallengeCatalog.all }
    private var context: ModelContext?

    func configure(_ context: ModelContext) {
        self.context = context
    }

    func join(_ template: ChallengeTemplate, habit: Habit? = nil) {
        guard let context = context else { return }
        let challenge = Challenge(template: template)
        challenge.habitID = habit?.id
        context.insert(challenge)
        try? context.save()
        HapticManager.lightImpact()
    }

    /// Crée un défi personnalisé (hors catalogue).
    @discardableResult
    func createCustom(title: String, icon: String, target: Int, unit: String,
                      isDaily: Bool, windowDays: Int, habit: Habit? = nil) -> Challenge? {
        guard let context = context else { return nil }
        let challenge = Challenge(customTitle: title, icon: icon, target: target,
                                  unit: unit, isDaily: isDaily, windowDays: windowDays)
        challenge.habitID = habit?.id
        context.insert(challenge)
        try? context.save()
        HapticManager.success()
        return challenge
    }

    /// Rejoint un défi partagé reçu par invitation (copie locale reliée par `sharedID`).
    @discardableResult
    func joinShared(_ invite: ChallengeInvite) -> Challenge? {
        guard let context = context else { return nil }
        let days = max(1, Calendar.current.dateComponents([.day], from: Date(), to: invite.deadline).day ?? 1)
        let challenge = Challenge(customTitle: invite.title, icon: invite.icon, target: invite.target,
                                  unit: invite.unit, isDaily: invite.isDaily, windowDays: days)
        challenge.deadline = invite.deadline
        challenge.sharedID = invite.id
        context.insert(challenge)
        try? context.save()
        HapticManager.success()
        return challenge
    }

    func abandon(_ challenge: Challenge) {
        guard let context = context else { return }
        context.delete(challenge)
        try? context.save()
    }

    /// Un défi quotidien est-il piloté automatiquement par une habitude liée ?
    func isAuto(_ challenge: Challenge) -> Bool {
        challenge.isDaily && challenge.habitID != nil
    }

    func isExpired(_ challenge: Challenge) -> Bool {
        !challenge.isCompleted && Date() > challenge.deadline
    }

    func daysRemaining(_ challenge: Challenge) -> Int {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: challenge.deadline)).day ?? 0
        return max(0, days)
    }

    /// Progression d'un défi quotidien lié = nb de jours où l'habitude a été validée depuis le début.
    func linkedProgress(_ challenge: Challenge, habit: Habit) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: challenge.startDate)
        let days = Set(
            habit.records
                .filter { $0.count >= habit.dailyGoal }
                .map { cal.startOfDay(for: $0.date) }
        ).filter { $0 >= start }
        return min(days.count, challenge.target)
    }

    /// Recalcule les défis liés (auto-progression) et attribue les récompenses.
    func refresh(_ challenges: [Challenge], habits: [Habit]) {
        for challenge in challenges where !challenge.isCompleted {
            guard isAuto(challenge), let habit = habits.first(where: { $0.id == challenge.habitID }) else { continue }
            let p = linkedProgress(challenge, habit: habit)
            if p != challenge.progress { challenge.progress = p }
            if p >= challenge.target { complete(challenge) }
        }
        try? context?.save()
    }

    private func complete(_ challenge: Challenge) {
        challenge.progress = challenge.target
        challenge.isCompleted = true
        if !challenge.rewarded {
            challenge.rewarded = true
            GamificationManager.shared.grant(xp: challenge.rewardXP, coins: challenge.rewardCoins)
            HapticManager.success()
        }
    }

    /// Un défi quotidien ne peut avancer qu'une fois par jour.
    func canAdvanceToday(_ challenge: Challenge) -> Bool {
        guard !challenge.isCompleted else { return false }
        guard challenge.isDaily else { return true }
        if let last = challenge.lastProgressDate {
            return !Calendar.current.isDateInToday(last)
        }
        return true
    }

    /// Avance le défi. Renvoie `true` si le défi vient d'être terminé.
    @discardableResult
    func advance(_ challenge: Challenge, by amount: Int = 1) -> Bool {
        guard !challenge.isCompleted else { return false }
        if challenge.isDaily {
            guard canAdvanceToday(challenge) else { return false }
            challenge.progress += 1
        } else {
            challenge.progress += amount
        }
        challenge.lastProgressDate = Date()

        var justFinished = false
        if challenge.progress >= challenge.target {
            complete(challenge)
            justFinished = true
        } else {
            HapticManager.lightImpact()
        }
        try? context?.save()
        return justFinished
    }
}
