import SwiftUI

/// Un enregistrement du coffre (compte + métadonnées non sensibles ; secret exclu).
struct VaultRecord: Identifiable, Hashable {
    let account: String
    let metadata: [String: String]
    var id: String { account }
}

private func loadRecords(_ category: VaultCategory) -> [VaultRecord] {
    KeychainService.listRecords(service: category.service)
        .map { VaultRecord(account: $0.account, metadata: $0.metadata) }
}

// MARK: - Email

struct EmailVaultView: View {
    private let service = VaultCategory.email.service
    @State private var records: [VaultRecord] = []
    @State private var showingAdd = false
    @State private var editing: VaultRecord?

    var body: some View {
        List {
            Section {
                if records.isEmpty {
                    Text("Aucune boîte email. Ajoutez-en une avec le bouton +.")
                        .foregroundStyle(.secondary)
                }
                ForEach(records) { r in
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.account).font(.body.weight(.medium))
                            let servers = [serverLabel("POP", r.metadata["pop"]),
                                           serverLabel("SMTP", r.metadata["smtp"])]
                                .compactMap { $0 }.joined(separator: "  ·  ")
                            if !servers.isEmpty {
                                Text(servers).font(.caption).foregroundStyle(.secondary)
                            }
                            SecretReveal(reason: "Afficher le mot de passe de \(r.account)") {
                                KeychainService.revealRecord(service: service, account: r.account)
                            }
                        }
                        Spacer(minLength: 8)
                        VaultRowActions(onEdit: { editing = r },
                                        onDelete: { KeychainService.deleteRecord(service: service, account: r.account); reload() })
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Boîtes email (Keychain — accessible à ClaudeVault uniquement)")
            } footer: {
                Text("Le mot de passe ne s'affiche/copie qu'après Touch ID / Face ID / mot de passe.")
                    .font(.caption)
            }
        }
        .listStyle(.inset)
        .navigationTitle("Email")
        .toolbar { ToolbarItem { Button { showingAdd = true } label: { Image(systemName: "plus") }.help("Ajouter une boîte") } }
        .onAppear(perform: reload)
        .sheet(isPresented: $showingAdd, onDismiss: reload) { EmailEditSheet(service: service, existing: nil) }
        .sheet(item: $editing, onDismiss: reload) { r in EmailEditSheet(service: service, existing: r) }
    }

    private func reload() { records = loadRecords(.email) }
    private func serverLabel(_ p: String, _ v: String?) -> String? {
        guard let v, !v.isEmpty else { return nil }; return "\(p) \(v)"
    }
}

private struct EmailEditSheet: View {
    let service: String
    let existing: VaultRecord?
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var password = ""
    @State private var pop = ""
    @State private var smtp = ""
    private var isEdit: Bool { existing != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEdit ? "Éditer la boîte email" : "Nouvelle boîte email")
                .font(.title3.weight(.semibold))
            Form {
                TextField("Adresse email", text: $address, prompt: Text("moi@exemple.com"))
                if isEdit, let existing {
                    LabeledContent("Mot de passe") {
                        SecretReveal(reason: "Afficher le mot de passe de \(existing.account)") {
                            KeychainService.revealRecord(service: service, account: existing.account)
                        }
                    }
                    SecureField("Remplacer le mot de passe (optionnel)", text: $password,
                                prompt: Text("laisser vide pour ne pas changer"))
                } else {
                    SecureField("Mot de passe", text: $password, prompt: Text("••••••••"))
                }
                TextField("Serveur POP", text: $pop, prompt: Text("pop.exemple.com:995"))
                TextField("Serveur SMTP", text: $smtp, prompt: Text("smtp.exemple.com:465"))
            }
            .formStyle(.grouped)
            SheetButtons(canSave: canSave, onCancel: { dismiss() }, onSave: save)
        }
        .padding(24).frame(width: 480)
        .onAppear {
            if let existing {
                address = existing.account
                pop = existing.metadata["pop"] ?? ""
                smtp = existing.metadata["smtp"] ?? ""
            }
        }
    }

    private var canSave: Bool {
        let a = !address.trimmingCharacters(in: .whitespaces).isEmpty
        return isEdit ? a : (a && !password.isEmpty)
    }

    private func save() {
        let addr = address.trimmingCharacters(in: .whitespaces)
        let meta = ["pop": pop.trimmingCharacters(in: .whitespaces),
                    "smtp": smtp.trimmingCharacters(in: .whitespaces)]
        if let existing {
            if existing.account != addr {
                KeychainService.renameRecord(service: service, from: existing.account, to: addr)
            }
            KeychainService.updateRecord(service: service, account: addr,
                                         secret: password.isEmpty ? nil : password, metadata: meta)
        } else {
            KeychainService.saveRecord(service: service, account: addr, secret: password, metadata: meta)
        }
        dismiss()
    }
}

