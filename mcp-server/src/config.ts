/**
 * Lecture/écriture de la configuration partagée avec l'app macOS.
 * Source de vérité : ~/.vault-mcp/profiles.json
 * État de session (profil actif) : ~/.vault-mcp/state.json
 *
 * On relit le disque à chaque appel (pas de cache long) pour rester
 * synchronisé avec l'app SwiftUI, conformément à la spec.
 */
import { homedir } from "node:os";
import { join } from "node:path";
import { promises as fs } from "node:fs";

/**
 * Dossier de configuration. Par défaut ~/.vault-mcp, surchargée par la variable
 * d'environnement CLAUDEVAULT_DIR (pratique pour les tests ou une config
 * alternative sans toucher au HOME de la session).
 */
export const VAULT_DIR =
  process.env.CLAUDEVAULT_DIR && process.env.CLAUDEVAULT_DIR.trim().length > 0
    ? process.env.CLAUDEVAULT_DIR
    : join(homedir(), ".vault-mcp");
export const PROFILES_FILE = join(VAULT_DIR, "profiles.json");
export const STATE_FILE = join(VAULT_DIR, "state.json");

export interface Profile {
  id: string;
  name: string;
  path: string;
  description: string;
  /** Nom du fichier mémoire condensé, par défaut "memory.md". */
  memoryFile?: string;
  lastUpdated?: string;
}

interface ProfilesConfig {
  profiles: Profile[];
}

interface State {
  activeProfileId?: string;
}

async function ensureVaultDir(): Promise<void> {
  await fs.mkdir(VAULT_DIR, { recursive: true });
}

/** Lit profiles.json. Retourne une liste vide si le fichier n'existe pas encore. */
export async function readProfiles(): Promise<Profile[]> {
  try {
    const raw = await fs.readFile(PROFILES_FILE, "utf8");
    const parsed = JSON.parse(raw) as ProfilesConfig;
    if (!parsed || !Array.isArray(parsed.profiles)) return [];
    return parsed.profiles;
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === "ENOENT") return [];
    throw new Error(
      `profiles.json illisible (${PROFILES_FILE}) : ${(err as Error).message}`
    );
  }
}

/** Résout un profil par son id, ou lève une erreur explicite si absent. */
export async function getProfileOrThrow(profileId: string): Promise<Profile> {
  const profiles = await readProfiles();
  const profile = profiles.find((p) => p.id === profileId);
  if (!profile) {
    const known = profiles.map((p) => p.id).join(", ") || "(aucun profil)";
    throw new Error(
      `Profil introuvable : "${profileId}". Profils disponibles : ${known}.`
    );
  }
  return profile;
}

/** Nom du fichier mémoire d'un profil (défaut : memory.md). */
export function memoryFileName(profile: Profile): string {
  return profile.memoryFile && profile.memoryFile.trim().length > 0
    ? profile.memoryFile
    : "memory.md";
}

/** Met à jour le champ lastUpdated d'un profil dans profiles.json. */
export async function touchProfile(profileId: string): Promise<void> {
  const profiles = await readProfiles();
  const idx = profiles.findIndex((p) => p.id === profileId);
  if (idx === -1) return;
  profiles[idx].lastUpdated = new Date().toISOString();
  await ensureVaultDir();
  await fs.writeFile(
    PROFILES_FILE,
    JSON.stringify({ profiles }, null, 2),
    "utf8"
  );
}

export async function readActiveProfileId(): Promise<string | undefined> {
  try {
    const raw = await fs.readFile(STATE_FILE, "utf8");
    return (JSON.parse(raw) as State).activeProfileId;
  } catch {
    return undefined;
  }
}

export async function setActiveProfileId(profileId: string): Promise<void> {
  await ensureVaultDir();
  const state: State = { activeProfileId: profileId };
  await fs.writeFile(STATE_FILE, JSON.stringify(state, null, 2), "utf8");
}
