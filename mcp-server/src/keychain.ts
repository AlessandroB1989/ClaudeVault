/**
 * Accès au vault de clés API unique, partagé entre tous les profils.
 * Les clés sont stockées dans le Keychain macOS par l'app SwiftUI
 * (kSecClassGenericPassword, service = SERVICE, account = nom de la clé).
 * On les relit ici via l'outil CLI `security`.
 */
import { execFile } from "node:child_process";

/** Doit correspondre à kSecAttrService utilisé par l'app SwiftUI. */
export const KEYCHAIN_SERVICE = "ClaudeVault";

function run(cmd: string, args: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    execFile(cmd, args, { timeout: 5000 }, (err, stdout, stderr) => {
      if (err) {
        reject(new Error(stderr.trim() || err.message));
        return;
      }
      resolve(stdout);
    });
  });
}

/**
 * Récupère la valeur d'une clé API par son COMPTE Keychain (id stable pour les
 * nouvelles clés, ou nom pour l'ancien schéma). Retourne null si absente.
 */
export async function fetchValueByAccount(account: string): Promise<string | null> {
  if (!account || account.trim().length === 0) return null;
  try {
    const out = await run("security", [
      "find-generic-password",
      "-s",
      KEYCHAIN_SERVICE,
      "-a",
      account,
      "-w", // n'affiche que le mot de passe (la valeur)
    ]);
    return out.replace(/\n$/, ""); // `security -w` ajoute un retour à la ligne final
  } catch (err) {
    const msg = (err as Error).message;
    if (/could not be found|SecKeychainSearch/i.test(msg)) return null;
    throw new Error(`Lecture Keychain impossible (${account}) : ${msg}`);
  }
}
