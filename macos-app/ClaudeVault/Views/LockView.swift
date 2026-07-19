import SwiftUI

/// Écran de verrouillage plein cadre, style Apple.
struct LockView: View {
    @EnvironmentObject private var lock: AppLock

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("ClaudeVault est verrouillé")
                .font(.title2.weight(.semibold))

            Text("Authentifiez-vous avec Touch ID ou le mot de passe de votre session macOS.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            if lock.isAuthenticating {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    lock.authenticate()
                } label: {
                    Label("Déverrouiller", systemImage: "touchid")
                        .frame(minWidth: 160)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            if let err = lock.lastError {
                Text(err)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}
