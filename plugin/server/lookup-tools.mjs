// Game knowledge from the player's own addons: quests, NPCs and items from
// Questie's database, gathering nodes from GatherMate2's records.

import { characterFolder, savedVariablesFiles } from './addons.mjs';
import { decodeCoord, KINDS, nodeNames } from './gather.mjs';
import { flavorOf } from './flavors.mjs';
import { characters, findWowDir, fold, loadData, notedItems, pickCharacter, questsDone } from './game.mjs';
import { loadPrices, priceOf } from './prices.mjs';
import { loadQuestie, slot, values } from './questie.mjs';
import { readSaved } from './saved.mjs';
import { itemFacts } from './util.mjs';
import { mapName, uiMapOf, zoneName } from './zones.mjs';

const NO_QUESTIE = 'Questie\'s database (the QuestieDB addon) is not installed: use Wowhead instead.';
const RANKS = ['normal', 'elite', 'rare elite', 'boss', 'rare'];
const MAX_MATCHES = 10;

const wowhead = (type, id) => `https://www.wowhead.com${flavorOf(findWowDir()).wowhead[0]}/fr/${type}=${id}`;

// Where an NPC or object spawns: zones by number of spawns, a few coordinates
// each, and the game's map of the zone (uiMapID, for map links in answers).
function where(wowDir, spawns, maxZones = 4, maxPoints = 3) {
  if (!spawns || typeof spawns !== 'object') return [];
  return Object.entries(spawns)
    .map(([area, points]) => ({ area, points: values(points) }))
    .sort((a, b) => b.points.length - a.points.length)
    .slice(0, maxZones)
    .map(({ area, points }) => ({
      zone: zoneName(wowDir, area),
      uiMapID: uiMapOf(wowDir, area),
      spawns: points.length,
      coords: [...new Set(points.slice(0, maxPoints).map((p) => (p[0] < 0 ? 'inside the instance' : `${Math.round(p[0] * 10) / 10} ${Math.round(p[1] * 10) / 10}`)))],
    }));
}

// IDs matching a number or part of a name (French first, then English).
function resolve(db, type, query) {
  const text = String(query ?? '').trim();
  if (/^\d+$/.test(text)) return db.record(type, Number(text)) ? [Number(text)] : [];
  const q = fold(text);
  if (!q) return [];
  const exact = [], partial = [];
  for (const id of db.ids(type)) {
    const fr = db.french(type, id)[0];
    const name = fold(typeof fr === 'string' ? fr : '');
    if (name === q) exact.push(id); else if (name.includes(q)) partial.push(id);
  }
  if (!exact.length && !partial.length) {
    for (const id of db.ids(type)) {
      const name = fold(db.record(type, id)?.name);
      if (name === q) exact.push(id); else if (name.includes(q)) partial.push(id);
    }
  }
  return [...exact, ...partial];
}

function brief(db, type, id) {
  const rec = db.record(type, id);
  return rec ? { id, name: db.name(type, id), ...(type === 'Quest' && rec.questLevel ? { level: rec.questLevel } : {}) } : { id };
}

function matches(db, type, ids) {
  return { matches: ids.slice(0, 25).map((id) => brief(db, type, id)), more: Math.max(0, ids.length - 25), note: 'Several match: ask again with an ID.' };
}

// Quests the character has handed in: the game's own list when the addon noted
// it, else Questie's and ItemQuester's saved data.
function completed(wowDir, characterQuery) {
  const data = loadData();
  const character = data.noCompanion ? undefined : pickCharacter(data.db, characterQuery);
  const noted = questsDone(character?.data);
  if (noted) return noted;
  const key = character?.key;
  const done = new Set();
  let known = false;
  try {
    for (const f of savedVariablesFiles(wowDir, 'Questie', null)) {
      const chars = readSaved(f.file).globals.QuestieConfig?.char || {};
      const mine = (key && chars[key]) || Object.values(chars)[0];
      if (mine?.complete) { known = true; for (const id of Object.keys(mine.complete)) done.add(Number(id)); }
    }
    const folder = characterFolder(wowDir, characterQuery || key);
    for (const f of savedVariablesFiles(wowDir, 'ItemQuesterForever', folder)) {
      const turnedIn = readSaved(f.file).globals.ItemQuesterForeverCharDB?.turnedIn;
      if (turnedIn) { known = true; for (const id of Object.keys(turnedIn)) done.add(Number(id)); }
    }
  } catch { /* unreadable: unknown */ }
  return known ? done : null;
}

