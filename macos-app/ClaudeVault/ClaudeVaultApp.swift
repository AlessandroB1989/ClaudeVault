import SwiftUI

@main
struct ClaudeVaultApp: App {
    @StateObject private var store = ProfileStore()
    @StateObject private var lock = AppLock()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(lock)
                .frame(minWidth: 820, minHeight: 520)
                .onAppear {
                    // Verrou à l'ouverture de l'app.
                    lock.authenticate()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        // Retour au premier plan : redemander l'auth si verrouillé.
                        lock.authenticate()
                    case .background:
                        // Reverrouille dès que l'app passe en arrière-plan.
                        lock.lock()
                    default:
                        break
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Verrouiller ClaudeVault") { lock.lock() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}
