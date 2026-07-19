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
 * Récupère une clé API depuis le Keychain macOS.
 * Retourne la valeur en clair (vault local et personnel).
 * Lève une erreur claire si la clé est absente.
 */
export async function getApiKey(keyName: string): Promise<string> {
  if (!keyName || keyName.trim().length === 0) {
    throw new Error("Nom de clé vide.");
  }
  try {
    const out = await run("security", [
      "find-generic-password",
      "-s",
      KEYCHAIN_SERVICE,
      "-a",
      keyName,
      "-w", // n'affiche que le mot de passe (la valeur)
    ]);
    // `security -w` ajoute un retour à la ligne final.
    return out.replace(/\n$/, "");
  } catch (err) {
    const msg = (err as Error).message;
    if (/could not be found|SecKeychainSearch/i.test(msg)) {
      throw new Error(
        `Clé API "${keyName}" introuvable dans le Keychain (service "${KEYCHAIN_SERVICE}"). ` +
          `Ajoute-la depuis l'app ClaudeVault, onglet « Clés API ».`
      );
    }
    throw new Error(`Lecture Keychain impossible pour "${keyName}" : ${msg}`);
  }
}
