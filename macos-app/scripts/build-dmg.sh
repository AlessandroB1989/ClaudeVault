#!/usr/bin/env bash
# Construit ClaudeVault.app puis l'emballe dans un .dmg (glisser → Applications).
# À lancer sur ta machine (Xcode requis). Signature « pour exécution locale » par
# défaut ; pour distribuer largement, notarise ensuite (voir la note en bas).
#
#   bash macos-app/scripts/build-dmg.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."   # → macos-app/

PROJECT="ClaudeVault.xcodeproj"
SCHEME="ClaudeVault"
CONFIG="Release"
BUILD_DIR="build"
APP_NAME="ClaudeVault"
DMG_OUT="../dist/${APP_NAME}.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "../dist"

echo "▶︎ Build (${CONFIG})…"
# CODE_SIGNING_ALLOWED=NO → build local sans compte/notarisation.
# Retire cette ligne (et laisse la signature auto) si tu as un compte développeur.
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$BUILD_DIR/dd" \
  CONFIGURATION_BUILD_DIR="$PWD/$BUILD_DIR/app" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="$BUILD_DIR/app/${APP_NAME}.app"
[ -d "$APP_PATH" ] || { echo "❌ App introuvable : $APP_PATH"; exit 1; }

echo "▶︎ Fabrication du .dmg…"
STAGING="$BUILD_DIR/dmg"
rm -rf "$STAGING"; mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "$DMG_OUT"

echo "✅ DMG prêt : dist/${APP_NAME}.dmg"
echo
echo "Note distribution :"
echo " • Local (toi/ton épouse) : ce .dmg suffit. Au 1er lancement, clic droit →"
echo "   Ouvrir pour contourner Gatekeeper (app non notarisée)."
echo " • Diffusion large : signe avec un Developer ID puis notarise :"
echo "     xcrun notarytool submit dist/${APP_NAME}.dmg --keychain-profile <profil> --wait"
echo "     xcrun stapler staple dist/${APP_NAME}.dmg"
