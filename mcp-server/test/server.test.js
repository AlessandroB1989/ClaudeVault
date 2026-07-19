/**
 * Test d'intégration bout-en-bout du serveur MCP ClaudeVault.
 * Démarre le serveur via stdio dans un HOME temporaire isolé et exerce
 * chaque outil via un vrai client MCP.
 */
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { promises as fs } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { execFileSync } from "node:child_process";

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const here = fileURLToPath(new URL(".", import.meta.url));
const serverEntry = join(here, "..", "build", "index.js");

let workDir;
let vaultDir;
let profileDir;
let client;
let transport;

/** Extrait le texte d'un résultat d'outil MCP. */
function textOf(result) {
  return result.content.map((c) => c.text).join("\n");
}

before(async () => {
  // Dossier de travail temporaire isolé. On surcharge CLAUDEVAULT_DIR (pas HOME)
  // pour que le trousseau Keychain reste celui de la session réelle.
  workDir = await fs.mkdtemp(join(tmpdir(), "claudevault-"));
  vaultDir = join(workDir, ".vault-mcp");
  profileDir = join(workDir, "Vault", "Business-IA");
  await fs.mkdir(vaultDir, { recursive: true });
  await fs.mkdir(profileDir, { recursive: true });

  await fs.writeFile(
    join(vaultDir, "profiles.json"),
    JSON.stringify(
      {
        profiles: [
          {
            id: "business-ia",
            name: "Business IA",
            path: profileDir,
            description: "Projets SaaS, clients, roadmap",
            memoryFile: "memory.md",
          },
        ],
      },
      null,
      2
    )
  );

  transport = new StdioClientTransport({
    command: process.execPath,
    args: [serverEntry],
    env: { ...process.env, CLAUDEVAULT_DIR: vaultDir },
  });
  client = new Client({ name: "test", version: "1.0.0" });
  await client.connect(transport);
});

after(async () => {
  await transport?.close();
  if (workDir) await fs.rm(workDir, { recursive: true, force: true });
});

test("les 7 outils sont exposés", async () => {
  const { tools } = await client.listTools();
  const names = tools.map((t) => t.name).sort();
  assert.deepEqual(names, [
    "get_api_key",
    "list_profiles",
    "read_memory",
    "read_notes",
    "set_active_profile",
    "update_profile_memory",
    "write_note",
  ]);
});

test("list_profiles retourne le profil configuré", async () => {
  const res = await client.callTool({ name: "list_profiles", arguments: {} });
  assert.match(textOf(res), /business-ia/);
  assert.match(textOf(res), /Business IA/);
});

test("set_active_profile marque le profil actif", async () => {
  const res = await client.callTool({
    name: "set_active_profile",
    arguments: { profileId: "business-ia" },
  });
  assert.match(textOf(res), /Profil actif : Business IA/);

  const list = await client.callTool({ name: "list_profiles", arguments: {} });
  assert.match(textOf(list), /⭐ \(actif\)/);
});

test("set_active_profile échoue proprement sur id inconnu", async () => {
  const res = await client.callTool({
    name: "set_active_profile",
    arguments: { profileId: "inconnu" },
  });
  assert.equal(res.isError, true);
  assert.match(textOf(res), /introuvable/i);
});

test("write_note puis read_notes", async () => {
  await client.callTool({
    name: "write_note",
    arguments: {
      profileId: "business-ia",
      filename: "roadmap",
      content: "# Roadmap\n- MVP en juillet",
    },
  });
  // Le fichier doit exister avec l'extension .md ajoutée.
  const onDisk = await fs.readFile(
    join(profileDir, "notes", "roadmap.md"),
    "utf8"
  );
  assert.match(onDisk, /MVP en juillet/);

  const res = await client.callTool({
    name: "read_notes",
    arguments: { profileId: "business-ia" },
  });
  assert.match(textOf(res), /roadmap\.md/);
  assert.match(textOf(res), /MVP en juillet/);
});