// NPCs, objects and items in a Questie {npcs, objects, items} list.
function actors(db, wowDir, list) {
  const out = [];
  for (const id of values(slot(list, 1)).flat()) out.push({ type: 'npc', ...brief(db, 'Npc', id), where: where(wowDir, db.record('Npc', id)?.spawns, 2, 2) });
  for (const id of values(slot(list, 2)).flat()) out.push({ type: 'object', ...brief(db, 'Object', id), where: where(wowDir, db.record('Object', id)?.spawns, 2, 2) });
  for (const id of values(slot(list, 3)).flat()) out.push({ type: 'item', ...brief(db, 'Item', id) });
  return out;
}

function questDetails(db, wowDir, id, characterQuery) {
  const q = db.record('Quest', id);
  const fr = db.french('Quest', id);
  const objectives = q.objectives || [];
  const done = completed(wowDir, characterQuery);
  const zone = q.zoneOrSort ? zoneName(wowDir, q.zoneOrSort) : undefined;
  return {
    id,
    name: db.name('Quest', id),
    nameEnglish: q.name,
    level: q.questLevel,
    requiredLevel: q.requiredLevel,
    zone,
    objectivesText: values(fr[1]).length ? values(fr[1]) : values(q.objectivesText),
    startedBy: actors(db, wowDir, q.startedBy),
    finishedBy: actors(db, wowDir, q.finishedBy),
    kill: values(slot(objectives, 1)).map((o) => ({ ...brief(db, 'Npc', o[0]), where: where(wowDir, db.record('Npc', o[0])?.spawns, 3, 3) })),
    use: values(slot(objectives, 2)).map((o) => ({ ...brief(db, 'Object', o[0]), where: where(wowDir, db.record('Object', o[0])?.spawns, 3, 3) })),
    collect: values(slot(objectives, 3)).map((o) => {
      const item = db.record('Item', o[0]);
      return {
        ...brief(db, 'Item', o[0]),
        droppedBy: values(item?.npcDrops).slice(0, 5).map((n) => ({ ...brief(db, 'Npc', n), where: where(wowDir, db.record('Npc', n)?.spawns, 1, 2) })),
        fromObjects: values(item?.objectDrops).slice(0, 5).map((o2) => ({ ...brief(db, 'Object', o2), where: where(wowDir, db.record('Object', o2)?.spawns, 1, 2) })),
      };
    }),
    requires: [...values(q.preQuestSingle), ...values(q.preQuestGroup)].map((p) => ({ ...brief(db, 'Quest', p), done: done ? done.has(p) : undefined })),
    nextQuest: q.nextQuestInChain ? brief(db, 'Quest', q.nextQuestInChain) : undefined,
    handedIn: done ? done.has(id) : 'unknown',
    wowhead: wowhead('quest', id),
  };
}

// Items the quests give at their start, need, or ask to collect, from all
// of Questie's quests, read once per database: item ID -> [{ quest, role }].
const questItemIndex = new WeakMap();
function questsForItems(db) {
  let index = questItemIndex.get(db);
  if (index) return index;
  index = new Map();
  const add = (item, quest, role) => {
    if (typeof item !== 'number') return;
    const list = index.get(item) || [];
    if (!list.some((x) => x.quest === quest)) list.push({ quest, role });
    index.set(item, list);
  };
  for (const id of db.ids('Quest')) {
    const q = db.record('Quest', id);
    if (!q) continue;
    add(q.sourceItemId, id, 'comes with the quest');
    for (const item of values(q.requiredSourceItems)) add(item, id, 'needed by the quest');
    for (const o of values(slot(q.objectives, 3))) add(slot(o, 1), id, 'to collect');
  }
  questItemIndex.set(db, index);
  return index;
}

// The quests an item is for, with whether each is in the log or handed in.
function itemQuests(db, wowDir, data, id, it) {
  const roles = new Map();
  for (const q of values(it?.startQuest)) roles.set(q, 'starts the quest');
  for (const { quest, role } of questsForItems(db).get(id) || []) if (!roles.has(quest)) roles.set(quest, role);
  for (const q of values(it?.relatedQuests)) if (!roles.has(q)) roles.set(q, 'related');
  if (!roles.size) return [];
  const done = completed(wowDir);
  const char = data.noCompanion ? null : pickCharacter(data.db);
  const inLog = new Set((char?.data.quests || []).map((q) => q.id));
  return [...roles].slice(0, 12).map(([q, role]) => ({
    ...brief(db, 'Quest', q),
    role,
    inLog: inLog.has(q) || undefined,
    handedIn: done ? done.has(q) : undefined,
  }));
}

// What the game itself says of an item the player has, from the snapshots.
function inGame(entry) {
  if (!entry) return undefined;
  const { name, count, ...item } = entry.item;
  return { name, ...itemFacts(item), owned: entry.places };
}

