import SwiftUI

/// Onglet Clés API : vault unique partagé, stocké dans le Keychain macOS.
/// Chaque clé a un nom (unique) + une référence libre pour distinguer des clés
/// d'un même service (ex. Stripe demo/prod, projets différents).
/// Valeurs masquées par défaut, affichage à la demande.
struct APIKeysView: View {
    @State private var items: [KeychainService.APIKey] = []
    @State private var revealed: Set<String> = []
    @State private var cache: [String: String] = [:]

    @State private var showingAdd = false
    @State private var newName = ""
    @State private var newReference = ""
    @State private var newValue = ""

    @State private var editingKey: KeychainService.APIKey?
    @State private var editReference = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                Section {
                    if items.isEmpty {
                        Text("Aucune clé. Ajoutez-en une avec le bouton +.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(items) { key in
                        keyRow(key)
                    }
                } header: {
                    Text("Vault partagé (Keychain macOS · service « ClaudeVault »)")
                } footer: {
                    Text("La référence aide à distinguer plusieurs clés d'un même service "
                         + "(ex. Stripe démo/prod, projets). Claude lit une clé par son nom via get_api_key.")
                        .font(.caption)
                }
            }
            .listStyle(.inset)
        }
        .navigationTitle("Clés API")
        .toolbar {
            ToolbarItem {
                Button {
                    newName = ""; newReference = ""; newValue = ""; showingAdd = true
                } label: { Image(systemName: "plus") }
                .help("Ajouter une clé")
            }
        }
        .onAppear(perform: reload)
        .sheet(isPresented: $showingAdd) { addSheet }
        .sheet(item: $editingKey) { key in editReferenceSheet(key) }
    }

    private func keyRow(_ key: KeychainService.APIKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(key.name).font(.body.weight(.medium))
                    if !key.reference.isEmpty {
                        Text(key.reference)
                            .font(.caption)
                            .foregroundStyle(.tint)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(.tint.opacity(0.12), in: Capsule())
                    }
                }
                Text(revealed.contains(key.name) ? (cache[key.name] ?? "") : "••••••••••••")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button {
                toggleReveal(key.name)
            } label: {
                Image(systemName: revealed.contains(key.name) ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .help(revealed.contains(key.name) ? "Masquer" : "Afficher")

            Button {
                editReference = key.reference
                editingKey = key
            } label: {
                Image(systemName: "tag")
            }
            .buttonStyle(.borderless)
            .help("Modifier la référence")

            Button(role: .destructive) {
                KeychainService.delete(name: key.name)
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
                TextField("Nom", text: $newName, prompt: Text("STRIPE_PROD_PROJET_X"))
                TextField("Référence (optionnelle)", text: $newReference,
                          prompt: Text("Stripe — Production — Projet X"))
                SecureField("Valeur", text: $newValue, prompt: Text("sk_live_…"))
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
        .frame(width: 460)
    }

    private func editReferenceSheet(_ key: KeychainService.APIKey) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Référence de « \(key.name) »").font(.title3.weight(.semibold))
            Form {
                TextField("Référence", text: $editReference,
                          prompt: Text("Stripe — Démo — Projet Y"))
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler") { editingKey = nil }
                    .keyboardShortcut(.cancelAction)
                Button("Enregistrer") {
                    KeychainService.setReference(name: key.name, reference: editReference)
                    editingKey = nil
                    reload()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    // MARK: - Actions

    private func reload() {
        items = KeychainService.listItems()
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
        if KeychainService.set(name: newName, value: newValue, reference: newReference) {
            showingAdd = false
            reload()
        }
    }
}
