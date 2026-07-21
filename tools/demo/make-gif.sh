#!/usr/bin/env bash
# Convertit un enregistrement d'écran (.mov/.mp4) en GIF optimisé pour le README.
# Qualité maximale : 2 passes (palette dédiée) + dithering.
#
#   bash tools/demo/make-gif.sh demo.mov            # → docs/demo.gif
#   bash tools/demo/make-gif.sh demo.mov out.gif
#   FPS=15 WIDTH=1000 START=2 DURATION=25 bash tools/demo/make-gif.sh demo.mov
#
# Enregistrer la vidéo au préalable : Cmd+Shift+5 → « Enregistrer une portion »,
# cadre la fenêtre ClaudeVault (~1280×800), suis le storyboard docs/LAUNCH.md §5.
set -euo pipefail

IN="${1:-}"
OUT="${2:-docs/demo.gif}"
FPS="${FPS:-12}"
WIDTH="${WIDTH:-900}"
START="${START:-}"
DURATION="${DURATION:-}"

if [ -z "$IN" ] || [ ! -f "$IN" ]; then
  echo "Usage : bash tools/demo/make-gif.sh <entree.mov> [sortie.gif]"; exit 1
fi
command -v ffmpeg >/dev/null || { echo "❌ ffmpeg absent (brew install ffmpeg)"; exit 1; }

TRIM=()
[ -n "$START" ] && TRIM+=(-ss "$START")
[ -n "$DURATION" ] && TRIM+=(-t "$DURATION")

TMP="$(mktemp -d)"
PALETTE="$TMP/palette.png"
FILTERS="fps=${FPS},scale=${WIDTH}:-1:flags=lanczos"

mkdir -p "$(dirname "$OUT")"

echo "▶︎ Passe 1/2 : génération de la palette…"
ffmpeg -y -loglevel error ${TRIM[@]+"${TRIM[@]}"} -i "$IN" \
  -vf "${FILTERS},palettegen=stats_mode=diff" "$PALETTE"

echo "▶︎ Passe 2/2 : encodage du GIF…"
ffmpeg -y -loglevel error ${TRIM[@]+"${TRIM[@]}"} -i "$IN" -i "$PALETTE" \
  -lavfi "${FILTERS} [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" \
  "$OUT"

rm -rf "$TMP"
SIZE=$(du -h "$OUT" | cut -f1)
echo "✅ GIF prêt : $OUT (${SIZE})"
echo "   Ajoute-le en tête du README :  <p align=\"center\"><img src=\"$OUT\" width=\"720\"></p>"
