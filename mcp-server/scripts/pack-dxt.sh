#!/usr/bin/env bash
# Construit le serveur puis le packe en Desktop Extension (.mcpb / .dxt)
# pour installation en un clic dans Claude Desktop.
#
# Prérequis : npm i -g @anthropic-ai/mcpb  (ou npx @anthropic-ai/mcpb)
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶︎ Build TypeScript…"
npm install
npm run build

echo "▶︎ Packaging Desktop Extension…"
# L'outil `mcpb pack` lit manifest.json et embarque build/ + node_modules de prod.
npx --yes @anthropic-ai/mcpb pack . ../dist/claudevault.mcpb

echo "✅ Bundle prêt : dist/claudevault.mcpb"
echo "   Ouvre-le avec Claude Desktop pour l'installer en un clic."
