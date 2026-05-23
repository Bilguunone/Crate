#!/usr/bin/env node

import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import os from "node:os";
import path from "node:path";

const scriptPath = fileURLToPath(import.meta.url);
const rootDir = path.resolve(path.dirname(scriptPath), "..");
const cratectlPath = path.join(rootDir, "script", "cratectl.sh");

const tools = [
  {
    name: "analyze_folder",
    description: "Analyze an asset folder before import and return Crate's proposed pack metadata, ignored files, duplicate basename warnings, and sample normalized names.",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Folder containing PNG/JPG design assets." },
        library: { type: "string", description: "Optional Crate library root. Defaults to Crate's saved/default library." },
        kind: { type: "string", description: "Optional override such as texture, overlay, sticker." },
        material: { type: "string", description: "Optional material override such as paper, plastic, ink." },
        subtype: { type: "string", description: "Optional subtype override such as torn-paper or plastic-wrap." },
        display_name: { type: "string", description: "Optional display name override." },
        source: { type: "string", description: "Optional source/vendor label." },
        pack_id: { type: "string", description: "Optional stable pack id override." },
        short_code: { type: "string", description: "Optional filename prefix override." }
      },
      required: ["path"],
      additionalProperties: false
    }
  },
  {
    name: "import_folder",
    description: "Import a folder into the managed Crate library. Originals are copied, not mutated.",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Folder containing PNG/JPG design assets." },
        library: { type: "string", description: "Optional Crate library root." },
        kind: { type: "string", description: "Optional override such as texture, overlay, sticker." },
        material: { type: "string", description: "Optional material override." },
        subtype: { type: "string", description: "Optional subtype override." },
        display_name: { type: "string", description: "Optional display name override." },
        source: { type: "string", description: "Optional source/vendor label." },
        pack_id: { type: "string", description: "Optional stable pack id override." },
        short_code: { type: "string", description: "Optional filename prefix override." }
      },
      required: ["path"],
      additionalProperties: false
    }
  },
  {
    name: "search_assets",
    description: "Search Crate assets by text, kind, tags, alpha, and limit. Returns structured asset records.",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Text query. Can be empty when filtering by tags." },
        library: { type: "string", description: "Optional Crate library root." },
        kind: { type: "string", description: "Optional kind filter." },
        tags: {
          type: "array",
          items: { type: "string" },
          description: "Tag filters such as material:paper, color:black, transparency:light."
        },
        alpha: { type: "boolean", description: "Only assets with alpha/transparent variants." },
        limit: { type: "integer", minimum: 1, maximum: 200, description: "Maximum results." }
      },
      additionalProperties: false
    }
  },
  {
    name: "add_to_cart",
    description: "Add explicit asset ids or search results to the Crate cart, then return the updated cart.",
    inputSchema: {
      type: "object",
      properties: {
        library: { type: "string", description: "Optional Crate library root." },
        asset_ids: {
          type: "array",
          items: { type: "string" },
          description: "Explicit asset ids to add."
        },
        query: { type: "string", description: "Search query when adding by search." },
        kind: { type: "string", description: "Optional kind filter for search-based add." },
        tags: {
          type: "array",
          items: { type: "string" },
          description: "Optional tag filters for search-based add."
        },
        alpha: { type: "boolean", description: "Only alpha assets for search-based add." },
        limit: { type: "integer", minimum: 1, maximum: 100, description: "Search add limit. Defaults to 12." }
      },
      additionalProperties: false
    }
  },
  {
    name: "create_collection",
    description: "Create a Crate collection from the cart or explicit asset ids.",
    inputSchema: {
      type: "object",
      properties: {
        name: { type: "string", description: "Collection name." },
        library: { type: "string", description: "Optional Crate library root." },
        from_cart: { type: "boolean", description: "Create from current cart. Defaults to true when asset_ids is empty." },
        asset_ids: {
          type: "array",
          items: { type: "string" },
          description: "Explicit asset ids for the collection."
        }
      },
      required: ["name"],
      additionalProperties: false
    }
  },
  {
    name: "export_cart",
    description: "Export the current Crate cart as a folder or zip and return the exported path.",
    inputSchema: {
      type: "object",
      properties: {
        library: { type: "string", description: "Optional Crate library root." },
        format: { type: "string", enum: ["folder", "zip"], description: "Export format. Defaults to folder." }
      },
      additionalProperties: false
    }
  }
];

