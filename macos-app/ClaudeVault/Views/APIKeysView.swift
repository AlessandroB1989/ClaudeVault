import SwiftUI

/// Onglet Clés API : vault unique partagé, stocké dans le Keychain macOS.
/// Valeurs masquées par défaut, affichage à la demande.
struct APIKeysView: View {
    @State private var names: [String] = []
    @State private var revealed: Set<String> = []
    @State private var cache: [String: String] = [:]

    @State private var showingAdd = false
    @State private var newName = ""
    @State private var newValue = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                Section {
                    if names.isEmpty {
                        Text("Aucune clé. Ajoutez-en une avec le bouton +.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(names, id: \.self) { name in
                        keyRow(name)
                    }
                } header: {
                    Text("Vault partagé (Keychain macOS · service « ClaudeVault »)")
                } footer: {
                    Text("Ces clés sont accessibles à Claude via l'outil MCP get_api_key.")
                        .font(.caption)
                }
            }
            .listStyle(.inset)
        }
        .navigationTitle("Clés API")
        .toolbar {
            ToolbarItem {
                Button {
                    newName = ""; newValue = ""; showingAdd = true
                } label: { Image(systemName: "plus") }
                .help("Ajouter une clé")
            }
        }
        .onAppear(perform: reload)
        .sheet(isPresented: $showingAdd) { addSheet }
    }

    private func keyRow(_ name: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body.weight(.medium))
                Text(revealed.contains(name) ? (cache[name] ?? "") : "••••••••••••")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                toggleReveal(name)
            } label: {
                Image(systemName: revealed.contains(name) ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .help(revealed.contains(name) ? "Masquer" : "Afficher")

            Button(role: .destructive) {
                KeychainService.delete(name: name)
                reload()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Supprimer")
        }
        .padding(.vertical, 4)
    }

    private var addSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nouvelle clé API").font(.title3.weight(.semibold))
            Form {
                TextField("Nom", text: $newName, prompt: Text("OPENAI_API_KEY"))
                SecureField("Valeur", text: $newValue, prompt: Text("sk-…"))
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler") { showingAdd = false }
                    .keyboardShortcut(.cancelAction)
                Button("Enregistrer") { addKey() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || newValue.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    // MARK: - Actions

    private func reload() {
        names = KeychainService.listNames()
        revealed.removeAll()
        cache.removeAll()
    }

    private func toggleReveal(_ name: String) {
        if revealed.contains(name) {
            revealed.remove(name)
        } else {
            cache[name] = KeychainService.get(name: name) ?? ""
            revealed.insert(name)
        }
    }

    private func addKey() {
        if KeychainService.set(name: newName, value: newValue) {
            showingAdd = false
            reload()
        }
    }
}
