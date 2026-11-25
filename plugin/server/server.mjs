#!/usr/bin/env node
// claude-in-wow MCP server: stdio, newline-delimited JSON-RPC, no
// dependencies. Only MCP messages go to stdout; logs go to stderr.

import fs from 'node:fs';
import readline from 'node:readline';
import { resume } from './silent-mode.mjs';
import { callTool, listTools } from './tools.mjs';

const VERSION = JSON.parse(fs.readFileSync(new URL('../.claude-plugin/plugin.json', import.meta.url), 'utf8')).version;
const PROTOCOLS = ['2025-11-25', '2025-06-18', '2025-03-26', '2024-11-05'];

const INSTRUCTIONS = 'Reads the player\'s World of Warcraft install (the version played last): the character snapshot the claude-in-wow addon '
  + 'notes at every reload or logout, or at a photo the player takes in game (/claude photo in the chat: '
  + 'no reload needed). Check its age; when the present matters, ask for a photo. Also the installed addons '
  + 'and their saved settings and data, and auction house prices from TradeSkillMaster\'s data. '
  + 'Read-only: nothing here acts in the game, and saved files may only be changed with the game closed; '
  + 'the only files it deletes are the addon\'s own photos in the Screenshots folder, once read and replaced.';

function send(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}

function reply(id, result) {
  send({ jsonrpc: '2.0', id, result });
}

function error(id, code, message) {
  send({ jsonrpc: '2.0', id, error: { code, message } });
}

function handle(message) {
  const { id, method, params } = message;
  const isRequest = id !== undefined && id !== null;

  switch (method) {
    case 'initialize': {
      const asked = params?.protocolVersion;
      reply(id, {
        protocolVersion: PROTOCOLS.includes(asked) ? asked : PROTOCOLS[0],
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: 'claude-in-wow', version: VERSION },
        instructions: INSTRUCTIONS,
      });
      return;
    }
    case 'ping':
      reply(id, {});
      return;
    case 'tools/list':
      reply(id, { tools: listTools() });
      return;
    case 'tools/call':
      callTool(params?.name, params?.arguments).then((result) => reply(id, result));
      return;
    default:
      if (isRequest) error(id, -32601, `Method not found: ${method}`);
  }
}

const input = readline.createInterface({ input: process.stdin, terminal: false });
input.on('line', (line) => {
  if (!line.trim()) return;
  let message;
  try {
    message = JSON.parse(line);
  } catch {
    error(null, -32700, 'Parse error');
    return;
  }
  try {
    handle(message);
  } catch (err) {
    console.error(err);
    if (message.id !== undefined) error(message.id, -32603, String(err.message || err));
  }
});
input.on('close', () => process.exit(0));

try { resume(); } catch (err) { console.error(err); }