let buffer = Buffer.alloc(0);
let messageQueue = Promise.resolve();

process.stdin.on("data", chunk => {
  buffer = Buffer.concat([buffer, chunk]);
  drainMessages();
});

process.stdin.on("error", error => {
  console.error(`crate-mcp stdin error: ${error.message}`);
});

function drainMessages() {
  while (true) {
    const headerEnd = buffer.indexOf("\r\n\r\n");
    if (headerEnd === -1) return;

    const header = buffer.subarray(0, headerEnd).toString("utf8");
    const match = header.match(/content-length:\s*(\d+)/i);
    if (!match) {
      buffer = buffer.subarray(headerEnd + 4);
      continue;
    }

    const length = Number(match[1]);
    const bodyStart = headerEnd + 4;
    const bodyEnd = bodyStart + length;
    if (buffer.length < bodyEnd) return;

    const body = buffer.subarray(bodyStart, bodyEnd).toString("utf8");
    buffer = buffer.subarray(bodyEnd);

    try {
      enqueueMessage(JSON.parse(body));
    } catch (error) {
      sendError(null, -32700, `Invalid JSON-RPC message: ${error.message}`);
    }
  }
}

function enqueueMessage(message) {
  messageQueue = messageQueue
    .then(() => handleMessage(message))
    .catch(error => {
      console.error(`crate-mcp message error: ${error.message}`);
    });
}

async function handleMessage(message) {
  const id = Object.hasOwn(message, "id") ? message.id : undefined;

  try {
    switch (message.method) {
      case "initialize":
        sendResult(id, {
          protocolVersion: message.params?.protocolVersion ?? "2024-11-05",
          capabilities: { tools: { listChanged: false } },
          serverInfo: { name: "crate-mcp", version: "0.1.0" }
        });
        return;
      case "notifications/initialized":
        return;
      case "ping":
        sendResult(id, {});
        return;
      case "tools/list":
        sendResult(id, { tools });
        return;
      case "tools/call":
        sendResult(id, await callTool(message.params?.name, message.params?.arguments ?? {}));
        return;
      case "resources/list":
        sendResult(id, { resources: [] });
        return;
      case "prompts/list":
        sendResult(id, { prompts: [] });
        return;
      default:
        if (id !== undefined) {
          sendError(id, -32601, `Unknown method: ${message.method}`);
        }
    }
  } catch (error) {
    sendResult(id, {
      isError: true,
      content: [{ type: "text", text: error.message }]
    });
  }
}

async function callTool(name, input) {
  switch (name) {
    case "analyze_folder":
      return jsonToolResult(await analyzeFolder(input));
    case "import_folder":
      return textToolResult(await importFolder(input));
    case "search_assets":
      return jsonToolResult(await searchAssets(input));
    case "add_to_cart":
      return jsonToolResult(await addToCart(input));
    case "create_collection":
      return jsonToolResult(await createCollection(input));
    case "export_cart":
      return jsonToolResult(await exportCart(input));
    default:
      throw new Error(`Unknown tool: ${name}`);
  }
}

async function analyzeFolder(input) {
  requireString(input.path, "path");
  const args = ["analyze-folder", expandHome(input.path), "--json"];
  appendImportOptions(args, input);
  return parseJSON(await runCrate(args, input.library));
}

async function importFolder(input) {
  requireString(input.path, "path");
  const args = ["import-folder", expandHome(input.path)];
  appendImportOptions(args, input);
  const output = await runCrate(args, input.library);
  const packs = parseJSON(await runCrate(["packs", "--json"], input.library));
  return `${output}\n\nPacks:\n${JSON.stringify(packs, null, 2)}`;
}

async function searchAssets(input) {
  const args = ["search"];
  appendSearchOptions(args, input);
  args.push("--json");
  return parseJSON(await runCrate(args, input.library));
}

