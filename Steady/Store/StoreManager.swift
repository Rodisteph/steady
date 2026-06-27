import StoreKit
import SwiftUI

@Observable
final class StoreManager {
    
    private let productID = "com.yourcompany.steady.premium.unlock"
    private(set) var product: Product?
    private(set) var isPremium: Bool {
        didSet {
            UserDefaults.standard.set(isPremium, forKey: "steady_premium_unlocked")
        }
    }
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    
    private var transactionListener: Task<Void, Error>?
    
    init() {
        self.isPremium = UserDefaults.standard.bool(forKey: "steady_premium_unlocked")
        self.transactionListener = listenForTransactions()
        Task {
            await verifyCurrentEntitlements()
            await loadProduct()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    func loadProduct() async {
        do {
            let products = try await Product.products(for: [productID])
            self.product = products.first
        } catch {
            self.errorMessage = "Impossible de charger les produits : \(error.localizedDescription)"
        }
    }
    
    func purchase() async {
        guard let product = product else {
            errorMessage = "Produit indisponible. Vérifiez votre connexion."
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                self.isPremium = true
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
        var hasActivePurchase = false
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                if transaction.productID == productID {
                    hasActivePurchase = true
                }
            } catch {
                // Transaction invalide ou révoquée
            }
        }
        
        self.isPremium = hasActivePurchase
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    
                    if transaction.productID == self.productID {
                        await MainActor.run {
                            self.isPremium = true
                        }
                    }
                } catch {
                    // Transaction invalide
                }
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    var priceDisplay: String {
        product?.displayPrice ?? "—"
    }
    
    var canAddHabit: Bool {
        isPremium
    }
}

