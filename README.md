<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="ClaudeVault" />
</p>

# ClaudeVault

**Le « second brain » de Claude, sur votre Mac.**

ClaudeVault donne à Claude (Desktop et Claude Code) une **mémoire par profil** : un
dossier isolé par domaine de vie (Business IA, Voyages, Écriture, Code…), pour éviter
de mélanger les contextes et gaspiller des tokens. Une petite app macOS gère les
profils et un **vault de clés API** protégé par le Keychain, verrouillé par Touch ID /
mot de passe de session. Un serveur MCP expose le tout à Claude.

Tout est **100 % local** : aucun cloud, aucune synchronisation externe.

---

## Ce que ça fait

- **Profils isolés** : chaque profil = un dossier avec un `memory.md` condensé + un
  sous-dossier `notes/` de fichiers `.md`.
- **Mémoire évolutive** : Claude résume automatiquement les nouveautés dans `memory.md`
  (plafonné à ~5000 tokens pour rester économique).
- **Vault de clés API unique**, partagé entre tous les profils, stocké dans le
  **Keychain macOS** (jamais en `.env` en clair).
- **Verrouillage** de l'app par Touch ID ou mot de passe macOS.

---

## Installation en 3 étapes

### 1. Installer l'app ClaudeVault

**Option A — Télécharger le `.dmg` (le plus simple)**

- Récupérez `ClaudeVault.dmg` depuis la page
  [Releases](https://github.com/AlessandroB1989/ClaudeVault/releases).
- Ouvrez-le, glissez **ClaudeVault** dans **Applications**.
- Au **premier lancement** : clic droit sur l'app → **Ouvrir** → **Ouvrir**
  (l'app est signée ad-hoc mais pas notarisée ; cette étape n'est nécessaire
  qu'une fois).

**Option B — Compiler depuis les sources**

- Ouvrez `macos-app/ClaudeVault.xcodeproj` dans **Xcode**, puis **▶︎ Run** (`Cmd+R`).
- Ou en ligne de commande : `bash macos-app/scripts/build-dmg.sh` → génère
  `dist/ClaudeVault.dmg`.

> À la première ouverture, macOS demande Touch ID ou votre mot de passe de session :
> c'est le verrou de ClaudeVault.

### 2. Créer un profil et vos clés API

- Dans l'app, cliquez **+** → donnez un **nom**, une **description**, et choisissez un
  **dossier** (ex. `~/Vault/Business-IA`). Le dossier et son `memory.md` sont créés
  automatiquement, et `~/.vault-mcp/profiles.json` est mis à jour.
- Onglet **Clés API** → **+** pour ajouter vos clés (ex. `OPENAI_API_KEY`). Elles vont
  directement dans le Keychain.

### 3. Brancher le serveur MCP à Claude

**Claude Desktop (recommandé, un clic) :**

```bash
cd mcp-server
bash scripts/pack-dxt.sh        # génère dist/claudevault.mcpb
```

Double-cliquez `dist/claudevault.mcpb` : Claude Desktop propose l'installation en un clic.

**Claude Code :**

```bash
cd mcp-server && npm install && npm run build
claude mcp add claudevault -- node "$(pwd)/build/index.js"
```

C'est tout. Demandez à Claude : *« liste mes profils ClaudeVault »*.

---

## Comment Claude utilise la mémoire

Le serveur expose 7 outils : `list_profiles`, `set_active_profile`, `read_memory`,
`read_notes`, `write_note`, `update_profile_memory`, `get_api_key`.

Consigne de comportement « second brain » (déjà dans le `CLAUDE.md` du projet) :

> À chaque fin de session (ou tous les ~40 messages) sur un profil actif, résume les
> éléments nouveaux et importants puis appelle `update_profile_memory`. Ne dépasse
> jamais ~5000 tokens dans `memory.md`. Charge toujours `read_memory` avant
> `read_notes` pour économiser des tokens.

---

## Architecture

```
ClaudeVault/
├── CLAUDE.md                 # spécification + consigne "second brain"
├── README.md                 # ce fichier
├── config/
│   └── profiles.example.json # exemple de ~/.vault-mcp/profiles.json
├── mcp-server/               # serveur MCP Node/TypeScript
│   ├── src/                  # config, keychain, notes, memory, index (outils)
│   ├── test/                 # tests d'intégration bout-en-bout (10/10)
│   ├── manifest.json         # descripteur Desktop Extension (.mcpb)
│   ├── claude_desktop_config.example.json  # config manuelle (fallback)
│   └── scripts/pack-dxt.sh   # packaging un clic
└── macos-app/                # app SwiftUI native
    ├── ClaudeVault.xcodeproj
    └── ClaudeVault/          # App, Models, Security, Views
```

**Source de vérité partagée** : `~/.vault-mcp/profiles.json`, écrit par l'app et relu
par le serveur MCP à chaque appel (toujours synchro).

**Keychain** : l'app enregistre les clés sous le service `ClaudeVault` avec l'option
« accessible par vos applications », pour que Claude les lise sans redemander
l'autorisation à chaque fois.

---

## Configuration manuelle (sans l'app)

Si vous voulez tester le serveur avant l'app :

```bash
# 1. Config des profils
mkdir -p ~/.vault-mcp
cp config/profiles.example.json ~/.vault-mcp/profiles.json
#    …puis adaptez les chemins "path" à vos dossiers réels.

# 2. Une clé API dans le Keychain (option -A = lisible par Claude sans pop-up)
security add-generic-password -s "ClaudeVault" -a "OPENAI_API_KEY" -w "sk-…" -U -A

# 3. Config Claude Desktop
#    copiez mcp-server/claude_desktop_config.example.json dans :
#    ~/Library/Application Support/Claude/claude_desktop_config.json
#    (en remplaçant /CHEMIN/VERS/ par le chemin réel)
```

---

## Développement

```bash
# Serveur MCP
cd mcp-server
npm install
npm run build       # compile TypeScript → build/
npm test            # 10 tests d'intégration (profils, notes, mémoire, keychain)

# App macOS (typecheck sans lancer Xcode)
cd ../macos-app
swiftc -typecheck -sdk "$(xcrun --show-sdk-path)" \
  -target arm64-apple-macos14.0 $(find ClaudeVault -name '*.swift')
```

Prérequis : macOS 14+, Node 18+, Xcode 16+ (pour builder l'app).

---

## Notes de sécurité

- Aucune donnée ne quitte votre Mac.
- Chaque utilisateur macOS a sa propre session : son `~/.vault-mcp/` et son Keychain.
  Rien n'est partagé entre comptes (idéal pour un usage à deux).
- Les clés API sont dans le Keychain, pas dans des fichiers. L'option d'accès large
  (`-A`) évite les pop-ups répétées ; retirez-la si vous préférez confirmer chaque
  accès (voir `KeychainService.swift`).

---

## Licence & mentions

Sous licence [MIT](LICENSE).

> **Non affilié à Anthropic.** ClaudeVault est un projet indépendant, open source,
> qui s'interface avec Claude via le protocole MCP. « Claude » et « Anthropic » sont
> des marques d'Anthropic, PBC, utilisées ici à des fins descriptives uniquement.
