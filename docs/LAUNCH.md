# Kit de lancement — ClaudeVault

Tout le prêt-à-copier pour publier ClaudeVault et le faire remarquer.
Remplace `AlessandroB1989` par ton pseudo GitHub une fois le repo créé.

---

## 1. Description courte (repo GitHub « About » / annuaires)

> Native macOS second-brain for Claude: isolated per-profile memory over MCP,
> with a shared Keychain vault for API keys. One-click Desktop Extension.

FR :

> Second-brain macOS natif pour Claude : mémoire isolée par profil via MCP, plus
> un vault de clés API dans le Keychain. Extension Desktop en un clic.

Topics GitHub suggérés : `mcp` `model-context-protocol` `claude` `macos` `swiftui`
`second-brain` `memory` `keychain` `desktop-extension`

---

## 2. Soumission aux annuaires MCP

### awesome-mcp-servers (punaise-liste communautaire)

Ligne à ajouter (section Knowledge / Memory) :

```markdown
- [ClaudeVault](https://github.com/AlessandroB1989/ClaudeVault) 🍎 — Native macOS
  second-brain for Claude: isolated per-profile memory + Keychain-backed API key
  vault, installable as a one-click Desktop Extension (.mcpb).
```

### Registre officiel MCP (modelcontextprotocol)

Le serveur est déjà décrit dans `mcp-server/manifest.json`. Pour une soumission,
mets en avant :
- 7 outils : `list_profiles`, `set_active_profile`, `read_memory`, `read_notes`,
  `write_note`, `update_profile_memory`, `get_api_key`
- Transport stdio, Node ≥ 18
- Packagé en Desktop Extension `.mcpb`

---

## 3. Post X / Twitter (thread)

**1/**
J'ai construit ClaudeVault : un « second brain » natif macOS pour Claude. 🧠🔒

Une mémoire *isolée par profil* (Business, Voyages, Code…) pour que Claude arrête
de tout mélanger — et un vault de clés API dans le Keychain. Open source, MIT.

🧵

**2/**
Le problème : une seule grosse mémoire pollue le contexte et brûle des tokens.

ClaudeVault donne à chaque domaine son dossier + un `memory.md` condensé
(plafonné ~5000 tokens). Claude charge la mémoire avant les notes brutes → moins
de tokens, plus de pertinence.

**3/**
Sous le capot :
• Serveur MCP (Node/TS) — 7 outils, 12/12 tests
• App SwiftUI native — Touch ID, arbo de dossiers, aperçu Markdown
• Clés API dans le Keychain (jamais en .env)
• Extension Desktop `.mcpb` → install en un clic

**4/**
100 % local, zéro cloud. Multi-utilisateur (chaque session macOS a son vault).

Repo 👉 github.com/AlessandroB1989/ClaudeVault
Retours bienvenus 🙏 #MCP #Claude #buildinpublic

---

## 4. Post LinkedIn

> J'ai open-sourcé **ClaudeVault** — un « second brain » natif macOS pour Claude.
>
> L'idée : arrêter de tout entasser dans une seule mémoire. Chaque domaine de vie
> (business, voyages, code…) obtient son profil isolé, avec un fichier mémoire
> condensé que Claude met à jour tout seul — sans jamais polluer le contexte des
> autres profils, ni gaspiller des tokens.
>
> Côté technique : un serveur MCP (Node/TypeScript, 7 outils, testé), une app
> SwiftUI native (verrouillage Touch ID, arborescence de projets, aperçu Markdown),
> et un vault de clés API dans le Keychain macOS. Le tout 100 % local, packagé en
> extension Desktop installable en un clic.
>
> C'est sous licence MIT, les contributions sont bienvenues 👇
> github.com/AlessandroB1989/ClaudeVault
>
> #MCP #Claude #macOS #OpenSource #IA

---

## 5. Plan de tournage du GIF de démo (vraie app + Claude, ~20 s)

But : montrer la boucle qui fait vendre — **mémoire isolée par profil** + **Claude
qui écrit dedans** via MCP.

### Préparation
- Fenêtre ClaudeVault ~1280×800, thème cohérent, infos perso masquées.
- **≥ 2 profils** déjà créés (ex. Business IA, Voyages) pour montrer l'isolation.
- **Claude Desktop** ouvert, MCP ClaudeVault connecté (teste avant : « liste mes
  profils ClaudeVault »).
- Idéalement, ClaudeVault et Claude Desktop côte à côte (ou plein écran, je recadre).

### Séquence
1. (0-3 s) ClaudeVault au premier plan → **déverrouillage Touch ID**.
2. (3-7 s) Clic **Business IA** → ses notes + `memory.md`. Puis clic **Voyages** →
   contenu différent → **l'isolation par profil se voit**. Reviens sur Business IA.
3. (7-14 s) Bascule vers **Claude Desktop** → tape :
   « Dans mon profil Business IA, note que le client Acme a signé, MVP le 30/07. »
   → Claude appelle **`write_note`** (la tool-call s'affiche).
4. (14-18 s) Retour dans ClaudeVault → le fichier **`clients/acme.md` apparaît** dans
   `notes/` → ouvre-le en **aperçu Markdown**.
5. (18-20 s) Optionnel : onglet **Clés API** (le vault Keychain).

### Enregistrement & remise
- `Cmd+Shift+5` → « Enregistrer une portion » → cadre → **Enregistrer** ; arrête via
  l'icône de la barre de menus. Sauvegarde en `demo.mov`.
- Fais des **pauses nettes** entre étapes (ça rend mieux en GIF), curseur visible.
- Envoie-moi `demo.mov` (dépose-le dans le dossier du projet ou sur le Bureau et
  donne-moi le chemin) → je m'occupe du **trim + optimisation + intégration README** :
  `bash tools/demo/make-gif.sh demo.mov docs/demo.gif`
  (je choisis le meilleur segment via `START`/`DURATION`).
