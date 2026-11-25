// Import strings, made here for the player to paste: the format many addons
// share ("!" and LibDeflate's printable letters, of a deflated AceSerializer
// text), and an aura of the WeakAuras family that lists what to gather or do
// and follows it.
//
// In the silent mode a string never goes through Claude, which would spend
// thousands of tokens copying it, with mistakes: the tool gives a mark, "{{string:
// 1a2b3c}}", and silent.mjs puts the string in its place in the answer.

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { dataDir } from './home.mjs';

// ------------------------------------------------------------- the format

const LETTERS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789()';

function escape(text) {
  return [...text].map((char) => {
    const code = char.codePointAt(0);
    if (code === 30) return '~z';
    if (code <= 32) return `~${String.fromCharCode(code + 64)}`;
    return { 94: '~}', 126: '~|', 127: '~{' }[code] || char;
  }).join('');
}

// A value as AceSerializer writes it. An object's keys that are whole numbers
// are numbers, and a list's are from 1, as Lua's.
export function serialize(value) {
  const out = ['^1'];
  const write = (v) => {
    if (v === true) out.push('^B');
    else if (v === false) out.push('^b');
    else if (typeof v === 'number') out.push(`^N${v}`);
    else if (typeof v === 'string') out.push(`^S${escape(v)}`);
    else if (v && typeof v === 'object') {
      out.push('^T');
      const entries = Array.isArray(v) ? v.map((item, i) => [i + 1, item]) : Object.entries(v).map(([key, item]) => [/^-?\d+$/.test(key) ? Number(key) : key, item]);
      for (const [key, item] of entries) {
        if (item === null || item === undefined) continue;
        write(key);
        write(item);
      }
      out.push('^t');
    } else throw new Error(`cannot be written: ${v}`);
  };
  write(value);
  out.push('^^');
  return out.join('');
}

export function encodeForPrint(bytes) {
  let out = '';
  for (let i = 0; i < bytes.length; i += 3) {
    const left = Math.min(3, bytes.length - i);
    let bits = 0;
    for (let k = 0; k < left; k++) bits += bytes[i + k] * 256 ** k;
    for (let k = 0; k < Math.ceil((left * 8) / 6); k++) { out += LETTERS[bits % 64]; bits = Math.floor(bits / 64); }
  }
  return out;
}

export function decodeForPrint(text) {
  const out = [];
  for (let i = 0; i < text.length; i += 4) {
    const part = [...text.slice(i, i + 4)].map((letter) => LETTERS.indexOf(letter));
    let bits = part.reduce((sum, n, k) => sum + n * 64 ** k, 0);
    for (let k = 0; k < Math.floor((part.length * 6) / 8); k++) { out.push(bits % 256); bits = Math.floor(bits / 256); }
  }
  return Buffer.from(out);
}

export function importString(table) {
  return `!${encodeForPrint(zlib.deflateRawSync(Buffer.from(serialize(table), 'utf8'), { level: 9 }))}`;
}

// ------------------------------------------------------------- the aura

const lua = (text) => `"${String(text).replace(/[\\"]/g, '\\$&').replace(/\r?\n/g, ' ')}"`;
const whole = (value) => (Number.isFinite(Number(value)) && Number(value) > 0 ? Math.floor(Number(value)) : null);

// What an aura's line does, in Lua: lines = [{ text, item, need, quest, currency, header }].
function luaLine(line) {
  const text = line.text ? lua(line.text) : 'nil';
  if (line.header) return `  head(${text})`;
  if (whole(line.item)) return `  item(${whole(line.item)}, ${whole(line.need) || 1}, ${text})`;
  if (whole(line.currency)) return `  currency(${whole(line.currency)}, ${whole(line.need) || 1}, ${text})`;
  if (whole(line.quest)) return `  quest(${whole(line.quest)}, ${text})`;
  return line.text ? `  say(${text})` : null;
}

