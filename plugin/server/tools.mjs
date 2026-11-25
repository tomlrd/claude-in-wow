// The tools: what the assistant can ask about the player's game, addons and
// auction house. All read-only.

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ADDON_TOOLS } from './addon-tools.mjs';
import { findFunctions } from './functions.mjs';
import { answerMark, toClipboard } from './clipboard.mjs';
import { deliver } from './deliver.mjs';
import { check, setAutostart } from './autostart.mjs';
import { running as silentRunning, start as silentStart, status as silentStatus, stop as silentStop } from './silent-mode.mjs';
import { characters, chooseGame, findGames, fold, listScreenshots, loadData, NO_COMPANION, pickCharacter, screenshotsDir, questsDone } from './game.mjs';
import { LOOKUP_TOOLS } from './lookup-tools.mjs';
import { ADDON_TOOL_NAMES, ADDONS_ENV } from './modules.mjs';
import { STRING_TOOLS } from './string-tools.mjs';
import { say } from './said.mjs';
import { undoUpdate } from './updates.mjs';
import { questionsAfter } from './photo.mjs';
import { PRICE_TOOLS } from './price-tools.mjs';
import { setSlots } from './slots.mjs';
import { capped, itemFacts, money, when } from './util.mjs';

const MAX_TEXT = 40000;

const characterArg = {
  type: 'string',
  description: 'Part of a character\'s name. Leave it out for the character of the newest snapshot.',
};

// What to run in the background to wait for the game's next question.
function listenCommand(after, hours = 4) {
  const script = path.join(path.dirname(fileURLToPath(import.meta.url)), 'listen.mjs').replace(/\\/g, '/');
  return `node "${script}" --after ${after} --hours ${hours}`;
}

// Data, the character asked for, or a reason to stop.
function context(args) {
  const data = loadData();
  if (data.error) return { error: data.error };
  if (data.noCompanion) return { error: NO_COMPANION };
  const picked = pickCharacter(data.db, args.character);
  if (!picked) {
    const names = characters(data.db).map((c) => c.key);
    return { error: `No snapshot for "${args.character}". Characters: ${names.join(', ') || 'none yet'}.` };
  }
  return { data, key: picked.key, char: picked.data };
}

// When the character was noted, and how.
function noted(char) {
  return { ...when(char.savedAt), by: char.fromPhoto ? 'photo taken in game' : 'reload or logout' };
}

// Each item as noted by the addon, with the mark the player pasted on it
// when there is one.
function items(container, marks) {
  return Object.entries(container?.items || {})
    .map(([id, item]) => {
      const mark = marks?.[id];
      return {
        id: Number(id),
        name: item.name,
        count: item.count,
        ...itemFacts(item),
        mark: mark ? { action: mark.action, reason: mark.reason } : undefined,
      };
    })
    .sort((a, b) => fold(a.name).localeCompare(fold(b.name)));
}

// How many items carry each mark, or undefined without marks.
function markCounts(marks) {
  const counts = {};
  for (const mark of Object.values(marks || {})) if (mark?.action) counts[mark.action] = (counts[mark.action] || 0) + 1;
  return Object.keys(counts).length ? counts : undefined;
}

