/**
 * Mémoire condensée "second brain" d'un profil (memory.md).
 * Objectif : rester sous ~5000 tokens pour économiser le contexte de Claude.
 *
 * Heuristique de comptage : ~4 caractères par token (approximation robuste
 * pour du français/anglais). La vraie compaction sémantique est faite par
 * Claude qui appelle update_profile_memory avec un résumé déjà condensé ;
 * cet outil garantit surtout que le fichier ne dépasse jamais la limite dure.
 */
import { join } from "node:path";
import { promises as fs } from "node:fs";
import { type Profile, memoryFileName } from "./config.js";

export const MAX_MEMORY_TOKENS = 5000;
const CHARS_PER_TOKEN = 4;
export const MAX_MEMORY_CHARS = MAX_MEMORY_TOKENS * CHARS_PER_TOKEN; // ~20000

export function estimateTokens(text: string): number {
  return Math.ceil(text.length / CHARS_PER_TOKEN);
}

export function memoryPath(profile: Profile): string {
  return join(profile.path, memoryFileName(profile));
}

/** Lit memory.md. Retourne "" si le fichier n'existe pas encore. */
export async function readMemory(profile: Profile): Promise<string> {
  try {
    return await fs.readFile(memoryPath(profile), "utf8");
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === "ENOENT") return "";
    throw err;
  }
}

export interface MemoryUpdateResult {
  path: string;
  tokensBefore: number;
  tokensAfter: number;
  trimmed: boolean;
  warning?: string;
}

/**
 * Ajoute un résumé horodaté à memory.md.
 * Si le total dépasse MAX_MEMORY_CHARS, on retire les sections les plus
 * anciennes (en gardant l'en-tête) jusqu'à repasser sous la limite, et on
 * renvoie un avertissement invitant Claude à recompacter sémantiquement.
 */
export async function updateMemory(
  profile: Profile,
  summary: string,
  isoDate: string
): Promise<MemoryUpdateResult> {
  const path = memoryPath(profile);
  const existing = await readMemory(profile);
  const tokensBefore = estimateTokens(existing);

  const header = `# Mémoire — ${profile.name}\n`;
  const body = existing.startsWith("#")
    ? existing.slice(existing.indexOf("\n") + 1)
    : existing;

  const section = `\n## ${isoDate}\n\n${summary.trim()}\n`;
  let next = `${header}${body.replace(/\s+$/, "")}\n${section}`;

  let trimmed = false;
  let warning: string | undefined;

  if (next.length > MAX_MEMORY_CHARS) {
    trimmed = true;
    // Découpe en sections "## " et retire les plus anciennes.
    const parts = next.split(/(?=\n## )/);
    const head = parts.shift() ?? header; // titre + éventuel préambule
    while (parts.length > 1 && (head + parts.join("")).length > MAX_MEMORY_CHARS) {
      parts.shift(); // retire la section la plus ancienne
    }
    next = head + parts.join("");
    warning =
      `⚠️ memory.md dépassait ${MAX_MEMORY_TOKENS} tokens : les sections les plus ` +
      `anciennes ont été retirées automatiquement. Pour préserver l'essentiel, ` +
      `relis la mémoire, recompacte-la sémantiquement, puis réécris-la avec ` +
      `update_profile_memory.`;
  }

  await fs.mkdir(profile.path, { recursive: true });
  await fs.writeFile(path, next, "utf8");

  return {
    path,
    tokensBefore,
    tokensAfter: estimateTokens(next),
    trimmed,
    warning,
  };
}
