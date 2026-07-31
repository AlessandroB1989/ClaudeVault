import Foundation

/// Catégories du coffre-fort (onglet Vault).
enum VaultCategory: String, CaseIterable, Identifiable {
    case apiKey
    case email
    case recovery
    case database

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apiKey: return "Clés API"
        case .email: return "Email"
        case .recovery: return "Recovery"
        case .database: return "Database"
        }
    }

    var systemImage: String {
        switch self {
        case .apiKey: return "key.fill"
        case .email: return "envelope.fill"
        case .recovery: return "lifepreserver.fill"
        case .database: return "cylinder.split.1x2.fill"
        }
    }

    /// Service Keychain. Les clés API restent sur « ClaudeVault » (lisible par le MCP) ;
    /// les autres catégories sont app-privées.
    var service: String {
        switch self {
        case .apiKey: return "ClaudeVault"
        case .email: return "ClaudeVault.email"
        case .recovery: return "ClaudeVault.recovery"
        case .database: return "ClaudeVault.database"
        }
    }
}
