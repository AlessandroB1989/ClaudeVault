import Foundation

/// Nœud de l'arborescence notes/ : un fichier .md ou un dossier (projet).
struct FileNode: Identifiable, Hashable {
    var url: URL
    var isDirectory: Bool
    /// nil pour un fichier ; tableau (éventuellement vide) pour un dossier.
    var children: [FileNode]?

    var id: String { url.path }
    var name: String { url.lastPathComponent }
}

/// Opérations sur les fichiers .md et sous-dossiers du dossier notes/ d'un profil.
enum NotesManager {
    static func ensureNotesDir(for profile: Profile) throws {
        try FileManager.default.createDirectory(
            at: profile.notesURL, withIntermediateDirectories: true)
    }

    /// Construit l'arbre des enfants de notes/ (dossiers d'abord, puis .md, triés).
    static func tree(for profile: Profile) -> [FileNode] {
        children(of: profile.notesURL)
    }

    private static func children(of dir: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var nodes: [FileNode] = []
        for url in urls {
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                nodes.append(FileNode(url: url, isDirectory: true, children: children(of: url)))
            } else if url.pathExtension.lowercased() == "md" {
                nodes.append(FileNode(url: url, isDirectory: false, children: nil))
            }
        }
        // Dossiers d'abord, puis fichiers, chacun trié naturellement.
        return nodes.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }

    /// Normalise un nom de fichier en simple composant .md (sans chemin).
    static func normalizedFile(_ filename: String) -> String {
        var base = (filename as NSString).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if base.isEmpty { base = "note" }
        if (base as NSString).pathExtension.lowercased() != "md" { base += ".md" }
        return base
    }

    /// Normalise un nom de dossier (simple composant, pas d'extension forcée).
    static func normalizedFolder(_ name: String) -> String {
        let base = (name as NSString).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? "Dossier" : base
    }

    @discardableResult
    static func createNote(
        for profile: Profile, in folder: URL?, name: String, content: String = ""
    ) throws -> URL {
        try ensureNotesDir(for: profile)
        let dir = folder ?? profile.notesURL
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(normalizedFile(name))
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @discardableResult
    static func createFolder(for profile: Profile, in parent: URL?, name: String) throws -> URL {
        try ensureNotesDir(for: profile)
        let base = parent ?? profile.notesURL
        let url = base.appendingPathComponent(normalizedFolder(name), isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func read(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    static func write(_ url: URL, content: String) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    @discardableResult
    static func rename(_ url: URL, to newName: String, isDirectory: Bool) throws -> URL {
        let name = isDirectory ? normalizedFolder(newName) : normalizedFile(newName)
        let dest = url.deletingLastPathComponent().appendingPathComponent(name)
        if dest != url {
            try FileManager.default.moveItem(at: url, to: dest)
        }
        return dest
    }

    /// Supprime un fichier, ou un dossier (récursivement).
    static func delete(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }
}