export function trackerCode(title, lines) {
  return `function(states)
  local out = {}
  local function add(color, text) out[#out + 1] = "|cff" .. color .. text .. "|r" end
  local function head(text) add("ffd100", text or "") end
  local function say(text) add("c2c0b6", text or "") end
  local function count(have, need, name)
    add(have >= need and "7fbf7f" or "ffffff", ("%d/%d  %s"):format(math.min(have, need), need, name))
  end
  local function item(id, need, text)
    if not C_Item.GetItemNameByID(id) and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    count(C_Item.GetItemCount(id, true) or 0, need, C_Item.GetItemNameByID(id) or text or ("item " .. id))
  end
  local function currency(id, need, text)
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    count(info and info.quantity or 0, need, info and info.name or text or ("currency " .. id))
  end
  local function quest(id, text)
    local done = C_QuestLog.IsQuestFlaggedCompleted(id)
    add(done and "7fbf7f" or C_QuestLog.IsOnQuest(id) and "ffffff" or "9c9a92", (done and "ok  " or "-  ") .. (C_QuestLog.GetTitleForQuestID(id) or text or ("quest " .. id)))
  end
  head(${lua(title)})
${lines.map(luaLine).filter(Boolean).join('\n')}
  local state = states[""] or {}
  state.show, state.changed, state.text = true, true, table.concat(out, "\\n")
  states[""] = state
  return true
end`;
}

const EVENTS = 'PLAYER_ENTERING_WORLD BAG_UPDATE_DELAYED QUEST_LOG_UPDATE QUEST_TURNED_IN CURRENCY_DISPLAY_UPDATE GET_ITEM_INFO_RECEIVED';
const NO_ANIMATION = { type: 'none', duration_type: 'seconds', easeType: 'none', easeStrength: 3 };

// An aura's text that lists and follows, as its addon exports it.
export function trackerAura(name, title, lines) {
  return {
    m: 'd', v: 1421, s: '1.0',
    d: {
      id: name, uid: crypto.randomBytes(9).toString('base64').replace(/[+/]/g, 'x').slice(0, 11),
      regionType: 'text', internalVersion: 91,
      displayText: '%text', customTextUpdate: 'event', fontSize: 13, justify: 'LEFT', outline: 'OUTLINE', color: [1, 1, 1, 1],
      anchorFrameType: 'SCREEN', anchorPoint: 'LEFT', selfPoint: 'LEFT', xOffset: 40, yOffset: 60, frameStrata: 1,
      automaticWidth: 'Auto', fixedWidth: 260, wordWrap: 'WordWrap', alpha: 1,
      triggers: {
        1: {
          trigger: {
            type: 'custom', custom_type: 'stateupdate', check: 'event', events: EVENTS, custom: trackerCode(title, lines),
            custom_hide: 'timed', unit: 'player', debuffType: 'HELPFUL', event: 'Health', names: {}, spellIds: {}, subeventPrefix: 'SPELL', subeventSuffix: '_CAST_START',
          },
          untrigger: {},
        },
        activeTriggerMode: -10, disjunctive: 'any',
      },
      load: { size: { multi: {} }, spec: { multi: {} }, class: { multi: {} }, talent: { multi: {} } },
      conditions: {}, subRegions: [], actions: { start: {}, init: {}, finish: {} },
      animation: { start: NO_ANIMATION, main: NO_ANIMATION, finish: NO_ANIMATION },
      authorOptions: {}, config: {}, information: {},
    },
  };
}

// ------------------------------------------------------------- kept for the answer

const dir = () => path.join(dataDir(), 'claude-in-wow-strings');
const KEPT_MS = 24 * 3600e3;

// Keeps a string: its mark.
export function keepString(text) {
  fs.mkdirSync(dir(), { recursive: true });
  for (const name of fs.readdirSync(dir())) {
    const file = path.join(dir(), name);
    try { if (Date.now() - fs.statSync(file).mtimeMs > KEPT_MS) fs.rmSync(file); } catch { /* gone */ }
  }
  const id = crypto.createHash('sha1').update(text).digest('hex').slice(0, 8);
  fs.writeFileSync(path.join(dir(), `${id}.txt`), text);
  return `{{string:${id}}}`;
}

// An answer with the strings in the place of their marks.
export function putStrings(text) {
  return text.replace(/\{\{string:([0-9a-f]{8})\}\}/g, (mark, id) => {
    try { return fs.readFileSync(path.join(dir(), `${id}.txt`), 'utf8'); } catch { return mark; }
  });
}
