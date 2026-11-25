// Questie's quest, NPC, item and object database (the QuestieDB addon), read
// offline. QuestieDB stores it in its .toc file as "## X-..." lines:
//   X-<Type>-IDS          base64 of zlib of a CBOR array of the IDs, ascending
//   X-<Type>-<id>-S       base64 of CBOR {fieldIndex: value, p: presence bits}
//   X-<Type>-<id>-<field> base64 of CBOR, one table field
//   X-l10n-frFR-<Type>    base64 of zlib of CBOR columns ([name, ...]) by ID position
// A value "~N~" is cut into keys "<key>-1" .. "<key>-N". Strings are CBOR byte
// strings of UTF-8; sparse Lua lists come as maps with integer keys.

import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';

export const TYPES = { quest: 'Quest', npc: 'Npc', item: 'Item', object: 'Object' };

// Field names by index (1-based), from QuestieDB's meta files.
const FIELDS = {
  Quest: ['name', 'startedBy', 'finishedBy', 'requiredLevel', 'questLevel', 'requiredRaces', 'requiredClasses', 'objectivesText',
    'triggerEnd', 'objectives', 'sourceItemId', 'preQuestGroup', 'preQuestSingle', 'childQuests', 'inGroupWith', 'exclusiveTo',
    'zoneOrSort', 'requiredSkill', 'requiredMinRep', 'requiredMaxRep', 'requiredSourceItems', 'nextQuestInChain', 'questFlags',
    'specialFlags', 'parentQuest', 'reputationReward', 'breadcrumbForQuestId', 'breadcrumbs', 'extraObjectives', 'requiredSpell',
    'requiredSpecialization', 'requiredMaxLevel', 'availableUntilCompleted', 'availableStartingWith', 'requiredRanks', 'disabledByQuest'],
  Npc: ['name', null, null, 'minLevel', 'maxLevel', 'rank', 'spawns', 'waypoints', 'zoneID', 'questStarts', 'questEnds', 'factionID',
    'friendlyToFaction', 'subName', 'npcFlags'],
  Item: ['name', 'npcDrops', 'objectDrops', 'itemDrops', 'startQuest', 'questRewards', 'flags', 'foodType', 'itemLevel', 'requiredLevel',
    'ammoType', 'class', 'subClass', 'vendors', 'relatedQuests', 'teachesSpell'],
  Object: ['name', 'questStarts', 'questEnds', 'spawns', 'zoneID', 'factionID', 'waypoints'],
};

export function decodeCbor(buf) {
  let pos = 0;
  const length = (info) => {
    if (info < 24) return info;
    if (info === 24) return buf[pos++];
    if (info === 25) { const v = buf.readUInt16BE(pos); pos += 2; return v; }
    if (info === 26) { const v = buf.readUInt32BE(pos); pos += 4; return v; }
    if (info === 27) { const v = Number(buf.readBigUInt64BE(pos)); pos += 8; return v; }
    if (info === 31) return -1; // indefinite
    throw new Error(`CBOR: bad length ${info}`);
  };
  const half = (h) => {
    const exp = (h >> 10) & 0x1f;
    const mant = h & 0x3ff;
    const v = exp === 0 ? mant * 2 ** -24 : exp === 31 ? (mant ? NaN : Infinity) : (mant + 1024) * 2 ** (exp - 25);
    return h & 0x8000 ? -v : v;
  };
  const item = () => {
    const byte = buf[pos++];
    const major = byte >> 5;
    const info = byte & 31;
    switch (major) {
      case 0: return length(info);
      case 1: return -1 - length(info);
      case 2: case 3: {
        const n = length(info);
        if (n < 0) { let s = ''; while (buf[pos] !== 0xff) s += item(); pos++; return s; }
        const s = buf.toString('utf8', pos, pos + n);
        pos += n;
        return s;
      }
      case 4: {
        const n = length(info);
        const list = [];
        if (n < 0) { while (buf[pos] !== 0xff) list.push(item()); pos++; } else for (let i = 0; i < n; i++) list.push(item());
        return list;
      }
      case 5: {
        const n = length(info);
        const map = {};
        const one = () => { const k = item(); map[String(k)] = item(); };
        if (n < 0) { while (buf[pos] !== 0xff) one(); pos++; } else for (let i = 0; i < n; i++) one();
        return map;
      }
      case 6: length(info); return item(); // tag: the value alone
      default:
        if (info === 20) return false;
        if (info === 21) return true;
        if (info === 25) { const h = buf.readUInt16BE(pos); pos += 2; return half(h); }
        if (info === 26) { const v = buf.readFloatBE(pos); pos += 4; return v; }
        if (info === 27) { const v = buf.readDoubleBE(pos); pos += 8; return v; }
        return null; // null, undefined
    }
  };
  return item();
}

