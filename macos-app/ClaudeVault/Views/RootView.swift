import SwiftUI

/// Racine : affiche l'écran de verrouillage tant que l'app n'est pas
/// déverrouillée, sinon l'interface principale.
struct RootView: View {
    @EnvironmentObject private var lock: AppLock

    var body: some View {
        ZStack {
            ContentView()
                .disabled(!lock.isUnlocked)
                .blur(radius: lock.isUnlocked ? 0 : 18)

            if !lock.isUnlocked {
                LockView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: lock.isUnlocked)
    }
}
