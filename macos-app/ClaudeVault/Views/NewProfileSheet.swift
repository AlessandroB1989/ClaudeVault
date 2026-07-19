import SwiftUI
import AppKit

/// Feuille de création d'un profil : nom, description, dossier disque (NSOpenPanel).
struct NewProfileSheet: View {
    @EnvironmentObject private var store: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var folder: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nouveau profil")
                .font(.title3.weight(.semibold))

            Form {
                TextField("Nom", text: $name, prompt: Text("Business IA"))
                TextField(
                    "Description",
                    text: $description,
                    prompt: Text("Projets SaaS, clients, roadmap")
                )

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dossier")
                        Text(folder?.path ?? "Aucun dossier sélectionné")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button("Choisir…") { chooseFolder() }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Annuler") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Créer") { create() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || folder == nil)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choisir ce dossier"
        panel.message = "Sélectionnez (ou créez) le dossier qui contiendra ce profil."
        if panel.runModal() == .OK {
            folder = panel.url
        }
    }

    private func create() {
        guard let folder else { return }
        if store.addProfile(name: name, description: description, folder: folder) != nil {
            dismiss()
        }
    }
}
