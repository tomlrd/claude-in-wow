// Tools about the installed addons: what they are, whether they load, and the
// settings and data they save.

import { characterFolder, enabledAddons, installedAddons, savedVariablesFiles } from './addons.mjs';
import { fold, loadData, pickCharacter } from './game.mjs';
import { readSaved } from './saved.mjs';
import { outline, when } from './util.mjs';

const NOT_A_PROBLEM = ['DISABLED', 'DEMAND_LOADED', 'DEP_DISABLED']; // the player's choice, or loads when needed

export const ADDON_TOOLS = [
  {
    name: 'addons',
    description: 'The addons installed in the game, read from their folders: name, title, version, author, whether the character has them enabled (AddOns.txt) and, from the last claude-in-wow snapshot, whether they loaded and the game\'s reason when not (DISABLED, MISSING, DEP_MISSING, INTERFACE_VERSION...). With `search`, full details: notes, dependencies, saved data names, folder.',
    inputSchema: {
      type: 'object',
      properties: {
        search: { type: 'string', description: 'Part of an addon\'s folder name or title.' },
        problems_only: { type: 'boolean', description: 'Only addons enabled but not loaded, with a load problem, or missing a required dependency.' },
        character: { type: 'string', description: 'Part of a character\'s name, for its enabled list. By default the one played last.' },
      },
      additionalProperties: false,
    },
    run(args) {
      const data = loadData();
      if (data.error) return data;
      const installed = installedAddons(data.wowDir);
      const folder = characterFolder(data.wowDir, args.character);
      const enabled = folder ? enabledAddons(folder.dir) : {};
      const snapshot = data.noCompanion ? null : pickCharacter(data.db, args.character)?.data;
      const loadedInfo = new Map((snapshot?.addons || []).map((a) => [a.name, a]));
      const names = new Set(installed.map((a) => a.name));

      let list = installed.map((a) => {
        const info = loadedInfo.get(a.name);
        return {
          ...a,
          enabled: a.name in enabled ? enabled[a.name] : true,
          loaded: info ? info.loaded : undefined,
          reason: info?.reason || undefined,
          missingDependencies: a.dependencies.filter((d) => !names.has(d) && !d.startsWith('Blizzard_')),
        };
      });
      if (args.search) {
        const q = fold(args.search);
        list = list.filter((a) => fold(a.name).includes(q) || fold(a.title).includes(q));
      }
      if (args.problems_only) {
        list = list.filter((a) => a.missingDependencies.length || (a.enabled && a.loaded === false && !NOT_A_PROBLEM.includes(a.reason))
          || (a.reason && !NOT_A_PROBLEM.includes(a.reason)));
      }

      const detailed = Boolean(args.search) || list.length <= 10;
      return {
        character: folder ? `${folder.name} (${folder.realm})` : undefined,
        loadStateFrom: snapshot ? when(snapshot.reloadSavedAt ?? snapshot.savedAt) : 'no claude-in-wow snapshot: load state unknown',
        installed: installed.length,
        enabled: installed.filter((a) => (a.name in enabled ? enabled[a.name] : true)).length,
        addons: list.map((a) => (detailed ? a : {
          name: a.name, title: a.title, version: a.version, enabled: a.enabled, loaded: a.loaded, reason: a.reason,
          ...(a.missingDependencies.length ? { missingDependencies: a.missingDependencies } : {}),
        })),
      };
    },
  },
  {
    name: 'saved_variables',
    description: 'An addon\'s saved settings and data (its SavedVariables files, account-wide and for the character), as the game wrote them at the last reload or logout. Without `path`, an outline of what is there; with `path` (dot-separated keys, e.g. "QuestieConfig.profiles.Default"), that part in full. Read-only: settings may only be changed with the game closed.',
    inputSchema: {
      type: 'object',
      properties: {
        addon: { type: 'string', description: 'The addon\'s folder name, e.g. "Questie", "TradeSkillMaster".' },
        path: { type: 'string', description: 'Dot-separated keys from a saved global, e.g. "QuestieConfig.profileKeys". Numeric keys work too.' },
        depth: { type: 'number', description: 'How many levels to show (default 2 for an outline, 6 with a path).' },
        character: { type: 'string', description: 'Part of a character\'s name, for per-character files. By default the one played last.' },
      },
      required: ['addon'],
      additionalProperties: false,
    },
    run(args) {
      const data = loadData();
      if (data.error) return data;
      const folder = characterFolder(data.wowDir, args.character);
      const addon = installedAddons(data.wowDir).find((a) => fold(a.name) === fold(args.addon));
      const files = savedVariablesFiles(data.wowDir, addon?.name || args.addon, folder);
      if (!files.length) {
        return { error: `No saved data found for "${args.addon}". ${addon ? `It saves: ${[...addon.savedVariables, ...addon.savedVariablesPerCharacter].join(', ') || 'nothing'}.` : 'Check the folder name with the addons tool.'}` };
      }

      const results = files.map((f) => {
        const { mtimeMs, globals } = readSaved(f.file);
        const base = { scope: f.scope, file: f.file, saved: when(Math.round(mtimeMs / 1000)) };
        if (!args.path) {
          return { ...base, globals: outline(globals, Math.max(1, Math.min(Number(args.depth) || 2, 4))) };
        }
        let node = globals;
        for (const key of args.path.split('.')) {
          if (node === null || typeof node !== 'object') { node = undefined; break; }
          node = Array.isArray(node) ? node[Number(key) - 1] : node[key];
        }
        return { ...base, path: args.path, value: node === undefined ? 'nothing at this path' : outline(node, Math.max(1, Math.min(Number(args.depth) || 6, 12))) };
      });
      return { addon: addon?.name || args.addon, files: results };
    },
  },
];
