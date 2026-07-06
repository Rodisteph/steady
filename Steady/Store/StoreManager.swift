import StoreKit
import SwiftUI

@MainActor
@Observable
final class StoreManager {

    // Identifiants produits (à créer à l'identique dans App Store Connect).
    static let lifetimeID = "com.rodrigo.steady.premium"   // non-consommable existant
    static let monthlyID  = "com.rodrigo.steady.monthly"   // abonnement mensuel
    static let annualID   = "com.rodrigo.steady.annual"    // abonnement annuel (essai 7 j)

    private var productIDs: Set<String> { [Self.lifetimeID, Self.monthlyID, Self.annualID] }

    private(set) var products: [Product] = []

    var monthly: Product?  { products.first { $0.id == Self.monthlyID } }
    var annual: Product?   { products.first { $0.id == Self.annualID } }
    var lifetime: Product? { products.first { $0.id == Self.lifetimeID } }

    /// Achat StoreKit réel (abonnement actif OU achat à vie). Persisté pour un
    /// démarrage hors-ligne fluide, re-vérifié via currentEntitlements.
    private(set) var hasActivePurchase: Bool {
        didSet { UserDefaults.standard.set(hasActivePurchase, forKey: "steady_premium_unlocked") }
    }

    /// Fin de l'essai Premium débloqué par pub récompensée (badge visiteur 24 h).
    /// Persisté : survit au redémarrage, et s'expire tout seul (aucun code de
    /// « nettoyage » nécessaire — le temps fait le travail).
    private(set) var adTrialUntil: Date {
        didSet { UserDefaults.standard.set(adTrialUntil, forKey: "steady_ad_trial_until") }
    }

    /// SEULE porte d'entrée du droit Premium : achat OU essai pub encore valide.
    /// Toutes les vues existantes lisent déjà cette propriété → l'essai 24 h est
    /// honoré partout sans toucher une seule vue.
    var isPremium: Bool { hasActivePurchase || adTrialUntil > .now }

    /// Accordé UNIQUEMENT par le callback de récompense AdMob (via EntitlementStore).
    func grantAdTrial(hours: Int = 24) {
        adTrialUntil = Date().addingTimeInterval(TimeInterval(hours) * 3600)
    }

    private(set) var isLoading = false
    private(set) var errorMessage: String?

    nonisolated(unsafe) private var transactionListener: Task<Void, Error>?

    init() {
        self.hasActivePurchase = UserDefaults.standard.bool(forKey: "steady_premium_unlocked")
        self.adTrialUntil = UserDefaults.standard.object(forKey: "steady_ad_trial_until") as? Date ?? .distantPast
        self.transactionListener = listenForTransactions()
        Task {
            await verifyCurrentEntitlements()
            await loadProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: productIDs)
            // Ordre d'affichage : mensuel, annuel, à vie.
            self.products = loaded.sorted { lhs, rhs in
                order(lhs.id) < order(rhs.id)
            }
        } catch {
            self.errorMessage = "Impossible de charger les offres : \(error.localizedDescription)"
        }
    }

    private func order(_ id: String) -> Int {
        switch id {
        case Self.monthlyID: return 0
        case Self.annualID: return 1
        case Self.lifetimeID: return 2
        default: return 3
        }
    }

    func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                do {
                    let transaction = try checkVerified(verification)
                    await transaction.finish()
                } catch {
                    // Le test StoreKit du SIMULATEUR échoue parfois la vérification
                    // d'appareil. En DEBUG on tolère pour pouvoir tester ; sinon strict.
                    #if DEBUG
                    if case .unverified(let transaction, _) = verification {
                        await transaction.finish()
                    }
                    #else
                    throw error
                    #endif
                }
                self.hasActivePurchase = true
                self.errorMessage = nil

            case .userCancelled:
                break

            case .pending:
                self.errorMessage = "Achat en attente de validation parentale."

            @unknown default:
                break
            }
        } catch {
            self.errorMessage = "Échec de l'achat : \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await verifyCurrentEntitlements()
        } catch {
            self.errorMessage = "Restauration échouée : \(error.localizedDescription)"
        }
    }

    func verifyCurrentEntitlements() async {
        var foundActivePurchase = false

        // currentEntitlements ne renvoie que les droits ACTIFS (abo en cours ou achat à vie).
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if productIDs.contains(transaction.productID) {
                    foundActivePurchase = true
                }
            } catch {
                #if DEBUG
                if case .unverified(let transaction, _) = result, productIDs.contains(transaction.productID) {
                    foundActivePurchase = true
                }
                #endif
            }
        }

        #if DEBUG
        if hasActivePurchase && !foundActivePurchase { return }
        #endif
        self.hasActivePurchase = foundActivePurchase
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            guard let self else { return }
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.verifyCurrentEntitlements()
                } catch {
                    // Transaction invalide
                }
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
