#!/usr/bin/env node
/**
 * Serveur MCP ClaudeVault.
 * Expose à Claude une mémoire par profil (second brain) + un vault de clés API.
 *
 * Transport : stdio (compatible Claude Desktop et Claude Code).
 * Config partagée avec l'app macOS : ~/.vault-mcp/profiles.json
 */
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

import {
  readProfiles,
  getProfileOrThrow,
  setActiveProfileId,
  readActiveProfileId,
  touchProfile,
  memoryFileName,
} from "./config.js";
import { readNotes, writeNote } from "./notes.js";
import {
  readMemory,
  updateMemory,
  estimateTokens,
  MAX_MEMORY_TOKENS,
} from "./memory.js";
import { getApiKey } from "./keychain.js";

const server = new McpServer({
  name: "claudevault",
  version: "1.0.0",
});

/** Raccourci pour renvoyer du texte. */
function text(s: string) {
  return { content: [{ type: "text" as const, text: s }] };
}

/** Raccourci pour renvoyer une erreur outil (isError). */
function fail(s: string) {
  return { content: [{ type: "text" as const, text: s }], isError: true };
}

// ─── list_profiles ──────────────────────────────────────────────────────────
server.registerTool(
  "list_profiles",
  {
    title: "Lister les profils",
    description:
      "Retourne la liste des profils de mémoire disponibles (id, nom, description). " +
      "Utilise-la en début de session pour savoir quels domaines existent.",
    inputSchema: {},
  },
  async () => {
    const profiles = await readProfiles();
    if (profiles.length === 0) {
      return text(
        "Aucun profil configuré. Crée-en un depuis l'app ClaudeVault (bouton +)."
      );
    }
    const active = await readActiveProfileId();
    const lines = profiles.map((p) => {
      const flag = p.id === active ? " ⭐ (actif)" : "";
      return `- ${p.id}${flag} — ${p.name} : ${p.description}`;
    });
    return text(
      `Profils disponibles (${profiles.length}) :\n${lines.join("\n")}`
    );
  }
);

// ─── set_active_profile ───────────────────────────────────────────────────────
server.registerTool(
  "set_active_profile",
  {
    title: "Définir le profil actif",
    description:
      "Définit le profil actif pour la session en cours. Les mises à jour de " +
      "mémoire concerneront ce profil par défaut.",
    inputSchema: {
      profileId: z.string().describe("id du profil à activer"),
    },
  },
  async ({ profileId }) => {
    const profile = await getProfileOrThrow(profileId);
    await setActiveProfileId(profile.id);
    return text(
      `Profil actif : ${profile.name} (${profile.id}). ` +
        `Pense à charger read_memory("${profile.id}") avant les notes brutes.`
    );
  }
);

// ─── read_memory ──────────────────────────────────────────────────────────────
server.registerTool(
  "read_memory",
  {
    title: "Lire la mémoire condensée",
    description:
      "Lit le fichier memory.md condensé du profil. À CHARGER EN PRIORITÉ, " +
      "avant read_notes : il suffit souvent à répondre et économise des tokens.",
    inputSchema: {
      profileId: z.string().describe("id du profil"),
    },
  },
  async ({ profileId }) => {
    const profile = await getProfileOrThrow(profileId);
    const memory = await readMemory(profile);
    if (memory.trim().length === 0) {
      return text(
        `Mémoire vide pour "${profile.name}". Aucun ${memoryFileName(profile)} ` +
          `n'existe encore — elle se remplira via update_profile_memory.`
      );
    }
    const tokens = estimateTokens(memory);
    return text(
      `Mémoire de "${profile.name}" (~${tokens}/${MAX_MEMORY_TOKENS} tokens) :\n\n${memory}`
    );
  }
);

