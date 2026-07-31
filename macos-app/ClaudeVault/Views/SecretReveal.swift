import SwiftUI
import AppKit

/// Affiche un secret masqué avec deux actions protégées par Touch ID / Face ID /
/// mot de passe : Afficher (œil) et Copier. Le secret n'est lu qu'après auth.
struct SecretReveal: View {
    /// Raison affichée dans la fenêtre d'authentification.
    let reason: String
    var multiline: Bool = false
    /// Lit le secret (appelé seulement après authentification réussie).
    let fetch: () -> String?

    @State private var revealed: String?
    @State private var busy = false
    @State private var copied = false

    var body: some View {
        if multiline {
            VStack(alignment: .leading, spacing: 6) {
                HStack { buttons }
                if let revealed {
                    Text(revealed)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                } else {
                    Text("•••• •••• ••••")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            HStack(spacing: 8) {
                Text(revealed ?? "••••••••••••")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(revealed == nil ? .secondary : .primary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                buttons
            }
        }
    }

    @ViewBuilder private var buttons: some View {
        if busy {
            ProgressView().controlSize(.small)
        } else {
            Button { toggle() } label: {
                Image(systemName: revealed == nil ? "eye" : "eye.slash")
            }
            .buttonStyle(.borderless)
            .help(revealed == nil ? "Afficher (Touch ID)" : "Masquer")

            Button { copy() } label: {
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    .foregroundStyle(copied ? Color.green : Color.accentColor)
            }
            .buttonStyle(.borderless)
            .help("Copier (Touch ID)")
        }
    }

    private func toggle() {
        if revealed != nil { revealed = nil; return }
        busy = true
        Task {
            let ok = await Biometrics.authenticate(reason: reason)
            if ok { revealed = fetch() }
            busy = false
        }
    }

    private func copy() {
        busy = true
        Task {
            let ok = await Biometrics.authenticate(reason: reason)
            if ok, let s = fetch() {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(s, forType: .string)
                copied = true
                try? await Task.sleep(nanoseconds: 1_300_000_000)
                copied = false
            }
            busy = false
        }
    }
}
