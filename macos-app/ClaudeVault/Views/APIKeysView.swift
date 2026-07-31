import SwiftUI

/// Onglet Clés API : vault unique partagé, stocké dans le Keychain macOS.
/// Chaque clé a un nom (unique) + une référence libre. La valeur est masquée
/// et ne s'affiche/copie qu'après Touch ID / Face ID / mot de passe.
struct APIKeysView: View {
    private let service = VaultCategory.apiKey.service

    @State private var items: [KeychainService.APIKey] = []
    @State private var showingAdd = false
    @State private var editing: KeychainService.APIKey?

    var body: some View {
        List {
            Section {
                if items.isEmpty {
                    Text("Aucune clé. Ajoutez-en une avec le bouton +.")
                        .foregroundStyle(.secondary)
                }
                ForEach(items) { key in
                    row(key)
                }
            } header: {
                Text("Vault partagé (Keychain macOS · service « ClaudeVault »)")
            } footer: {
                Text("La référence aide à distinguer plusieurs clés d'un même service "
                     + "(Stripe démo/prod, projets). Claude lit une clé par son nom via get_api_key.")
                    .font(.caption)
            }
        }
        .listStyle(.inset)
        .navigationTitle("Clés API")
        .toolbar {
            ToolbarItem {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
                    .help("Ajouter une clé")
            }
        }
        .onAppear(perform: reload)
        .sheet(isPresented: $showingAdd, onDismiss: reload) {
            APIKeyEditSheet(service: service, existing: nil)
        }
        .sheet(item: $editing, onDismiss: reload) { key in
            APIKeyEditSheet(service: service, existing: key)
        }
    }

    private func row(_ key: KeychainService.APIKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill").foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(key.name).font(.body.weight(.medium))
                    if !key.reference.isEmpty {
                        Text(key.reference)
                            .font(.caption).foregroundStyle(.tint)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(.tint.opacity(0.12), in: Capsule())
                    }
                }
                SecretReveal(reason: "Afficher la clé « \(key.name) »") {
                    KeychainService.get(name: key.name)
                }
            }
            Spacer(minLength: 8)
            Button { editing = key } label: { Image(systemName: "pencil") }
                .buttonStyle(.borderless).help("Éditer")
            Button(role: .destructive) {
                KeychainService.delete(name: key.name); reload()
            } label: { Image(systemName: "trash") }
                .buttonStyle(.borderless).help("Supprimer")
        }
        .padding(.vertical, 4)
    }

    private func reload() {
        items = KeychainService.listItems()
        KeychainService.exportIndex()
    }
}

/// Feuille d'ajout / édition d'une clé API.
private struct APIKeyEditSheet: View {
    let service: String
    let existing: KeychainService.APIKey?
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var reference = ""
    @State private var value = ""          // saisie (ajout) ou remplacement (édition)

    private var isEdit: Bool { existing != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEdit ? "Éditer la clé" : "Nouvelle clé API")
                .font(.title3.weight(.semibold))
            Form {
                TextField("Nom", text: $name, prompt: Text("STRIPE_PROD_PROJET_X"))
                TextField("Référence (optionnelle)", text: $reference,
                          prompt: Text("Stripe — Production — Projet X"))
                if isEdit, let existing {
                    LabeledContent("Valeur") {
                        SecretReveal(reason: "Afficher la clé « \(existing.name) »") {
                            KeychainService.get(name: existing.name)
                        }
                    }
                    SecureField("Remplacer la valeur (optionnel)", text: $value,
                                prompt: Text("laisser vide pour ne pas changer"))
                } else {
                    SecureField("Valeur", text: $value, prompt: Text("sk_live_…"))
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Annuler") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Enregistrer") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            if let existing {
                name = existing.name
                reference = existing.reference
            }
        }
    }

    private var canSave: Bool {
        let hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        return isEdit ? hasName : (hasName && !value.isEmpty)
    }

    private func save() {
        if let existing {
            KeychainService.editAPIKey(
                oldName: existing.name, newName: name, reference: reference,
                newValue: value.isEmpty ? nil : value)
        } else {
            KeychainService.set(name: name, value: value, reference: reference)
        }
        dismiss()
    }
}