test("write_note refuse un nom de fichier qui s'évade du dossier", async () => {
  const res = await client.callTool({
    name: "write_note",
    arguments: {
      profileId: "business-ia",
      filename: "../evasion.md",
      content: "nope",
    },
  });
  assert.equal(res.isError, true);
});

test("write_note range dans un sous-dossier, read_notes le retrouve", async () => {
  await client.callTool({
    name: "write_note",
    arguments: {
      profileId: "business-ia",
      filename: "site-acme/roadmap.md",
      content: "# Roadmap Acme\n- Sprint 1",
    },
  });
  // Le fichier existe bien dans le sous-dossier.
  const onDisk = await fs.readFile(
    join(profileDir, "notes", "site-acme", "roadmap.md"),
    "utf8"
  );
  assert.match(onDisk, /Sprint 1/);

  // read_notes renvoie le chemin relatif avec le sous-dossier.
  const res = await client.callTool({
    name: "read_notes",
    arguments: { profileId: "business-ia" },
  });
  assert.match(textOf(res), /site-acme\/roadmap\.md/);
  assert.match(textOf(res), /Roadmap Acme/);
});

test("write_note refuse un sous-chemin qui s'évade via ..", async () => {
  const res = await client.callTool({
    name: "write_note",
    arguments: {
      profileId: "business-ia",
      filename: "projet/../../evasion.md",
      content: "nope",
    },
  });
  assert.equal(res.isError, true);
});

test("update_profile_memory puis read_memory", async () => {
  await client.callTool({
    name: "update_profile_memory",
    arguments: {
      profileId: "business-ia",
      summary: "Client Acme signé. Livraison MVP prévue le 30 juillet.",
    },
  });
  const mem = await fs.readFile(join(profileDir, "memory.md"), "utf8");
  assert.match(mem, /# Mémoire — Business IA/);
  assert.match(mem, /Client Acme signé/);

  const res = await client.callTool({
    name: "read_memory",
    arguments: { profileId: "business-ia" },
  });
  assert.match(textOf(res), /Client Acme signé/);
  assert.match(textOf(res), /tokens/);
});

test("update_profile_memory tronque au-delà de la limite dure", async () => {
  // Injecte un memory.md déjà quasi plein (> limite).
  const big = "# Mémoire — Business IA\n" +
    Array.from({ length: 30 }, (_, i) => `\n## 2026-01-${String(i + 1).padStart(2, "0")}T00:00:00Z\n\n${"x".repeat(900)}\n`).join("");
  await fs.writeFile(join(profileDir, "memory.md"), big);

  const res = await client.callTool({
    name: "update_profile_memory",
    arguments: { profileId: "business-ia", summary: "Nouvelle entrée récente." },
  });
  assert.match(textOf(res), /anciennes/i); // avertissement de troncature
  const mem = await fs.readFile(join(profileDir, "memory.md"), "utf8");
  assert.ok(mem.length <= 20000, `memory.md doit rester <= 20000 chars, vu ${mem.length}`);
  assert.match(mem, /Nouvelle entrée récente/); // le récent est conservé
});

test("get_api_key : clé absente → erreur claire", async () => {
  const res = await client.callTool({
    name: "get_api_key",
    arguments: { keyName: "CLE_QUI_NEXISTE_PAS_XYZ" },
  });
  assert.equal(res.isError, true);
  assert.match(textOf(res), /introuvable|Keychain/i);
});

test("get_api_key : clé présente dans le Keychain → valeur", async () => {
  const account = "CLAUDEVAULT_TEST_KEY_TMP";
  const secret = "sk-test-123456";
  // Ajoute une entrée temporaire dans le trousseau de connexion.
  execFileSync("security", [
    "add-generic-password",
    "-s", "ClaudeVault",
    "-a", account,
    "-w", secret,
    "-U",
  ]);
  try {
    const res = await client.callTool({
      name: "get_api_key",
      arguments: { keyName: account },
    });
    assert.equal(textOf(res).trim(), secret);
  } finally {
    execFileSync("security", [
      "delete-generic-password",
      "-s", "ClaudeVault",
      "-a", account,
    ]);
  }
});
