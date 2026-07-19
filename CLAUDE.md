# ClaudeVault — Spécification de projet

## Vue d'ensemble

ClaudeVault est une application macOS native (SwiftUI) couplée à un serveur MCP (Model Context Protocol) permettant de gérer des "profils" de mémoire pour Claude (Desktop et Claude Code). Chaque profil correspond à un domaine de vie/activité (ex: Business IA, Voyages, Écriture, Code) avec son propre dossier de fichiers `.md`, isolé des autres profils pour éviter de surcharger le contexte de Claude et réduire la consommation de tokens.

L'app doit être installable en une étape par un utilisateur non technique (ex: conjoint(e)), verrouillée par l'authentification macOS (mot de passe de session / Touch ID), et fonctionner comme un "second brain" qui se met à jour automatiquement.

## Objectifs clés

1. Remplacer Obsidian (jugé trop lourd et pénible à connecter à Claude) par une solution native, simple, dédiée à Claude.
2. Isoler la mémoire par profil pour éviter la pollution de contexte (ex: un projet de code n'a jamais accès aux notes Voyages).
3. Un seul vault de clés API partagé entre tous les profils, stocké de façon sécurisée (Keychain macOS), pas en `.env` en clair.
4. Interface graphique minimaliste, style Apple (Finder/Notes.app), pour créer des profils et gérer les fichiers `.md` sans terminal.
5. Verrouillage par mot de passe/Touch ID du Mac (LocalAuthentication), pour un usage multi-utilisateur (ex: l'auteur + son épouse, chacun avec sa propre session macOS).
6. Installation ultra simple : app `.app`/`.dmg` glissée dans Applications + serveur MCP installé via Claude Desktop Extension (`.dtx`) en un clic, sans édition manuelle de JSON.
7. Mémoire évolutive type "second brain" : Claude met à jour quotidiennement/à chaque session le fichier mémoire du profil actif, en résumant les nouveaux éléments importants, sans jamais dépasser ~5000 tokens par profil pour rester économique.

## Architecture technique

### 1. Application macOS (SwiftUI)

- Fenêtre principale avec sidebar (liste des profils) + zone centrale (liste des fichiers `.md` du profil sélectionné, style Finder/Notes.app).
- Bouton "+" pour créer un profil : nom, description courte, sélection du dossier disque via `NSOpenPanel`.
- Vue fichiers : lister, créer, renommer, supprimer, prévisualiser les fichiers `.md` d'un profil (via `FileManager`).
- Onglet séparé "Clés API" : liste des clés (nom + valeur masquée par défaut, affichage à la demande), stockage/lecture via Keychain Services (pas de fichier `.env` en clair).
- Verrouillage à l'ouverture de l'app et au retour au premier plan (`scenePhase`) via `LocalAuthentication`, policy `deviceOwnerAuthentication` (accepte mot de passe macOS ou biométrie, pas seulement Touch ID).
- Design : SwiftUI natif, `NavigationSplitView`, couleurs/typo système (SF Pro, `.regularMaterial`), pas de dépendances UI tierces.
- L'app écrit sa configuration dans `~/.vault-mcp/profiles.json` (source de vérité partagée avec le serveur MCP).

### 2. Format de configuration (`~/.vault-mcp/profiles.json`)

```json
{
  "profiles": [
    {
      "id": "business-ia",
      "name": "Business IA",
      "path": "/Users/alexandrebruneau/Vault/Business-IA",
      "description": "Projets SaaS, clients, roadmap produit",
      "memoryFile": "memory.md",
      "lastUpdated": "2026-07-19T00:00:00Z"
    },
    {
      "id": "voyages",
      "name": "Voyages",
      "path": "/Users/alexandrebruneau/Vault/Voyages",
      "description": "Carnets de voyage, préférences, projets de voyage",
      "memoryFile": "memory.md",
      "lastUpdated": "2026-07-19T00:00:00Z"
    }
  ]
}
```

Chaque dossier de profil contient un fichier `memory.md` (mémoire condensée, second brain) et un sous-dossier `notes/` pour les fichiers `.md` bruts.

### 3. Serveur MCP (Node.js / TypeScript, SDK MCP officiel)

Outils exposés à Claude :

- `list_profiles()` — retourne la liste des profils disponibles avec description courte.
- `set_active_profile(profileId)` — définit le profil actif pour la session en cours.
- `read_notes(profileId)` — lit les fichiers `.md` du dossier `notes/` du profil.
- `read_memory(profileId)` — lit le fichier `memory.md` condensé du profil (chargé en priorité, avant les notes brutes).
- `write_note(profileId, filename, content)` — crée/modifie un fichier `.md` dans `notes/`.
- `update_profile_memory(profileId, summary)` — ajoute un résumé condensé à `memory.md`, en respectant une limite de ~5000 tokens (résumer/compacter l'existant si nécessaire).
- `get_api_key(keyName)` — récupère une clé API depuis le Keychain macOS (via un helper CLI Swift ou la commande `security find-generic-password`), vault unique partagé entre tous les profils.

Contraintes serveur :
- Écrit en Node.js/TypeScript avec le SDK MCP officiel (`@modelcontextprotocol/sdk`).
- Lit `~/.vault-mcp/profiles.json` à chaque appel (pas de cache long pour rester synchronisé avec l'app).
- Ne retourne jamais une clé API en clair dans un message si une politique de sécurité stricte est activée (paramètre configurable ; par défaut, mode simple sans masquage puisque le vault est local et personnel).

### 4. Instructions système pour Claude (comportement "second brain")

Ajouter au prompt système du serveur MCP ou au `CLAUDE.md` racine :

> À chaque fin de session ou tous les ~40 messages échangés sur un profil actif, résume les informations nouvelles et importantes de la conversation, puis appelle `update_profile_memory` pour les ajouter de façon condensée au fichier mémoire du profil. Ne dépasse jamais ~5000 tokens dans `memory.md` : si la limite est atteinte, compacte l'existant en gardant uniquement l'essentiel avant d'ajouter le nouveau résumé. Charge toujours `read_memory` avant `read_notes` pour économiser des tokens : ne lis les notes brutes que si la mémoire condensée ne suffit pas à répondre.

### 5. Distribution/installation

- App macOS : build Xcode signé, distribué en `.dmg` (glisser dans Applications).
- Serveur MCP : packagé en Claude Desktop Extension (`.dtx`) pour installation en un clic dans Claude Desktop, sans édition manuelle de configuration JSON.
- Pour Claude Code : ajouter le serveur MCP via `claude mcp add` ou configuration du dossier `.claude/` du projet actif, avec option `--add-dir` pour pointer dynamiquement vers un profil.
- Multi-utilisateur (ex: épouse) : chaque utilisateur macOS a sa propre session, donc son propre `~/.vault-mcp/profiles.json` et son propre Keychain — aucune configuration croisée nécessaire.

## Étapes de développement suggérées

1. Créer le projet Xcode SwiftUI (macOS app target).
2. Implémenter le verrouillage `LocalAuthentication` (écran de lock au démarrage + retour au premier plan).
3. Implémenter la sidebar profils + CRUD sur `profiles.json`.
4. Implémenter la vue fichiers (liste, création, édition, suppression de `.md`).
5. Implémenter l'onglet Clés API avec Keychain Services.
6. Créer le serveur MCP Node.js/TypeScript avec les outils listés ci-dessus.
7. Tester le serveur MCP localement avec Claude Desktop (config manuelle d'abord).
8. Packager le serveur MCP en Desktop Extension (`.dtx`).
9. Build et signature de l'app SwiftUI en `.dmg`.
10. Rédiger un `README.md` d'installation en 3 étapes maximum pour un utilisateur non technique.

## Contraintes non fonctionnelles

- Tout doit rester 100% local (pas de cloud, pas de synchronisation externe).
- Aucune dépendance UI tierce dans l'app SwiftUI (rester natif Apple).
- Le serveur MCP doit démarrer en moins d'une seconde et ne consommer aucune ressource significative en idle.
- Le design doit respecter les conventions macOS (Human Interface Guidelines) : sidebar, liste, matériaux translucides, typographie système.
