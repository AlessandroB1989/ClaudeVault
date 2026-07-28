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
        /// Libellé libre pour distinguer des clés d'un même service
        /// (ex. « Stripe — Production — Projet X »). Stocké dans le
        /// commentaire de l'entrée Keychain.
        var reference: String = ""
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
    static func set(name: String, value: String, reference: String = "") -> Bool {
        let account = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty, !value.isEmpty else { return false }
        // -U : met à jour si la clé existe déjà.
        // -A : accessible par toutes les applications de l'utilisateur (pas de popup MCP).
        // -j : commentaire = référence (libellé libre).
        var args = [
            "add-generic-password",
            "-s", service,
            "-a", account,
            "-w", value,
            "-U", "-A",
        ]
        let ref = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ref.isEmpty { args += ["-j", ref] }
        let ok = runSecurity(args)
        exportIndex()
        return ok
    }

    /// Met à jour uniquement la référence (commentaire) d'une clé existante,
    /// sans avoir à ressaisir la valeur secrète.
    @discardableResult
    static func setReference(name: String, reference: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
        ]
        let attrs: [String: Any] = [
            kSecAttrComment as String: reference.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        let ok = SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecSuccess
        exportIndex()
        return ok
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
        let ok = runSecurity(["delete-generic-password", "-s", service, "-a", name])
        exportIndex()
        return ok
    }

    /// URL de l'index partagé avec le serveur MCP (~/.vault-mcp/api-keys.json).
    private static var indexFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vault-mcp/api-keys.json")
    }

    /// Écrit l'index des clés (noms + références, SANS les valeurs) pour que
    /// l'outil MCP list_api_keys puisse les présenter à Claude.
    static func exportIndex() {
        let entries = listItems().map { ["name": $0.name, "reference": $0.reference] }
        guard let data = try? JSONSerialization.data(
            withJSONObject: entries, options: [.prettyPrinted, .sortedKeys]) else { return }
        let dir = indexFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: indexFileURL, options: .atomic)
    }

    // MARK: - Liste

    /// Liste les noms de toutes les clés du vault (sans les valeurs).
    static func listNames() -> [String] {
        listItems().map { $0.name }
    }

    /// Liste les clés du vault avec leur référence (sans les valeurs).
    static func listItems() -> [APIKey] {
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
            .compactMap { attrs -> APIKey? in
                guard let name = attrs[kSecAttrAccount as String] as? String else { return nil }
                let ref = attrs[kSecAttrComment as String] as? String ?? ""
                return APIKey(name: name, reference: ref)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