const TOOLS = [
  {
    name: 'game_state',
    description: 'Snapshot of the player\'s World of Warcraft character, noted by the claude-in-wow addon at the last reload or logout, or by a photo the player took in game (/claude in the chat), whichever is newer: who, where (zone, subzone, map and coordinates in %, instance), group, professions, money, XP, equipped items, bag space, counts of quests (and of quests left out under folded headers) and Lua errors. Says how old the snapshot is. Call it first for any question about the player\'s game.',
    inputSchema: { type: 'object', properties: { character: characterArg }, additionalProperties: false },
    run(args) {
      const ctx = context(args);
      if (ctx.error) return ctx;
      const { data, key, char } = ctx;
      const c = char.character || {};
      return {
        character: key,
        snapshot: noted(char),
        level: c.level,
        class: c.class,
        race: c.race,
        faction: c.faction,
        guild: c.guild,
        money: money(c.money),
        xp: c.xpMax ? `${c.xp}/${c.xpMax} (${Math.round((100 * c.xp) / c.xpMax)}%)${c.rested ? `, rested ${c.rested}` : ''}` : undefined,
        maxHealth: c.healthMax,
        dead: c.dead || undefined,
        location: char.location,
        group: char.group,
        professions: char.professions,
        equipment: char.equipment,
        bags: char.bags ? { free: char.bags.free, slots: char.bags.slots, marked: markCounts(char.marks) } : undefined,
        bankNoted: char.bank ? when(char.bank.savedAt) : null,
        quests: (char.quests || []).length,
        questsNotListed: char.questsNotListed,
        luaErrors: (data.db.errors || []).length,
        otherCharacters: characters(data.db).map((x) => x.key).filter((k) => k !== key),
        question: char.question
          ? { text: char.question.text, kind: char.question.kind, asked: when(Number(char.question.at) || char.savedAt) }
          : undefined,
      };
    },
  },
  {
    name: 'listen',
    description: 'Listening to the game: the player sends questions from the game\'s Claude window, each in a photo with the game state. Gives the shell command that waits for the next one: run it in the background (Bash, run_in_background). It prints the question and exits when one arrives, which wakes you; answer it, then call listen again with the after it printed. Use when the player asks you to listen to the game.',
    inputSchema: {
      type: 'object',
      properties: {
        after: { type: 'number', description: 'Only questions sent after this time (unix seconds), e.g. the last one answered. Default: now.' },
        hours: { type: 'number', description: 'How long to wait before giving up (default 4).' },
      },
      additionalProperties: false,
    },
    run(args) {
      const after = Number.isFinite(args.after) ? Math.floor(args.after) : Math.floor(Date.now() / 1000);
      const hours = Number.isFinite(args.hours) && args.hours > 0 ? args.hours : 4;
      return {
        command: listenCommand(after, hours),
        after,
        howTo: 'Run the command in the background (run_in_background) and end your turn: you are woken when it exits. It prints the question, or that it stopped listening after the hours given.',
        silentMode: silentRunning()
          ? 'The silent mode is running: it answers the questions, but those sent while the player\'s setting "Who answers" (the addon\'s settings, tab Claude) says a session they see, which come here. To get all of them, tell the player to choose that, or stop the silent mode (silent_mode) if they prefer.'
          : undefined,
      };
    },
  },
  {
    name: 'silent_mode',
    description: 'The silent mode: Claude answers the questions sent from the game\'s Claude window with no conversation open. A hidden program waits for each question, asks Claude Code without a window (claude -p, the player\'s own account, these tools), and puts the answer in the clipboard with a sound, for the player to paste with Ctrl+V. It keeps one Claude conversation per conversation of the game\'s window. Actions: start (when the player asks for the silent mode, "mode silencieux"), stop, status, check (what the answers need: Claude Code, its sign-in, the game, the addon, the answer addons), game (where World of Warcraft is, when it was not found: folder, as the player says it), undo_update (the addon as it was before its last update from GitHub, the game closed: only when the player asks), autostart and no_autostart (starting with Windows: only when the player asks for it; it puts a small script in their Startup folder). It runs until stopped, and starts again by itself when a Claude session opens these tools after the computer restarted; each answer uses the player\'s usage like a message.',
    inputSchema: {
      type: 'object',
      properties: {
        action: { type: 'string', enum: ['start', 'stop', 'status', 'check', 'game', 'undo_update', 'autostart', 'no_autostart'] },
        folder: { type: 'string', description: 'For game: the World of Warcraft folder. For start and autostart: the folder Claude works in for the answers (its CLAUDE.md and memory apply), usually this conversation\'s working folder.' },
      },
      required: ['action'],
      additionalProperties: false,
    },
    run(args) {
      if (args.action === 'start') return silentStart(args.folder || process.cwd());
      if (args.action === 'stop') return silentStop();
      if (args.action === 'check') return check();
      if (args.action === 'game') return chooseGame(args.folder);
      if (args.action === 'undo_update') return undoUpdate();
      if (args.action === 'autostart') return setAutostart(true, args.folder || process.cwd());
      if (args.action === 'no_autostart') return setAutostart(false);
      return silentStatus();
    },
  },
  {
    name: 'answer_to_game',
    description: 'Answers a question sent from the game: your answer shows in the game\'s Claude window when the question asks for that (the player\'s setting), and goes in the system clipboard in any case, for the player to paste it there with Ctrl+V, with a short sound. Pass the answer exactly as you wrote it, Markdown and marks block included. It replaces what the player had in the clipboard. With asked in place of question: what the player said in this conversation itself, shown in the game with your answer.',
    inputSchema: {
      type: 'object',
      properties: {
        text: { type: 'string', description: 'The answer, as written to the player.' },
        question: { type: 'number', description: 'Which question it answers: the "after" the listen command printed. The game\'s window only takes an answer marked with its question, so always give it for a question from the game.' },
        asked: { type: 'string', description: 'What the player said in this conversation (typed or dictated), in their words, for it and your answer to show in the game\'s window. Never with question.' },
        sound: { type: 'boolean', description: 'Play the sound that tells the player it is ready (default true).' },
      },
      required: ['text'],
      additionalProperties: false,
    },
    run(args) {
      let text = String(args.text || '').trim();
      if (!text) return { error: 'No answer to copy.' };
      let delivered = false, left = null;
      const fromGame = Number.isFinite(args.question);
      if (!fromGame && String(args.asked || '').trim()) ({ text, delivered, left } = say(args.asked, text, args.sound !== false));
      if (fromGame) {
        text = `${answerMark(args.question)}\n\n${text}`;
        const games = findGames().map((wowDir) => ({ wowDir, asked: questionsAfter(screenshotsDir(wowDir), args.question - 1).find(({ at }) => at === args.question) }));
        const { wowDir, asked } = games.find((game) => game.asked) || {};
        if (asked) {
          try { setSlots(wowDir, asked.question.options?.slots); } catch { /* as many as there are */ }
          delivered = deliver(wowDir, asked.question, text, args.sound !== false).delivered;
        }
      }
      const result = toClipboard(text, args.sound !== false && !delivered);
      if (result.error && !delivered) return result;
      return {
        delivered, copied: !result.error, characters: text.length,
        next: fromGame ? `To wait for the next question, run in the background: ${listenCommand(Math.floor(args.question))}` : undefined,
        places: left === null ? undefined : left > 0 ? `${left} more can show by themselves before the player's next question or photo from the game.` : 'No place is left for more: the player\'s next question or photo from the game (with "Who answers" on a session they see) gives some.',
        tell: delivered ? 'The answer shows in the game\'s Claude window by itself (it is in the clipboard too).'
          : 'The answer is in the clipboard: the player presses Ctrl+V in the game\'s Claude window.',
      };
    },
  },
  {
    name: 'game_functions',
    description: 'Finds, among the thousands of functions the game documents, those that only read (their arguments, what they give): what a question proposed to the player in an answer can have read in the running game ("read" in the questions block of the wow skill). Search in English by what it is about ("trainer service", "auction", "C_Map area", "quest reward").',
    inputSchema: {
      type: 'object',
      properties: {
        search: { type: 'string', description: 'Words the function\'s name, arguments or results must all hold.' },
        limit: { type: 'number', description: 'At most this many (default 25).' },
      },
      required: ['search'],
      additionalProperties: false,
    },
    run(args) {
      return findFunctions(args.search, Math.min(Math.max(Number(args.limit) || 25, 1), 60));
    },
  },
  {
    name: 'quests',
    description: 'The quest log of the snapshot: each quest with its ID, level, zone header, dungeon or group tag, objectives (done, have/need) and whether it is complete or ready to hand in. Says when quests under a header folded in the game\'s log are left out.',
    inputSchema: {
      type: 'object',
      properties: {
        character: characterArg,
        search: { type: 'string', description: 'Part of a quest\'s title, zone or objectives (accents and case ignored), to narrow the list.' },
        ids: { type: 'array', items: { type: 'number' }, maxItems: 200, description: 'Numbers of quests: for each, whether it is in the log or handed in (as of the last reload or logout). In place of the log.' },
      },
      additionalProperties: false,
    },
    run(args) {
      const ctx = context(args);
      if (ctx.error) return ctx;
      let quests = ctx.char.quests || [];
      if (Array.isArray(args.ids)) {
        const log = new Map(quests.map((q) => [q.id, q]));
        const done = questsDone(ctx.char);
        return { character: ctx.key, quests: args.ids.map((id) => ({ id, title: log.get(id)?.title, inLog: log.has(id), handedIn: done ? done.has(id) : 'unknown until the next /reload' })) };
      }
      if (args.search) {
        const q = fold(args.search);
        quests = quests.filter((x) => fold(x.title).includes(q) || fold(x.zone).includes(q)
          || (x.objectives || []).some((o) => fold(o.text).includes(q)));
      }
      const notListed = ctx.char.questsNotListed
        ? `${ctx.char.questsNotListed} more quests are in the log under folded headers: the player can unfold them, then take a photo (/claude in the chat) or /reload.`
        : undefined;
      return { character: ctx.key, snapshot: noted(ctx.char), notListed, quests };
    },
  },
  {
    name: 'find_item',
    description: 'Finds an item by part of its name or by item ID in every character\'s bags, bank and equipped items, and in the account bank. The bank is only known as it was when last opened (its date is given).',
    inputSchema: {
      type: 'object',
      properties: {
        search: { type: 'string', description: 'Part of the item\'s name (accents and case ignored), or its item ID.' },
        character: { type: 'string', description: 'Only this character (part of its name). Leave it out to search them all.' },
      },
      required: ['search'],
      additionalProperties: false,
    },
    run(args) {
      const data = loadData();
      if (data.error) return data;
      const q = fold(args.search);
      const id = /^\d+$/.test(args.search.trim()) ? Number(args.search.trim()) : null;
      const match = (itemID, name) => (id ? itemID === id : fold(name).includes(q));
      const found = [];

      const look = (owner, place, container, noted, marks) => {
        for (const item of items(container, marks)) {
          if (match(item.id, item.name)) found.push({ owner, place, ...item, ...(noted ? { noted } : {}) });
        }
      };

      const list = args.character ? [pickCharacter(data.db, args.character)].filter(Boolean) : characters(data.db);
      for (const { key, data: char } of list) {
        look(key, 'bags', char.bags, undefined, char.marks);
        if (char.bank) look(key, 'bank', char.bank, when(char.bank.savedAt));
        for (const [slot, item] of Object.entries(char.equipment || {})) {
          if (match(item.id, item.name)) found.push({ owner: key, place: `equipped (${slot})`, id: item.id, name: item.name, count: 1 });
        }
      }
      if (data.db.warbandBank) look('account', 'account bank', data.db.warbandBank, when(data.db.warbandBank.savedAt));
      return { search: args.search, found };
    },
  },
  {
    name: 'inventory',
    description: 'Everything in the character\'s bags, bank (as last opened) or account bank, added up by item, or the equipped items with durability. Each item with what its tooltip says (gear stats, "Use:" and "Equip:" effects, description) and, in the bags, the mark the player pasted from the assistant (sell, destroy, bank...).',
    inputSchema: {
      type: 'object',
      properties: {
        character: characterArg,
        where: { type: 'string', enum: ['bags', 'bank', 'equipped', 'account bank'], description: 'Which container. Bags by default.' },
      },
      additionalProperties: false,
    },
    run(args) {
      const ctx = context(args);
      if (ctx.error) return ctx;
      const where = args.where || 'bags';
      if (where === 'equipped') return { character: ctx.key, equipped: ctx.char.equipment || {} };
      const container = where === 'bank' ? ctx.char.bank : where === 'account bank' ? ctx.data.db.warbandBank : ctx.char.bags;
      if (!container) return { character: ctx.key, where, note: where === 'bags' ? 'No bag data.' : 'Not noted yet: the player has to open it once.' };
      return {
        character: ctx.key,
        where,
        noted: when(container.savedAt || ctx.char.savedAt),
        free: container.free,
        slots: container.slots,
        items: items(container, where === 'bags' ? ctx.char.marks : undefined),
      };
    },
  },
  {
    name: 'lua_errors',
    description: 'The last Lua errors and blocked actions (taint) the game had, newest first, with their stack, how many times they came and on which character. The game hides them by default, so the player may not have seen them.',
    inputSchema: {
      type: 'object',
      properties: {
        limit: { type: 'number', description: 'How many, 10 by default.' },
        include_stack: { type: 'boolean', description: 'With the stack traces (default true).' },
      },
      additionalProperties: false,
    },
    run(args) {
      const data = loadData();
      if (data.error) return data;
      const limit = Math.max(1, Math.min(Number(args.limit) || 10, 30));
      const errors = (data.db.errors || []).slice(0, limit).map((e) => ({
        kind: e.kind,
        message: e.message,
        count: e.count,
        character: e.character,
        ...when(e.time),
        ...(args.include_stack === false ? {} : { stack: e.stack }),
      }));
      return { total: (data.db.errors || []).length, errors };
    },
  },
  {
    name: 'screenshots',
    description: 'The newest screenshots of the game (taken with the game\'s screenshot key), newest first, as file paths with their time. Open one with the Read tool to look at it.',
    inputSchema: {
      type: 'object',
      properties: { count: { type: 'number', description: 'How many, 3 by default.' } },
      additionalProperties: false,
    },
    run(args) {
      const data = loadData();
      if (!data.wowDir) return data;
      const count = Math.max(1, Math.min(Number(args.count) || 3, 20));
      const shots = listScreenshots(data.wowDir, count).map((s) => ({
        path: s.file,
        ...when(Math.round(s.mtimeMs / 1000)),
        ...(/\.tga$/i.test(s.file) ? { note: 'TGA: may not open. The game can save JPG instead (screenshotFormat).' } : {}),
      }));
      return { screenshots: shots };
    },
  },
  ...ADDON_TOOLS,
  ...PRICE_TOOLS,
  ...LOOKUP_TOOLS,
  ...STRING_TOOLS,
];

export function listTools() {
  return TOOLS.map(({ name, description, inputSchema, readOnly }) => ({
    name,
    description,
    inputSchema,
    annotations: readOnly === false
      ? { readOnlyHint: false, destructiveHint: false, idempotentHint: true, openWorldHint: false }
      : { readOnlyHint: true, openWorldHint: false },
  }));
}

const REFUSED = "This question does not let you look in the player's addons: use the game's own data, the web, or what you know; or propose it as a question naming the addon.";

export async function callTool(name, args) {
  const tool = TOOLS.find((t) => t.name === name);
  if (!tool) return { isError: true, content: [{ type: 'text', text: `Unknown tool: ${name}` }] };
  if (process.env[ADDONS_ENV] === 'no' && ADDON_TOOL_NAMES.has(name)) {
    return { isError: true, content: [{ type: 'text', text: REFUSED }] };
  }
  try {
    const result = await tool.run(args || {});
    const isError = Boolean(result && result.error && Object.keys(result).length <= 2);
    return { isError, content: [{ type: 'text', text: capped(JSON.stringify(result, null, 1), MAX_TEXT) }] };
  } catch (err) {
    return { isError: true, content: [{ type: 'text', text: `Error: ${err.message}` }] };
  }
}
