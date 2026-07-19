import SwiftUI
import AppKit

/// Vue d'un profil : arborescence de fichiers .md et sous-dossiers (un par projet)
/// à gauche, éditeur avec bascule Éditer / Aperçu à droite. Style Finder/Notes.app.
struct ProfileDetailView: View {
    let profile: Profile
    @EnvironmentObject private var store: ProfileStore

    enum EditorMode: String, CaseIterable { case edit = "Éditer", preview = "Aperçu" }

    @State private var nodes: [FileNode] = []
    @State private var selection: URL?
    @State private var editorText = ""
    @State private var isDirty = false
    @State private var mode: EditorMode = .edit

    // Dialogues
    @State private var showingNewNote = false
    @State private var newNoteName = ""
    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @State private var renaming = false
    @State private var renameText = ""

    private var memoryURL: URL { profile.memoryURL }

    var body: some View {
        HSplitView {
            fileList
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 360)
            editor
                .frame(minWidth: 360, maxWidth: .infinity)
        }
        .navigationTitle(profile.name)
        .navigationSubtitle(profile.description)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    NSWorkspace.shared.open(profile.folderURL)
                } label: { Image(systemName: "folder") }
                .help("Ouvrir le dossier du profil dans le Finder")

                Button {
                    newFolderName = ""; showingNewFolder = true
                } label: { Image(systemName: "folder.badge.plus") }
                .help("Nouveau dossier (projet)")

                Button {
                    newNoteName = ""; showingNewNote = true
                } label: { Image(systemName: "square.and.pencil") }
                .help("Nouvelle note")
            }
        }
        .onAppear(perform: reload)
        .onChange(of: profile.id) { _, _ in
            selection = nil
            reload()
        }
        .alert("Nouvelle note", isPresented: $showingNewNote) {
            TextField("nom.md", text: $newNoteName)
            Button("Créer", action: createNote)
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Créée dans : \(targetFolderLabel)")
        }
        .alert("Nouveau dossier", isPresented: $showingNewFolder) {
            TextField("Nom du projet", text: $newFolderName)
            Button("Créer", action: createFolder)
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Créé dans : \(targetFolderLabel)")
        }
        .alert("Renommer", isPresented: $renaming) {
            TextField("Nouveau nom", text: $renameText)
            Button("Renommer", action: performRename)
            Button("Annuler", role: .cancel) {}
        }
    }

    // MARK: - Liste des fichiers

    private var fileList: some View {
        List(selection: $selection) {
            Section("Mémoire condensée") {
                Label(memoryURL.lastPathComponent, systemImage: "sparkles")
                    .tag(memoryURL)
            }
            Section("Notes") {
                if nodes.isEmpty {
                    Text("Aucune note. Créez une note ou un dossier ci-dessous.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                OutlineGroup(nodes, id: \.id, children: \.children) { node in
                    row(for: node).tag(node.url)
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: selection) { _, newValue in load(newValue) }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Button {
                    newFolderName = ""; showingNewFolder = true
                } label: {
                    Label("Dossier", systemImage: "folder.badge.plus")
                }
                Button {
                    newNoteName = ""; showingNewNote = true
                } label: {
                    Label("Note", systemImage: "plus")
                }
            }
            .buttonStyle(.borderless)
            .padding(8)
            .frame(maxWidth: .infinity)
        }
    }

    private func row(for node: FileNode) -> some View {
        Label(
            node.name,
            systemImage: node.isDirectory ? "folder" : "doc.text"
        )
        .contextMenu {
            Button {
                renameText = node.name
                selection = node.url
                renaming = true
            } label: { Label("Renommer", systemImage: "pencil") }

            if node.isDirectory {
                Button {
                    selection = node.url
                    newNoteName = ""; showingNewNote = true
                } label: { Label("Nouvelle note ici", systemImage: "plus") }
                Button {
                    selection = node.url
                    newFolderName = ""; showingNewFolder = true
                } label: { Label("Nouveau sous-dossier", systemImage: "folder.badge.plus") }
            }

            Button {
                NSWorkspace.shared.open(node.isDirectory ? node.url : node.url.deletingLastPathComponent())
            } label: { Label("Révéler dans le Finder", systemImage: "folder") }

            Divider()
            Button(role: .destructive) {
                delete(node.url)
            } label: {
                Label(node.isDirectory ? "Supprimer le dossier" : "Supprimer", systemImage: "trash")
            }
        }
    }

    // MARK: - Éditeur

    @ViewBuilder
    private var editor: some View {
        if let selection, isFileSelected {
            VStack(spacing: 0) {
                HStack {
                    Text(selection.lastPathComponent).font(.headline)
                    if isDirty {
                        Circle().fill(.orange).frame(width: 7, height: 7)
                            .help("Modifications non enregistrées")
                    }
                    Spacer()
                    Picker("", selection: $mode) {
                        ForEach(EditorMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    Button("Enregistrer", action: save)
                        .keyboardShortcut("s", modifiers: .command)
                        .disabled(!isDirty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                if mode == .edit {
                    TextEditor(text: $editorText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .onChange(of: editorText) { _, _ in isDirty = true }
                } else {
                    MarkdownView(text: editorText)
                }
            }
        } else if let selection, findNode(selection, in: nodes)?.isDirectory == true {
            folderPlaceholder(selection)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Sélectionnez un fichier à éditer")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func folderPlaceholder(_ url: URL) -> some View {
        let count = (findNode(url, in: nodes)?.children?.count) ?? 0
        return VStack(spacing: 10) {
            Image(systemName: "folder")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text(url.lastPathComponent).font(.title3.weight(.semibold))
            Text("\(count) élément(s)").foregroundStyle(.secondary)
            HStack {
                Button {
                    newNoteName = ""; showingNewNote = true
                } label: { Label("Nouvelle note", systemImage: "plus") }
                Button {
                    newFolderName = ""; showingNewFolder = true
                } label: { Label("Sous-dossier", systemImage: "folder.badge.plus") }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - État dérivé

    /// Vrai si la sélection pointe vers un fichier éditable (mémoire ou .md).
    private var isFileSelected: Bool {
        guard let selection else { return false }
        if selection == memoryURL { return true }
        return findNode(selection, in: nodes)?.isDirectory == false
    }

    /// Dossier cible pour les nouvelles créations.
    private var targetFolder: URL {
        guard let selection else { return profile.notesURL }
        if selection == memoryURL { return profile.notesURL }
        if let node = findNode(selection, in: nodes) {
            return node.isDirectory ? node.url : node.url.deletingLastPathComponent()
        }
        return profile.notesURL
    }

    private var targetFolderLabel: String {
        let f = targetFolder
        return f == profile.notesURL ? "notes/" : "notes/…/\(f.lastPathComponent)"
    }

    private func findNode(_ url: URL, in nodes: [FileNode]) -> FileNode? {
        for n in nodes {
            if n.url == url { return n }
            if let c = n.children, let found = findNode(url, in: c) { return found }
        }
        return nil
    }

    // MARK: - Actions

    private func reload() {
        try? NotesManager.ensureNotesDir(for: profile)
        nodes = NotesManager.tree(for: profile)
        if selection == nil {
            selection = memoryURL
        }
        load(selection)
    }

    private func load(_ url: URL?) {
        mode = .edit
        guard let url, isFileSelectedURL(url) else { editorText = ""; isDirty = false; return }
        editorText = NotesManager.read(url)
        isDirty = false
    }

    /// Comme isFileSelected mais pour une URL donnée (utilisé au chargement).
    private func isFileSelectedURL(_ url: URL) -> Bool {
        if url == memoryURL { return true }
        return findNode(url, in: nodes)?.isDirectory == false
    }

    private func save() {
        guard let selection, isFileSelected else { return }
        do {
            try NotesManager.write(selection, content: editorText)
            isDirty = false
            store.touch(profile)
        } catch { NSApp.presentError(error) }
    }

    private func createNote() {
        let name = newNoteName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            let base = NotesManager.normalizedFile(name)
            let url = try NotesManager.createNote(
                for: profile, in: targetFolder, name: name,
                content: "# \((base as NSString).deletingPathExtension)\n")
            nodes = NotesManager.tree(for: profile)
            selection = url
            load(url)
        } catch { NSApp.presentError(error) }
    }

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            _ = try NotesManager.createFolder(for: profile, in: targetFolder, name: name)
            nodes = NotesManager.tree(for: profile)
        } catch { NSApp.presentError(error) }
    }

    private func performRename() {
        guard let url = selection, url != memoryURL,
              let node = findNode(url, in: nodes) else { return }
        do {
            let newURL = try NotesManager.rename(url, to: renameText, isDirectory: node.isDirectory)
            nodes = NotesManager.tree(for: profile)
            selection = newURL
            load(newURL)
        } catch { NSApp.presentError(error) }
    }

    private func delete(_ url: URL) {
        do {
            try NotesManager.delete(url)
            nodes = NotesManager.tree(for: profile)
            if selection == url || (selection.map { $0.path.hasPrefix(url.path + "/") } ?? false) {
                selection = memoryURL
                load(memoryURL)
            }
        } catch { NSApp.presentError(error) }
    }
}
