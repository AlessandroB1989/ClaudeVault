import Foundation
import LocalAuthentication

/// Verrouillage de l'app par authentification macOS (mot de passe de session
/// OU biométrie Touch ID), via LocalAuthentication.
/// Policy `deviceOwnerAuthentication` : accepte le mot de passe si pas de Touch ID.
@MainActor
final class AppLock: ObservableObject {
    @Published var isUnlocked = false
    @Published var isAuthenticating = false
    @Published var lastError: String?

    private let reason = "Déverrouiller ClaudeVault pour accéder à vos profils et clés API."

    /// Verrouille immédiatement (retour au premier plan, mise en veille…).
    func lock() {
        isUnlocked = false
    }

    /// Lance l'authentification. Idempotent : ne relance pas si déjà en cours
    /// ou déjà déverrouillé.
    func authenticate() {
        guard !isUnlocked, !isAuthenticating else { return }
        isAuthenticating = true
        lastError = nil

        let context = LAContext()
        context.localizedFallbackTitle = "Utiliser le mot de passe"

        var authError: NSError?
        let policy: LAPolicy = .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: &authError) else {
            // Pas de mécanisme d'auth disponible : on déverrouille pour ne pas
            // enfermer l'utilisateur hors de sa propre app.
            self.lastError = authError?.localizedDescription
            self.isAuthenticating = false
            self.isUnlocked = true
            return
        }

        context.evaluatePolicy(policy, localizedReason: reason) { success, error in
            Task { @MainActor in
                self.isAuthenticating = false
                if success {
                    self.isUnlocked = true
                } else {
                    self.isUnlocked = false
                    self.lastError = error?.localizedDescription
                }
            }
        }
    }
}
