import Foundation
import Security

/// Vault unique de clés API, stocké dans le Keychain macOS.
/// Service = "ClaudeVault" (doit correspondre au serveur MCP, qui lit via
/// `security find-generic-password -s ClaudeVault -a <nom>`).
///
/// Écriture : via `/usr/bin/security add-generic-password -A`, qui pose une ACL
/// « tous les process du même utilisateur » — ainsi le serveur MCP (node → security)
/// lit les clés SANS popup d'autorisation à répétition. Lecture/liste : SecItem.
enum KeychainService {
    static let service = "ClaudeVault"

    struct APIKey: Identifiable, Hashable {
        var id: String { name }
        var name: String
    }

    /// Exécute /usr/bin/security. Retourne true si code de sortie 0.
    @discardableResult
    private static func runSecurity(_ args: [String]) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        proc.arguments = args
        proc.standardOutput = Pipe()
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Écriture / mise à jour

    @discardableResult
    static func set(name: String, value: String) -> Bool {
        let account = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty, !value.isEmpty else { return false }
        // -U : met à jour si la clé existe déjà.
        // -A : accessible par toutes les applications de l'utilisateur (pas de popup MCP).
        return runSecurity([
            "add-generic-password",
            "-s", service,
            "-a", account,
            "-w", value,
            "-U",
            "-A",
        ])
    }

    // MARK: - Lecture

    static func get(name: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Suppression

    @discardableResult
    static func delete(name: String) -> Bool {
        runSecurity(["delete-generic-password", "-s", service, "-a", name])
    }

    // MARK: - Liste

    /// Liste les noms de toutes les clés du vault (sans les valeurs).
    static func listNames() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return [] }
        return items
            .compactMap { $0[kSecAttrAccount as String] as? String }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}
