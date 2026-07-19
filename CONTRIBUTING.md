# Contribuer à ClaudeVault

Merci de vouloir aider ! ClaudeVault reste volontairement simple, natif et 100 % local.

## Démarrer

```bash
git clone https://github.com/AlessandroB1989/ClaudeVault.git
cd ClaudeVault

# Serveur MCP
cd mcp-server && npm install && npm run build && npm test   # 12/12 attendus

# App macOS (nécessite Xcode 16+)
open ../macos-app/ClaudeVault.xcodeproj   # ▶︎ Run
```

## Périmètre & principes

- **100 % local** : aucune dépendance cloud, aucune télémétrie.
- **App native** : pas de dépendance UI tierce (SwiftUI/AppKit uniquement).
- **Compat MCP ↔ app** : la source de vérité est `~/.vault-mcp/profiles.json` et le
  service Keychain `ClaudeVault`. Toute évolution de format doit rester lue/écrite
  identiquement des deux côtés.

## Avant d'ouvrir une PR

- Serveur : `npm run build` sans erreur et `npm test` au vert. Ajoute un test pour
  tout nouveau comportement d'outil.
- App : elle compile (`swiftc -typecheck …`, voir le README) et se lance.
- Garde les commits ciblés ; décris le *pourquoi* dans le message.

## Idées bienvenues

- Rendu Markdown : tableaux, cases à cocher `- [ ]`.
- Compteur de tokens en direct sur `memory.md`.
- Recherche plein-texte dans les notes.
- Export/import de profils.

## Signaler un bug

Ouvre une *issue* avec : version macOS, étapes de repro, et logs éventuels
(`~/Library/Logs` ou la console MCP). Merci 🙏
