import SwiftUI

/// Sélection courante dans la sidebar.
enum SidebarSelection: Hashable {
    case profile(String)
    case apiKeys
}

/// Interface principale : sidebar (profils + Clés API) à gauche, contenu à droite.
struct ContentView: View {
    @EnvironmentObject private var store: ProfileStore
    @State private var selection: SidebarSelection?
    @State private var showingNewProfile = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            detail
        }
        .sheet(isPresented: $showingNewProfile) {
            NewProfileSheet()
        }
        .onAppear {
            if selection == nil {
                selection = store.profiles.first.map { .profile($0.id) } ?? .apiKeys
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Profils") {
                ForEach(store.profiles) { profile in
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                            if !profile.description.isEmpty {
                                Text(profile.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    } icon: {
                        Image(systemName: "brain.head.profile")
                    }
                    .tag(SidebarSelection.profile(profile.id))
                    .contextMenu {
                        Button(role: .destructive) {
                            store.removeProfile(profile)
                            if selection == .profile(profile.id) { selection = .apiKeys }
                        } label: {
                            Label("Retirer de la liste", systemImage: "trash")
                        }
                        Button {
                            NSWorkspace.shared.open(profile.folderURL)
                        } label: {
                            Label("Ouvrir le dossier", systemImage: "folder")
                        }
                    }
                }
                Button {
                    showingNewProfile = true
                } label: {
                    Label("Nouveau profil", systemImage: "plus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }

            Section("Vault") {
                Label("Clés API", systemImage: "key.fill")
                    .tag(SidebarSelection.apiKeys)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("ClaudeVault")
        .toolbar {
            ToolbarItem {
                Button {
                    showingNewProfile = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Créer un profil")
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .profile(let id):
            if let profile = store.profiles.first(where: { $0.id == id }) {
                ProfileDetailView(profile: profile)
                    .id(profile.id)
            } else {
                emptyState
            }
        case .apiKeys:
            APIKeysView()
        case .none:
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Sélectionnez un profil ou créez-en un.")
                .foregroundStyle(.secondary)
            Button("Nouveau profil") { showingNewProfile = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
