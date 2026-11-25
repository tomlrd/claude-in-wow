// Small helpers shared by the tools.

export const QUALITY = ['poor', 'common', 'uncommon', 'rare', 'epic', 'legendary', 'artifact', 'heirloom'];

export function money(copper) {
  if (typeof copper !== 'number' || Number.isNaN(copper)) return undefined;
  const g = Math.floor(copper / 10000);
  const s = Math.floor(copper / 100) % 100;
  const c = copper % 100;
  return `${g}g ${s}s ${c}c`;
}

// What the addon noted of an item, beside its name and count: type, vendor
// price, gear slot and level, stats and tooltip texts.
export function itemFacts(item) {
  return {
    quality: QUALITY[item.quality],
    type: item.subType ? `${item.type}/${item.subType}` : item.type,
    slot: item.slot,
    itemLevel: item.itemLevel,
    stats: item.stats,
    equip: item.equip,
    use: item.use,
    text: item.text,
    sells: item.sell ? money(item.sell) : undefined,
    bound: item.bound || undefined,
    questItem: item.questItem || undefined,
    startsQuest: item.startsQuest,
  };
}

export function when(epoch) {
  if (typeof epoch !== 'number') return undefined;
  return {
    at: new Date(epoch * 1000).toISOString(),
    minutesAgo: Math.round((Date.now() / 1000 - epoch) / 60),
  };
}

// A JSON-friendly view of a value, tables cut below `depth` levels:
// a cut table shows how many entries it has.
export function outline(value, depth) {
  if (value === null || typeof value !== 'object') return value;
  const count = Array.isArray(value) ? value.length : Object.keys(value).length;
  if (depth <= 0) return `{${count} entries}`;
  if (Array.isArray(value)) return value.map((v) => outline(v, depth - 1));
  const out = {};
  for (const [k, v] of Object.entries(value)) out[k] = outline(v, depth - 1);
  return out;
}

// Text cut to a size the conversation can take.
export function capped(text, max) {
  return text.length <= max ? text : `${text.slice(0, max)}\n... (cut: ${text.length - max} more characters; ask for a deeper path)`;
}