// MARK: - Recovery

struct RecoveryVaultView: View {
    private let service = VaultCategory.recovery.service
    @State private var records: [VaultRecord] = []
    @State private var showingAdd = false
    @State private var editing: VaultRecord?

    var body: some View {
        List {
            Section {
                if records.isEmpty {
                    Text("Aucun code de récupération. Ajoutez-en avec le bouton +.")
                        .foregroundStyle(.secondary)
                }
                ForEach(records) { r in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "lifepreserver.fill").foregroundStyle(.secondary)
                            Text(r.account).font(.body.weight(.medium))
                            Spacer()
                            VaultRowActions(onEdit: { editing = r },
                                            onDelete: { KeychainService.deleteRecord(service: service, account: r.account); reload() })
                        }
                        SecretReveal(reason: "Afficher les codes « \(r.account) »", multiline: true) {
                            KeychainService.revealRecord(service: service, account: r.account)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Codes de récupération (Keychain — accessible à ClaudeVault uniquement)")
            } footer: {
                Text("Les codes ne s'affichent/copient qu'après Touch ID / Face ID / mot de passe.")
                    .font(.caption)
            }
        }
        .listStyle(.inset)
        .navigationTitle("Recovery")
        .toolbar { ToolbarItem { Button { showingAdd = true } label: { Image(systemName: "plus") }.help("Ajouter des codes") } }
        .onAppear(perform: reload)
        .sheet(isPresented: $showingAdd, onDismiss: reload) { RecoveryEditSheet(service: service, existing: nil) }
        .sheet(item: $editing, onDismiss: reload) { r in RecoveryEditSheet(service: service, existing: r) }
    }

    private func reload() { records = loadRecords(.recovery) }
}

private struct RecoveryEditSheet: View {
    let service: String
    let existing: VaultRecord?
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var codes = ""
    private var isEdit: Bool { existing != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEdit ? "Éditer les codes" : "Nouveaux codes de récupération")
                .font(.title3.weight(.semibold))
            Form {
                TextField("Libellé", text: $label, prompt: Text("GitHub — codes 2FA"))
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEdit ? "Remplacer les codes (optionnel)" : "Codes")
                        .font(.callout).foregroundStyle(.secondary)
                    TextEditor(text: $codes)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 130)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                }
            }
            .formStyle(.grouped)
            SheetButtons(canSave: canSave, onCancel: { dismiss() }, onSave: save)
        }
        .padding(24).frame(width: 480)
        .onAppear { if let existing { label = existing.account } }
    }

    private var canSave: Bool {
        let l = !label.trimmingCharacters(in: .whitespaces).isEmpty
        return isEdit ? l : (l && !codes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func save() {
        let lbl = label.trimmingCharacters(in: .whitespaces)
        if let existing {
            if existing.account != lbl {
                KeychainService.renameRecord(service: service, from: existing.account, to: lbl)
            }
            let trimmed = codes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                KeychainService.updateRecord(service: service, account: lbl, secret: codes, metadata: nil)
            }
        } else {
            KeychainService.saveRecord(service: service, account: lbl, secret: codes, metadata: [:])
        }
        dismiss()
    }
}

// MARK: - Database

struct DatabaseVaultView: View {
    private let service = VaultCategory.database.service
    @State private var records: [VaultRecord] = []
    @State private var showingAdd = false
    @State private var editing: VaultRecord?