// Entry i (1-based) of a Lua list that came as a CBOR array or map.
export function slot(list, i) {
  if (Array.isArray(list)) return list[i - 1] ?? undefined;
  if (list && typeof list === 'object') return list[String(i)];
  return undefined;
}

// The values of a Lua list that came as a CBOR array or map, holes left out.
export function values(list) {
  if (Array.isArray(list)) return list.filter((v) => v !== null && v !== undefined);
  if (list && typeof list === 'object') return Object.keys(list).sort((a, b) => a - b).map((k) => list[k]).filter((v) => v !== null);
  return [];
}

let cache = null;

export function questieDbFile(wowDir) {
  return path.join(wowDir, 'Interface', 'AddOns', 'QuestieDB', 'QuestieDB_Forever.toc');
}

class QuestieDB {
  constructor(file) {
    this.lines = new Map();
    for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
      if (!line.startsWith('## X-')) continue;
      const colon = line.indexOf(': ');
      if (colon > 0) this.lines.set(line.slice(3, colon), line.slice(colon + 2));
    }
    this.idLists = {};
    this.localized = {};
    this.records = new Map();
  }

  value(key) {
    const v = this.lines.get(key);
    const chunks = v && /^~(\d+)~$/.exec(v);
    if (!chunks) return v;
    let joined = '';
    for (let i = 1; i <= Number(chunks[1]); i++) joined += this.lines.get(`${key}-${i}`) || '';
    return joined;
  }

  packed(key) {
    const v = this.value(key);
    return v ? decodeCbor(zlib.inflateSync(Buffer.from(v, 'base64'))) : null;
  }

  plain(key) {
    const v = this.value(key);
    return v ? decodeCbor(Buffer.from(v, 'base64')) : undefined;
  }

  ids(type) {
    this.idLists[type] ??= this.packed(`X-${type}-IDS`) || [];
    return this.idLists[type];
  }

  // { field: value } by field name, or null when the ID is unknown.
  record(type, id) {
    const key = `${type}:${id}`;
    if (this.records.has(key)) return this.records.get(key);
    const scalars = this.plain(`X-${type}-${id}-S`);
    let rec = null;
    if (scalars) {
      rec = { id: Number(id) };
      const presence = Number(scalars.p || 0);
      FIELDS[type].forEach((name, index) => {
        const i = index + 1;
        if (!name) return;
        if (scalars[String(i)] !== undefined) rec[name] = scalars[String(i)];
        else if (Math.floor(presence / 2 ** index) % 2 === 1) rec[name] = this.plain(`X-${type}-${id}-${i}`);
      });
    }
    this.records.set(key, rec);
    return rec;
  }

  position(type, id) {
    const list = this.ids(type);
    let lo = 0, hi = list.length - 1;
    while (lo <= hi) {
      const mid = (lo + hi) >> 1;
      if (list[mid] === id) return mid;
      if (list[mid] < id) lo = mid + 1; else hi = mid - 1;
    }
    return -1;
  }

  // The French columns of an ID: [name, objectives or subName], or [].
  french(type, id) {
    this.localized[type] ??= this.packed(`X-l10n-frFR-${type}`) || [];
    const at = this.position(type, Number(id));
    if (at < 0) return [];
    return this.localized[type].map((column) => (Array.isArray(column) ? column[at] : column?.[String(at + 1)]) ?? undefined);
  }

  // The name in French when known, else in English.
  name(type, id) {
    const fr = this.french(type, id)[0];
    if (typeof fr === 'string' && fr) return fr;
    return this.record(type, id)?.name;
  }
}

// The database, or null when QuestieDB is not installed.
export function loadQuestie(wowDir) {
  const file = questieDbFile(wowDir);
  let stat;
  try { stat = fs.statSync(file); } catch { return null; }
  if (!cache || cache.file !== file || cache.mtimeMs !== stat.mtimeMs) {
    cache = { file, mtimeMs: stat.mtimeMs, db: new QuestieDB(file) };
  }
  return cache.db;
}