// Item IDs whose name in the snapshots matches (the game's own names, which
// Questie may not have in French for Forever's items).
function resolveNoted(noted, query) {
  const text = String(query ?? '').trim();
  if (/^\d+$/.test(text)) return noted.has(Number(text)) ? [Number(text)] : [];
  const q = fold(text);
  const exact = [], partial = [];
  for (const [id, { item }] of noted) {
    const name = fold(item.name);
    if (name === q) exact.push(id); else if (q && name.includes(q)) partial.push(id);
  }
  return [...exact, ...partial];
}

function lookup(type, run) {
  return (args) => {
    const data = loadData();
    if (data.error) return data;
    const db = loadQuestie(data.wowDir);
    let ids = db ? resolve(db, type, args.query) : [];
    if (!ids.length && type === 'Item' && !data.noCompanion) {
      // an item the player has, under the game's name, or one Questie lacks
      const noted = notedItems(data.db);
      const found = resolveNoted(noted, args.query);
      if (found.length && db?.record('Item', found[0])) ids = found;
      else if (found.length) return notedOnly(data, found[0], noted.get(found[0]), !db);
    }
    if (!db) return { error: NO_QUESTIE };
    if (!ids.length) return { error: `Nothing called "${args.query}" in Questie's database: try the English name, an ID, or Wowhead.` };
    if (ids.length > 1 && !/^\d+$/.test(String(args.query).trim()) && fold(db.name(type, ids[0])) !== fold(args.query)) return matches(db, type, ids);
    return run(db, data.wowDir, ids[0], args, data);
  };
}

// An item Questie does not know (or no Questie at all), from what the
// snapshots noted of it.
function notedOnly(data, id, entry, noQuestie) {
  const prices = loadPrices(data.wowDir);
  return {
    id,
    name: entry.item.name,
    note: noQuestie ? `${NO_QUESTIE} What the game says of it, from the player's snapshot:`
      : 'Not in Questie\'s database: what the game says of it, from the player\'s snapshot.',
    inGame: inGame(entry),
    price: prices ? priceOf(prices, id) || undefined : undefined,
    wowhead: wowhead('item', id),
  };
}