async function addToCart(input) {
  let action;
  if (Array.isArray(input.asset_ids) && input.asset_ids.length > 0) {
    action = await runCrate(["cart", "add", ...input.asset_ids], input.library);
  } else {
    const args = ["cart", "add-search"];
    appendSearchOptions(args, input, 12);
    action = await runCrate(args, input.library);
  }

  const cart = parseJSON(await runCrate(["cart", "list", "--json"], input.library));
  return { action, cart };
}

async function createCollection(input) {
  requireString(input.name, "name");
  const args = ["collection", "create", input.name];
  if (Array.isArray(input.asset_ids) && input.asset_ids.length > 0) {
    for (const id of input.asset_ids) {
      args.push("--asset", id);
    }
  } else if (input.from_cart !== false) {
    args.push("--from-cart");
  }

  const action = await runCrate(args, input.library);
  const collections = parseJSON(await runCrate(["collection", "list", "--json"], input.library));
  return { action, collections };
}

async function exportCart(input) {
  const format = input.format === "zip" ? "export-zip" : "export-folder";
  const outputPath = await runCrate(["cart", format], input.library);
  return { path: outputPath.trim(), format: input.format === "zip" ? "zip" : "folder" };
}

function appendImportOptions(args, input) {
  appendOption(args, "--kind", input.kind);
  appendOption(args, "--material", input.material);
  appendOption(args, "--subtype", input.subtype);
  appendOption(args, "--display-name", input.display_name);
  appendOption(args, "--source", input.source);
  appendOption(args, "--pack-id", input.pack_id);
  appendOption(args, "--short-code", input.short_code);
}

function appendSearchOptions(args, input, defaultLimit) {
  appendOption(args, "--kind", input.kind);
  for (const tag of input.tags ?? []) {
    appendOption(args, "--tag", tag);
  }
  if (input.alpha === true) args.push("--alpha");
  appendOption(args, "--limit", input.limit ?? defaultLimit);
  if (typeof input.query === "string" && input.query.length > 0) {
    args.push(input.query);
  }
}

function appendOption(args, flag, value) {
  if (value === undefined || value === null || value === "") return;
  args.push(flag, String(value));
}

function requireString(value, name) {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`Missing required string argument: ${name}`);
  }
}

function runCrate(args, library) {
  return new Promise((resolve, reject) => {
    const crateArgs = [];
    if (library) crateArgs.push("--library", expandHome(library));
    crateArgs.push(...args);

    const child = spawn(cratectlPath, crateArgs, {
      cwd: rootDir,
      stdio: ["ignore", "pipe", "pipe"]
    });

    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", chunk => {
      stdout += chunk;
    });
    child.stderr.on("data", chunk => {
      stderr += chunk;
    });
    child.on("error", reject);
    child.on("close", code => {
      const trimmedOutput = stdout.trim();
      if (code === 0) {
        resolve(trimmedOutput);
      } else {
        reject(new Error((stderr || trimmedOutput || `cratectl exited with ${code}`).trim()));
      }
    });
  });
}

function parseJSON(value) {
  try {
    return JSON.parse(value);
  } catch {
    throw new Error(`cratectl did not return JSON:\n${value}`);
  }
}

function jsonToolResult(value) {
  return {
    content: [{ type: "text", text: JSON.stringify(value, null, 2) }]
  };
}

function textToolResult(text) {
  return {
    content: [{ type: "text", text }]
  };
}

function sendResult(id, result) {
  if (id === undefined) return;
  send({ jsonrpc: "2.0", id, result });
}

function sendError(id, code, message) {
  send({ jsonrpc: "2.0", id, error: { code, message } });
}

function send(message) {
  const body = JSON.stringify(message);
  process.stdout.write(`Content-Length: ${Buffer.byteLength(body, "utf8")}\r\n\r\n${body}`);
}

function expandHome(value) {
  if (typeof value !== "string") return value;
  if (value === "~") return os.homedir();
  if (value.startsWith("~/")) return path.join(os.homedir(), value.slice(2));
  return value;
}
