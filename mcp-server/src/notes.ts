/**
 * Lecture/écriture des notes .md d'un profil, avec sous-dossiers.
 * Les notes vivent dans <profil.path>/notes/ et peuvent être rangées dans des
 * sous-répertoires (un par projet, par exemple : "site-acme/roadmap.md").
 */
import { join, sep, extname, relative } from "node:path";
import { promises as fs } from "node:fs";
import type { Profile } from "./config.js";

export function notesDir(profile: Profile): string {
  return join(profile.path, "notes");
}

/**
 * Nettoie un chemin relatif de note : autorise les sous-dossiers ("a/b/c.md")
 * mais interdit toute évasion ("../"), les segments cachés et les chemins
 * absolus. Force l'extension .md sur le dernier segment.
 */
export function safeNotePath(filename: string): string {
  const raw = filename.replace(/\\/g, "/").trim();
  if (raw.length === 0) {
    throw new Error("Nom de fichier vide.");
  }
  const segments = raw.split("/").filter((s) => s.length > 0);
  for (const seg of segments) {
    if (seg === "." || seg === ".." || seg.startsWith(".")) {
      throw new Error(
        `Chemin de note invalide : "${filename}". Pas de "..", ni de segment caché.`
      );
    }
  }
  if (segments.length === 0) {
    throw new Error(`Chemin de note invalide : "${filename}".`);
  }
  const last = segments[segments.length - 1];
  segments[segments.length - 1] =
    extname(last).toLowerCase() === ".md" ? last : `${last}.md`;
  return segments.join("/");
}

export interface NoteFile {
  /** Chemin relatif au dossier notes/, ex. "site-acme/roadmap.md". */
  filename: string;
  content: string;
}

/** Liste récursivement tous les .md sous notes/ (chemins relatifs). */
async function walk(dir: string, base: string): Promise<string[]> {
  let entries: import("node:fs").Dirent[];
  try {
    entries = await fs.readdir(dir, { withFileTypes: true });
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === "ENOENT") return [];
    throw err;
  }
  const results: string[] = [];
  for (const entry of entries) {
    if (entry.name.startsWith(".")) continue;
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...(await walk(full, base)));
    } else if (extname(entry.name).toLowerCase() === ".md") {
      results.push(relative(base, full).split(sep).join("/"));
    }
  }
  return results;
}

/** Lit tous les fichiers .md (y compris dans les sous-dossiers) d'un profil. */
export async function readNotes(profile: Profile): Promise<NoteFile[]> {
  const dir = notesDir(profile);
  const relPaths = (await walk(dir, dir)).sort((a, b) =>
    a.localeCompare(b, "fr")
  );
  const notes: NoteFile[] = [];
  for (const rel of relPaths) {
    const content = await fs.readFile(join(dir, rel), "utf8");
    notes.push({ filename: rel, content });
  }
  return notes;
}

/** Crée/écrase un .md dans notes/ (sous-dossiers créés au besoin). */
export async function writeNote(
  profile: Profile,
  filename: string,
  content: string
): Promise<string> {
  const rel = safeNotePath(filename);
  const dir = notesDir(profile);
  const full = join(dir, rel);
  await fs.mkdir(join(full, ".."), { recursive: true });
  await fs.writeFile(full, content, "utf8");
  return full;
}