export const LOOKUP_TOOLS = [
  {
    name: 'quest_info',
    description: 'A quest from Questie\'s database (installed with the game\'s addons, Forever quests included): French and English names, level, zone, who gives and takes it and where (coordinates in % of the zone map), objectives with where the creatures, objects and drops are, the quests it needs, the next one, whether the character handed it in, and its Wowhead link. By ID or part of its name.',
    inputSchema: {
      type: 'object',
      properties: {
        query: { type: 'string', description: 'The quest\'s ID or part of its name (French or English).' },
        character: { type: 'string', description: 'Part of a character\'s name, for "handed in". By default the newest snapshot\'s.' },
      },
      required: ['query'],
      additionalProperties: false,
    },
    run: lookup('Quest', (db, wowDir, id, args) => questDetails(db, wowDir, id, args.character)),
  },
  {
    name: 'npc_info',
    description: 'An NPC or creature from Questie\'s database: French and English names, title, level, rank (elite, rare, boss), faction, where it spawns (zones and coordinates in %), the quests it gives and takes, and its Wowhead link. By ID or part of its name.',
    inputSchema: {
      type: 'object',
      properties: { query: { type: 'string', description: 'The NPC\'s ID or part of its name (French or English).' } },
      required: ['query'],
      additionalProperties: false,
    },
    run: lookup('Npc', (db, wowDir, id) => {
      const n = db.record('Npc', id);
      const fr = db.french('Npc', id);
      return {
        id,
        name: db.name('Npc', id),
        nameEnglish: n.name,
        title: (typeof fr[1] === 'string' && fr[1]) || n.subName,
        level: n.minLevel === n.maxLevel ? n.minLevel : `${n.minLevel}-${n.maxLevel}`,
        rank: RANKS[n.rank || 0],
        friendlyTo: { A: 'Alliance', H: 'Horde', AH: 'Alliance and Horde' }[n.friendlyToFaction] || 'hostile or neutral',
        where: where(wowDir, n.spawns, 6, 5),
        givesQuests: values(n.questStarts).slice(0, 20).map((q) => brief(db, 'Quest', q)),
        takesQuests: values(n.questEnds).slice(0, 20).map((q) => brief(db, 'Quest', q)),
        wowhead: wowhead('npc', id),
      };
    }),
  },
  {
    name: 'item_info',
    description: 'An item from Questie\'s database: French and English names, item level, required level, which creatures drop it and where, which objects hold it, who sells it, the quests it starts or rewards, the quests it is for (given at their start, needed, to collect) with whether each is in the log or already handed in, its auction house price when TradeSkillMaster has one, and its Wowhead link. For an item the player has: what the game says of it (French name, stats, "Use:" and "Equip:" effects, description) and who has it, even when Questie lacks it. By ID or part of its name (French or English).',
    inputSchema: {
      type: 'object',
      properties: { query: { type: 'string', description: 'The item\'s ID or part of its name (French or English).' } },
      required: ['query'],
      additionalProperties: false,
    },
    run: lookup('Item', (db, wowDir, id, args, data) => {
      const it = db.record('Item', id);
      const prices = loadPrices(wowDir);
      const noted = data.noCompanion ? undefined : notedItems(data.db).get(id);
      const french = db.french('Item', id)[0];
      const quests = itemQuests(db, wowDir, data, id, it);
      return {
        id,
        name: (typeof french === 'string' && french) || noted?.item.name || it.name,
        nameEnglish: it.name,
        itemLevel: it.itemLevel,
        requiredLevel: it.requiredLevel,
        droppedBy: values(it.npcDrops).slice(0, 10).map((n) => ({ ...brief(db, 'Npc', n), where: where(wowDir, db.record('Npc', n)?.spawns, 1, 2) })),
        fromObjects: values(it.objectDrops).slice(0, 10).map((o) => ({ ...brief(db, 'Object', o), where: where(wowDir, db.record('Object', o)?.spawns, 2, 2) })),
        soldBy: values(it.vendors).slice(0, 10).map((n) => ({ ...brief(db, 'Npc', n), where: where(wowDir, db.record('Npc', n)?.spawns, 1, 1) })),
        startsQuest: quests.find((q) => q.role === 'starts the quest'),
        rewardFrom: values(it.questRewards).slice(0, 10).map((q) => brief(db, 'Quest', q)),
        usedFor: quests.filter((q) => q.role !== 'starts the quest'),
        inGame: inGame(noted),
        price: prices ? priceOf(prices, id) || undefined : undefined,
        wowhead: wowhead('item', id),
      };
    }),
  },
  {
    name: 'gathering',
    description: 'The gathering nodes (mining, herbs, fishing pools, treasure) the player\'s GatherMate2 has recorded while playing, by zone with coordinates in % of the zone map. With `node` (e.g. "mithril", "Gisement de vrai-argent"), where that node was seen; with `zone`, what was seen there; with neither, a summary.',
    inputSchema: {
      type: 'object',
      properties: {
        node: { type: 'string', description: 'Part of a node\'s name, French or English.' },
        zone: { type: 'string', description: 'Part of a zone\'s name.' },
      },
      additionalProperties: false,
    },
    run(args) {
      const data = loadData();
      if (data.error) return data;
      const files = savedVariablesFiles(data.wowDir, 'GatherMate2', null);
      if (!files.length) return { error: 'No GatherMate2 data: the GatherMate2 addon records nodes as the player gathers.' };
      const names = nodeNames(data.wowDir);
      const nodes = []; // { kind, node, zone, uiMapID, x, y }
      for (const f of files) {
        const globals = readSaved(f.file).globals;
        for (const [table, kind] of Object.entries(KINDS)) {
          for (const [map, points] of Object.entries(globals[table] || {})) {
            const zone = mapName(data.wowDir, map);
            for (const [key, nodeId] of Object.entries(points || {})) {
              nodes.push({ kind, node: names[kind]?.get(Number(nodeId)) || `${kind} ${nodeId}`, zone, uiMapID: Number(map), ...decodeCoord(key) });
            }
          }
        }
      }
      const count = (list, by) => Object.entries(list.reduce((acc, n) => { acc[n[by]] = (acc[n[by]] || 0) + 1; return acc; }, {}))
        .sort((a, b) => b[1] - a[1]);
      let list = nodes;
      if (args.node) list = list.filter((n) => fold(n.node).includes(fold(args.node)));
      if (args.zone) list = list.filter((n) => fold(n.zone).includes(fold(args.zone)));
      if (!list.length) return { error: 'Nothing recorded matches. GatherMate2 only knows the nodes the player has seen.' };

      if (!args.node && !args.zone) {
        return {
          recorded: nodes.length,
          byKind: count(nodes, 'kind').map(([kind, n]) => ({ kind, nodes: n, mostSeen: count(nodes.filter((x) => x.kind === kind), 'node').slice(0, 8).map(([node, c]) => `${node} (${c})`) })),
        };
      }
      const zones = count(list, 'zone');
      return {
        found: list.length,
        nodes: count(list, 'node').slice(0, 15).map(([node, c]) => `${node} (${c})`),
        zones: zones.slice(0, 10).map(([zone, c]) => ({
          zone,
          uiMapID: list.find((n) => n.zone === zone)?.uiMapID,
          count: c,
          coords: list.filter((n) => n.zone === zone).slice(0, 40).map((n) => (args.node ? `${n.x} ${n.y}` : `${n.node} ${n.x} ${n.y}`)),
        })),
      };
    },
  },
];
