#!/usr/bin/env bash
# Construit ClaudeVault.app puis l'emballe dans un .dmg (glisser → Applications).
# À lancer sur ta machine (Xcode requis).
#
# La compilation se fait dans un dossier TEMPORAIRE HORS du projet : si le repo
# est dans Google Drive/iCloud, compiler sur place casse la base de build
# (erreurs « disk I/O error »). Seul le .dmg final est écrit dans dist/.
#
# DEUX MODES, pilotés par variables d'environnement :
#
#  • Local (par défaut) — signature ad-hoc, aucun compte requis :
#        bash macos-app/scripts/build-dmg.sh
#    → l'app se lance en local ; 1er lancement : clic droit → Ouvrir.
#
#  • Distribution — Developer ID + notarisation (compte payant requis) :
#        SIGN_IDENTITY="Developer ID Application: … (TEAMID)" \
#        TEAM_ID="XXXXXXXXXX" \
#        NOTARY_PROFILE="claudevault-notary" \
#        bash macos-app/scripts/build-dmg.sh
#    → .dmg signé, notarisé, staplé : double-clic sans avertissement.
#
#    Pré-requis notarisation (une seule fois) :
#      1. Xcode ▸ Settings ▸ Accounts → certificat « Developer ID Application ».
#      2. Mot de passe d'app : https://account.apple.com → Connexion et sécurité.
#      3. xcrun notarytool store-credentials claudevault-notary \
#           --apple-id alexandre@baair.solutions --team-id XXXXXXXXXX
#
set -euo pipefail

cd "$(dirname "$0")/.."   # → macos-app/

PROJECT="ClaudeVault.xcodeproj"
SCHEME="ClaudeVault"
CONFIG="Release"
APP_NAME="ClaudeVault"
DIST_DIR="../dist"
DMG_OUT="${DIST_DIR}/${APP_NAME}.dmg"

# Signature : ad-hoc par défaut, Developer ID si SIGN_IDENTITY est fourni.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
TEAM_ID="${TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

# Dossier de build TEMPORAIRE hors du projet (évite les I/O errors Google Drive).
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ClaudeVault-build.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT
mkdir -p "$DIST_DIR"

# Si Xcode n'est pas l'outil par défaut (xcode-select → CommandLineTools),
# on le pointe le temps du build, sans sudo.
if ! xcodebuild -version >/dev/null 2>&1 && [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

if [ "$SIGN_IDENTITY" = "-" ]; then
  echo "▶︎ Build (${CONFIG}) — signature ad-hoc (local)…"
  xcodebuild \
    -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
    -derivedDataPath "$BUILD_DIR/dd" \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR/app" \
    CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="" \
    CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES \
    build
else
  echo "▶︎ Build (${CONFIG}) — Developer ID : ${SIGN_IDENTITY}…"
  # Hardened runtime (déjà activé dans le projet) + secure timestamp : requis pour notariser.
  xcodebuild \
    -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" \
    -derivedDataPath "$BUILD_DIR/dd" \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR/app" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
    build
fi

APP_PATH="$BUILD_DIR/app/${APP_NAME}.app"
[ -d "$APP_PATH" ] || { echo "❌ App introuvable : $APP_PATH"; exit 1; }

echo "▶︎ Fabrication du .dmg…"
STAGING="$BUILD_DIR/dmg"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG_OUT"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG_OUT"

# Notarisation + agrafage (mode distribution uniquement).
if [ -n "$NOTARY_PROFILE" ]; then
  echo "▶︎ Notarisation (profil : ${NOTARY_PROFILE})…"
  xcrun notarytool submit "$DMG_OUT" --keychain-profile "$NOTARY_PROFILE" --wait
  echo "▶︎ Agrafage du ticket…"
  xcrun stapler staple "$DMG_OUT"
  xcrun stapler validate "$DMG_OUT" && echo "✅ DMG notarisé et staplé."
fi

echo "✅ DMG prêt : dist/${APP_NAME}.dmg"
if [ "$SIGN_IDENTITY" = "-" ]; then
  echo "   (ad-hoc — 1er lancement : clic droit → Ouvrir)"
else
  echo "   (Developer ID — double-clic sans avertissement une fois notarisé)"
fi
