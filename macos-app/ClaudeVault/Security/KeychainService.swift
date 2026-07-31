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

    /// Édite une clé API : renomme, change la référence et/ou la valeur.
    /// La valeur est conservée si `newValue` est nil (déplacée en interne, jamais affichée).
    @discardableResult
    static func editAPIKey(oldName: String, newName: String, reference: String,
                           newValue: String?) -> Bool {
        let value = newValue ?? get(name: oldName) ?? ""
        guard !value.isEmpty else { return false }
        let newAccount = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newAccount.isEmpty else { return false }
        if oldName != newAccount { delete(name: oldName) }
        return set(name: newAccount, value: value, reference: reference)
    }

    // MARK: - Enregistrements génériques (Email / Recovery / Database)
    //
    // Stockage APP-PRIVÉ (SecItem, sans -A) : ces secrets ne sont lisibles que par
    // ClaudeVault, pas par d'autres process. Le secret est la donnée chiffrée de
    // l'entrée ; les champs non sensibles vont dans le commentaire (JSON).

    private static func metadataToJSON(_ meta: [String: String]) -> String {
        guard !meta.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: meta, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8) else { return "" }
        return s
    }
    private static func jsonToMetadata(_ s: String?) -> [String: String] {
        guard let s, let data = s.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        var out: [String: String] = [:]
        for (k, v) in obj { out[k] = String(describing: v) }
        return out
    }

    /// Crée ou met à jour un enregistrement (secret + métadonnées non sensibles).
    @discardableResult
    static func saveRecord(service: String, account: String, secret: String,
                           metadata: [String: String]) -> Bool {
        let acc = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !acc.isEmpty, let data = secret.data(using: .utf8) else { return false }
        let comment = metadataToJSON(metadata)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: acc,
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrComment as String: comment,
        ]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecSuccess { return true }
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrComment as String] = comment
            add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    /// Liste les enregistrements d'un service : compte + métadonnées (SANS le secret).
    static func listRecords(service: String) -> [(account: String, metadata: [String: String])] {
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
            .compactMap { attrs -> (String, [String: String])? in
                guard let account = attrs[kSecAttrAccount as String] as? String else { return nil }
                return (account, jsonToMetadata(attrs[kSecAttrComment as String] as? String))
            }
            .sorted { $0.0.localizedStandardCompare($1.0) == .orderedAscending }
    }

    /// Lit le secret d'un enregistrement (à n'appeler qu'après authentification).
    static func revealRecord(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func deleteRecord(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Renomme un enregistrement (change le compte) en conservant secret + métadonnées.
    @discardableResult
    static func renameRecord(service: String, from: String, to: String) -> Bool {
        let dest = to.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dest.isEmpty, dest != from else { return dest == from }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: from,
        ]
        let attrs: [String: Any] = [kSecAttrAccount as String: dest]
        return SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecSuccess
    }

    /// Met à jour le secret et/ou les métadonnées d'un enregistrement existant.
    /// `secret == nil` → inchangé ; `metadata == nil` → inchangé.
    @discardableResult
    static func updateRecord(service: String, account: String,
                             secret: String?, metadata: [String: String]?) -> Bool {
        var attrs: [String: Any] = [:]
        if let secret, let data = secret.data(using: .utf8) {
            attrs[kSecValueData as String] = data
        }
        if let metadata {
            attrs[kSecAttrComment as String] = metadataToJSON(metadata)
        }
        guard !attrs.isEmpty else { return true }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        return SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecSuccess
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
