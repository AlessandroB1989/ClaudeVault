import Foundation

/// Un profil de mémoire = un domaine de vie/activité isolé.
/// Correspond exactement à une entrée de ~/.vault-mcp/profiles.json,
/// partagé avec le serveur MCP.
struct Profile: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var path: String
    var description: String
    var memoryFile: String
    var lastUpdated: String?

    init(
        id: String,
        name: String,
        path: String,
        description: String,
        memoryFile: String = "memory.md",
        lastUpdated: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.description = description
        self.memoryFile = memoryFile
        self.lastUpdated = lastUpdated
    }

    /// URL du dossier du profil.
    var folderURL: URL { URL(fileURLWithPath: path) }

    /// URL du dossier des notes brutes.
    var notesURL: URL { folderURL.appendingPathComponent("notes", isDirectory: true) }

    /// URL du fichier mémoire condensé.
    var memoryURL: URL {
        folderURL.appendingPathComponent(memoryFile.isEmpty ? "memory.md" : memoryFile)
    }
}

/// Enveloppe JSON telle qu'attendue par le serveur MCP : { "profiles": [...] }.
struct ProfilesFile: Codable {
    var profiles: [Profile]
}

enum ProfileID {
    /// Génère un id slug stable et sûr pour le système de fichiers.
    static func slug(from name: String) -> String {
        let lowered = name.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        let allowed = lowered.map { ch -> Character in
            (ch.isLetter || ch.isNumber) ? ch : "-"
        }
        let collapsed = String(allowed)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "profil" : collapsed
    }
}
