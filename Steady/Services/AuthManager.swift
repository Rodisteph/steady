import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth

/// Gère la connexion « Sign in with Apple » et l'échange avec Firebase Auth.
@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()

    private(set) var uid: String?
    var isSignedIn: Bool { uid != nil }

    /// Nonce de sécurité : un code à usage unique qui empêche qu'on rejoue une connexion volée.
    private var currentNonce: String?

    private init() {
        uid = Auth.auth().currentUser?.uid
    }

    /// Prépare la requête Apple (scopes + nonce haché).
    func prepareRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName]
        request.nonce = Self.sha256(nonce)
    }

    /// Traite le résultat d'Apple et signe l'utilisateur dans Firebase.
    func handle(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            print("⚠️ Sign in with Apple annulé/échoué : \(error.localizedDescription)")
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                print("⚠️ Jeton Apple introuvable.")
                return
            }
            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: credential.fullName
            )
            do {
                let result = try await Auth.auth().signIn(with: firebaseCredential)
                uid = result.user.uid
            } catch {
                print("⚠️ Connexion Firebase échouée : \(error.localizedDescription)")
            }
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        uid = nil
    }

    /// Supprime définitivement le compte. Nécessite une re-connexion Apple fraîche
    /// (pour révoquer le jeton et autoriser la suppression). `deleteData` efface
    /// d'abord les données serveur tant qu'on a encore l'accès.
    @discardableResult
    func deleteAccount(_ result: Result<ASAuthorization, Error>,
                       deleteData: () async -> Void) async -> Bool {
        guard
            case .success(let authorization) = result,
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else { return false }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        do {
            // Re-connexion récente : obligatoire avant de supprimer un compte.
            try await Auth.auth().currentUser?.reauthenticate(with: firebaseCredential)
            // Effacer les données serveur pendant qu'on a encore l'accès.
            await deleteData()
            // Révoquer le jeton Apple (exigé par Apple à la suppression de compte).
            if let codeData = credential.authorizationCode,
               let code = String(data: codeData, encoding: .utf8) {
                try? await Auth.auth().revokeToken(withAuthorizationCode: code)
            }
            // Supprimer le compte d'authentification.
            try await Auth.auth().currentUser?.delete()
            uid = nil
            return true
        } catch {
            print("⚠️ Suppression du compte échouée : \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Nonce (sécurité)

    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
