import Foundation

/// Source de vérité partagée avec le serveur MCP : ~/.vault-mcp/profiles.json.
/// Toute mutation réécrit immédiatement le fichier pour que le MCP reste synchro.
@MainActor
final class ProfileStore: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var lastError: String?

    /// Dossier ~/.vault-mcp
    static var vaultDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vault-mcp", isDirectory: true)
    }

    static var profilesFileURL: URL {
        vaultDir.appendingPathComponent("profiles.json")
    }

    init() {
        load()
    }

    // MARK: - Chargement / sauvegarde

    func load() {
        let url = Self.profilesFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            profiles = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(ProfilesFile.self, from: data)
            profiles = decoded.profiles
        } catch {
            lastError = "Lecture de profiles.json impossible : \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: Self.vaultDir, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(ProfilesFile(profiles: profiles))
            try data.write(to: Self.profilesFileURL, options: .atomic)
        } catch {
            lastError = "Écriture de profiles.json impossible : \(error.localizedDescription)"
        }
    }

    // MARK: - CRUD profils

    /// Crée un profil : génère un id unique, crée le dossier + notes/ + memory.md.
    @discardableResult
    func addProfile(name: String, description: String, folder: URL) -> Profile? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Le nom du profil ne peut pas être vide."
            return nil
        }
        let id = uniqueID(base: ProfileID.slug(from: trimmed))
        let profile = Profile(
            id: id,
            name: trimmed,
            path: folder.path,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            memoryFile: "memory.md",
            lastUpdated: ISO8601DateFormatter().string(from: Date())
        )
        do {
            try FileManager.default.createDirectory(
                at: profile.notesURL, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: profile.memoryURL.path) {
                let header = "# Mémoire — \(profile.name)\n"
                try header.write(to: profile.memoryURL, atomically: true, encoding: .utf8)
            }
        } catch {
            lastError = "Création du dossier du profil impossible : \(error.localizedDescription)"
            return nil
        }
        profiles.append(profile)
        save()
        return profile
    }

    func renameProfile(_ profile: Profile, to newName: String, description: String) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { profiles[idx].name = trimmed }
        profiles[idx].description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        profiles[idx].lastUpdated = ISO8601DateFormatter().string(from: Date())
        save()
    }

    /// Retire le profil de la config. Ne supprime PAS les fichiers disque par
    /// sécurité (à faire manuellement si souhaité).
    func removeProfile(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        save()
    }

    func touch(_ profile: Profile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx].lastUpdated = ISO8601DateFormatter().string(from: Date())
        save()
    }

    // MARK: - Utilitaires

    private func uniqueID(base: String) -> String {
        var candidate = base
        var n = 2
        let existing = Set(profiles.map { $0.id })
        while existing.contains(candidate) {
            candidate = "\(base)-\(n)"
            n += 1
        }
        return candidate
    }
}
