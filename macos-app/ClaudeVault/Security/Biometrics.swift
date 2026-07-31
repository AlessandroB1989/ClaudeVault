import Foundation
import LocalAuthentication

/// Authentification à la demande pour révéler/copier un secret.
/// Redéclenche Touch ID / Face ID / mot de passe macOS à chaque appel
/// (policy `deviceOwnerAuthentication`, comme le verrou de l'app).
enum Biometrics {
    /// Retourne true si l'utilisateur s'est authentifié (ou si aucun mécanisme
    /// d'auth n'est disponible, pour ne pas bloquer l'accès à ses propres données).
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Utiliser le mot de passe"
        // Chaque révélation redemande l'auth (pas de réutilisation implicite).
        context.touchIDAuthenticationAllowableReuseDuration = 0

        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            return true
        }
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
                continuation.resume(returning: ok)
            }
        }
    }
}