// ─── read_notes ───────────────────────────────────────────────────────────────
server.registerTool(
  "read_notes",
  {
    title: "Lire les notes brutes",
    description:
      "Lit tous les fichiers .md du dossier notes/ du profil. À n'utiliser que " +
      "si read_memory ne suffit pas (plus coûteux en tokens).",
    inputSchema: {
      profileId: z.string().describe("id du profil"),
    },
  },
  async ({ profileId }) => {
    const profile = await getProfileOrThrow(profileId);
    const notes = await readNotes(profile);
    if (notes.length === 0) {
      return text(`Aucune note dans notes/ pour "${profile.name}".`);
    }
    const blocks = notes.map(
      (n) => `─── ${n.filename} ───\n${n.content}`
    );
    return text(
      `Notes de "${profile.name}" (${notes.length} fichier(s)) :\n\n${blocks.join(
        "\n\n"
      )}`
    );
  }
);

// ─── write_note ───────────────────────────────────────────────────────────────
server.registerTool(
  "write_note",
  {
    title: "Écrire une note",
    description:
      "Crée ou remplace un fichier .md dans le dossier notes/ du profil. " +
      "Le nom peut inclure un sous-dossier pour ranger par projet, ex. " +
      '"site-acme/roadmap.md" (les dossiers sont créés au besoin).',
    inputSchema: {
      profileId: z.string().describe("id du profil"),
      filename: z
        .string()
        .describe('nom du fichier, sous-dossier optionnel, ex. "site-acme/roadmap.md"'),
      content: z.string().describe("contenu Markdown complet du fichier"),
    },
  },
  async ({ profileId, filename, content }) => {
    const profile = await getProfileOrThrow(profileId);
    const full = await writeNote(profile, filename, content);
    return text(`Note écrite : ${full}`);
  }
);

// ─── update_profile_memory ────────────────────────────────────────────────────
server.registerTool(
  "update_profile_memory",
  {
    title: "Mettre à jour la mémoire",
    description:
      "Ajoute un résumé condensé à memory.md (section horodatée). Respecte une " +
      `limite dure d'environ ${MAX_MEMORY_TOKENS} tokens : au-delà, les sections ` +
      "les plus anciennes sont retirées. Appelle cet outil en fin de session ou " +
      "tous les ~40 messages, avec un résumé DÉJÀ compacté des éléments nouveaux.",
    inputSchema: {
      profileId: z.string().describe("id du profil"),
      summary: z
        .string()
        .describe("résumé condensé des informations nouvelles et importantes"),
    },
  },
  async ({ profileId, summary }) => {
    const profile = await getProfileOrThrow(profileId);
    const isoDate = new Date().toISOString();
    const result = await updateMemory(profile, summary, isoDate);
    await touchProfile(profile.id);
    let msg =
      `Mémoire mise à jour (${result.path}).\n` +
      `Tokens : ~${result.tokensBefore} → ~${result.tokensAfter} / ${MAX_MEMORY_TOKENS}.`;
    if (result.warning) msg += `\n\n${result.warning}`;
    return text(msg);
  }
);

// ─── get_api_key ──────────────────────────────────────────────────────────────
server.registerTool(
  "get_api_key",
  {
    title: "Récupérer une clé API",
    description:
      "Récupère une clé API depuis le Keychain macOS (vault unique partagé entre " +
      "tous les profils). Fournis le nom exact de la clé tel que défini dans l'app.",
    inputSchema: {
      keyName: z.string().describe('nom de la clé, ex. "OPENAI_API_KEY"'),
    },
  },
  async ({ keyName }) => {
    try {
      const value = await getApiKey(keyName);
      return text(value);
    } catch (err) {
      return fail((err as Error).message);
    }
  }
);

// ─── Démarrage ────────────────────────────────────────────────────────────────
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // stderr uniquement : stdout est réservé au protocole MCP.
  console.error("ClaudeVault MCP prêt (stdio).");
}

main().catch((err) => {
  console.error("Échec démarrage ClaudeVault MCP :", err);
  process.exit(1);
});