    var body: some View {
        List {
            Section {
                if records.isEmpty {
                    Text("Aucune base. Ajoutez-en une avec le bouton +.")
                        .foregroundStyle(.secondary)
                }
                ForEach(records) { r in
                    HStack(spacing: 12) {
                        Image(systemName: "cylinder.split.1x2.fill").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.metadata["db"] ?? r.account).font(.body.weight(.medium))
                            if let p = r.metadata["provider"], !p.isEmpty {
                                Text(p).font(.caption).foregroundStyle(.secondary)
                            }
                            SecretReveal(reason: "Afficher le mot de passe de \(r.account)") {
                                KeychainService.revealRecord(service: service, account: r.account)
                            }
                        }
                        Spacer(minLength: 8)
                        VaultRowActions(onEdit: { editing = r },
                                        onDelete: { KeychainService.deleteRecord(service: service, account: r.account); reload() })
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Bases de données (Keychain — accessible à ClaudeVault uniquement)")
            } footer: {
                Text("Le mot de passe ne s'affiche/copie qu'après Touch ID / Face ID / mot de passe.")
                    .font(.caption)
            }
        }
        .listStyle(.inset)
        .navigationTitle("Database")
        .toolbar { ToolbarItem { Button { showingAdd = true } label: { Image(systemName: "plus") }.help("Ajouter une base") } }
        .onAppear(perform: reload)
        .sheet(isPresented: $showingAdd, onDismiss: reload) { DatabaseEditSheet(service: service, existing: nil) }
        .sheet(item: $editing, onDismiss: reload) { r in DatabaseEditSheet(service: service, existing: r) }
    }

    private func reload() { records = loadRecords(.database) }
}

private struct DatabaseEditSheet: View {
    let service: String
    let existing: VaultRecord?
    @Environment(\.dismiss) private var dismiss
    @State private var provider = ""
    @State private var dbName = ""
    @State private var password = ""
    private var isEdit: Bool { existing != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEdit ? "Éditer la base" : "Nouvelle base de données")
                .font(.title3.weight(.semibold))
            Form {
                TextField("Fournisseur", text: $provider, prompt: Text("Supabase"))
                TextField("Nom de la base", text: $dbName, prompt: Text("prod-app"))
                if isEdit, let existing {
                    LabeledContent("Mot de passe") {
                        SecretReveal(reason: "Afficher le mot de passe de \(existing.account)") {
                            KeychainService.revealRecord(service: service, account: existing.account)
                        }
                    }
                    SecureField("Remplacer le mot de passe (optionnel)", text: $password,
                                prompt: Text("laisser vide pour ne pas changer"))
                } else {
                    SecureField("Mot de passe", text: $password, prompt: Text("••••••••"))
                }
            }
            .formStyle(.grouped)
            SheetButtons(canSave: canSave, onCancel: { dismiss() }, onSave: save)
        }
        .padding(24).frame(width: 480)
        .onAppear {
            if let existing {
                provider = existing.metadata["provider"] ?? ""
                dbName = existing.metadata["db"] ?? ""
            }
        }
    }

    private func account(_ prov: String, _ db: String) -> String {
        "\(prov) · \(db)".trimmingCharacters(in: .whitespaces)
    }
    private var canSave: Bool {
        let ok = !provider.trimmingCharacters(in: .whitespaces).isEmpty
              && !dbName.trimmingCharacters(in: .whitespaces).isEmpty
        return isEdit ? ok : (ok && !password.isEmpty)
    }

    private func save() {
        let prov = provider.trimmingCharacters(in: .whitespaces)
        let db = dbName.trimmingCharacters(in: .whitespaces)
        let acc = account(prov, db)
        let meta = ["provider": prov, "db": db]
        if let existing {
            if existing.account != acc {
                KeychainService.renameRecord(service: service, from: existing.account, to: acc)
            }
            KeychainService.updateRecord(service: service, account: acc,
                                         secret: password.isEmpty ? nil : password, metadata: meta)
        } else {
            KeychainService.saveRecord(service: service, account: acc, secret: password, metadata: meta)
        }
        dismiss()
    }
}

// MARK: - Composants partagés

private struct VaultRowActions: View {
    let onEdit: () -> Void
    let onDelete: () -> Void
    var body: some View {
        Button(action: onEdit) { Image(systemName: "pencil") }
            .buttonStyle(.borderless).help("Éditer")
        Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
            .buttonStyle(.borderless).help("Supprimer")
    }
}

private struct SheetButtons: View {
    let canSave: Bool
    let onCancel: () -> Void
    let onSave: () -> Void
    var body: some View {
        HStack {
            Spacer()
            Button("Annuler", action: onCancel).keyboardShortcut(.cancelAction)
            Button("Enregistrer", action: onSave)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
        }
    }
}
