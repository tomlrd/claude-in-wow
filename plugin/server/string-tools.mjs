// Tools for what the player pastes in an addon: import strings (strings.mjs),
// and the game's numbers for names (names.mjs).

import { ADDONS_ENV } from './modules.mjs';
import { numbers } from './names.mjs';
import { importString, keepString, trackerAura } from './strings.mjs';

const MAX_LINES = 40;
const silent = () => process.env[ADDONS_ENV] !== undefined; // asked from the game (silent.mjs)

// The items and quests of the lines given by name, by number; the names not found.
async function withNumbers(lines) {
  const byName = (value) => typeof value === 'string' && !/^\d+$/.test(value.trim());
  const names = lines.flatMap((line) => [line.item, line.quest].filter(byName));
  const found = names.length ? await numbers(names) : new Map();
  const notFound = [];
  const known = lines.map((line) => {
    const out = { ...line };
    for (const kind of ['item', 'quest']) {
      if (!byName(line[kind])) continue;
      const entry = found.get(line[kind].trim());
      if (entry?.type === kind) out[kind] = entry.id;
      else { notFound.push(line[kind]); delete out[kind]; }
      out.text = out.text || line[kind];
    }
    return out;
  });
  return { known, notFound };
}

export const STRING_TOOLS = [
  {
    name: 'import_string',
    description: 'Makes an import string for the player to paste in an addon. With `lines`: an aura for ForeverAuras (or WeakAuras) that shows on screen a list to follow, each line with how many the character has (bags and bank) or whether a quest is done, up to date as they play. With `table`: any table another addon exports in the "!" format (AceSerializer, deflate, printable letters), written as JSON. Gives the string, or the mark that stands for it in an answer to the game.',
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'The aura\'s name in the addon, short.' },
        title: { type: 'string', description: 'The title over the list, in the player\'s language.' },
        lines: {
          type: 'array',
          maxItems: MAX_LINES,
          items: {
            type: 'object',
            properties: {
              header: { type: 'boolean', description: 'A heading: its text only.' },
              text: { type: 'string', description: 'A heading\'s or a line\'s text; for an item or a quest, its name until the game knows it.' },
              item: { type: ['string', 'number'], description: 'An item: its exact name (French or English) or its number.' },
              need: { type: 'number', description: 'How many are needed.' },
              quest: { type: ['string', 'number'], description: 'A quest: its exact name or its number.' },
              currency: { type: 'number', description: 'A currency\'s number.' },
            },
            additionalProperties: false,
          },
        },
        table: { type: 'object', description: 'A whole table as the addon exports it, in place of lines.' },
      },
      required: ['name'],
      additionalProperties: false,
    },
    async run(args) {
      let table = args.table, notFound = [];
      if (!table) {
        if (!Array.isArray(args.lines) || !args.lines.length) return { error: 'Give the lines of the list (or a table).' };
        const { known, notFound: missing } = await withNumbers(args.lines.slice(0, MAX_LINES));
        notFound = missing;
        table = trackerAura(String(args.name).slice(0, 60), args.title || args.name, known);
      }
      const text = importString(table);
      return {
        string: silent() ? keepString(text) : text,
        characters: text.length,
        notFound: notFound.length ? { names: notFound, note: 'No such name in Wowhead\'s search: these lines are only text. Look for the exact name and make the string again.' } : undefined,
        ...(silent() ? { put: `Write it as it is in a code block of its own: the first line "[claude-in-wow] string ${args.name}", the second this mark. The window makes it a button that copies the string.` } : {}),
      };
    },
  },
  {
    name: 'numbers',
    description: 'The game\'s numbers for names of items, quests, creatures and characters, from Wowhead\'s search for the version played (exact names, in English or in the client\'s language).',
    inputSchema: {
      type: 'object',
      properties: { names: { type: 'array', items: { type: 'string' }, maxItems: 12 } },
      required: ['names'],
      additionalProperties: false,
    },
    async run(args) {
      const found = await numbers(args.names || []);
      return { found: [...found].map(([asked, { type, id, name }]) => ({ asked, type, id, name })), notFound: (args.names || []).filter((name) => !found.has(String(name).trim())) };
    },
  },
];
