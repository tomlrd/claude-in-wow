// Offline test of the claude-in-wow MCP server, as a client would use it.
// node server_test.mjs <plugin folder> <claude-in-wow.lua from addon_test.lua> [real SavedVariables folder]
// It builds a fake game folder ("fakewow") in the current folder.

import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import zlib from 'node:zlib';

const [pluginDir, svFile, realSV] = process.argv.slice(2).filter((arg) => !arg.startsWith('--'));
const withAddons = process.argv.includes('--addons'); // the tools on the player's own addons, on a real install
let passed = 0, failed = 0;
const ok = (name, got, want) => {
  if (JSON.stringify(got) === JSON.stringify(want)) passed++;
  else { failed++; console.log(`FAIL ${name}: got ${JSON.stringify(got)}, want ${JSON.stringify(want)}`); }
};

// A fake game folder: the addon's data, addons, settings, prices, screenshots
const wow = path.resolve('fakewow/_forever_');
fs.rmSync('fakewow', { recursive: true, force: true });
const write = (rel, text) => {
  const file = path.join(wow, rel);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text);
  return file;
};
fs.copyFileSync(svFile, write('WTF/Account/TEST/SavedVariables/claude-in-wow.lua', ''));
write('WTF/Account/TEST/SavedVariables/ElvUI.lua', 'ElvDB = {\n["profileKeys"] = {\n["Arden Valcourt"] = "arden_UI",\n},\n["profiles"] = {\n["arden_UI"] = {\n["general"] = {\n["fontSize"] = 12,\n},\n},\n},\n}\n');
write('WTF/Account/TEST/93/Arden-Valcourt/AddOns.txt', 'ElvUI: enabled\nXLoot: disabled\n');
write('WTF/Account/TEST/93/Arden-Valcourt/SavedVariables/ElvUI.lua', 'ElvCharacterDB = {\n["ChatHistoryLog"] = {\n},\n}\n');
write('Interface/AddOns/ElvUI/ElvUI.toc', '## Interface: 16001\n## Title: |cff1784d1ElvUI|r\n## Version: 13.80\n## Author: Elv\n## SavedVariables: ElvDB, ElvPrivateDB\n## SavedVariablesPerCharacter: ElvCharacterDB\nCore.lua\n');
write('Interface/AddOns/XLoot/XLoot.toc', '## Title: XLoot\n## Version: 1.0\n');
write('Interface/AddOns/Broken/Broken.toc', '## Title: Broken\n## Dependencies: NotInstalled, Blizzard_Tracker\n');
write('Interface/AddOns/Questie/Questie.toc', '## Title: Questie|cFFFF0000 game client not supported|r\n');
write('Interface/AddOns/Questie/Questie_Forever.toc', '## Title: Questie\n## Notes: Quest helper\n## Notes-frFR: Assistant de quêtes\n## Version: 11.0\n');
const b32 = (n) => n.toString(32).toUpperCase();
const day = 1795220339;
write('Interface/AddOns/TradeSkillMaster_AppHelper/AppData.lua', [
  `select(2, ...).LoadData("AUCTIONDB_REGION_STAT","Forever-EU",[[return {downloadTime=${day},fields={"itemString","regionMarketValue"},data={{2770,${b32(123)}},{3858,${b32(1177)}}}}]])`,
  `select(2, ...).LoadData("AUCTIONDB_REGION_SALE","Forever-EU",[[return {downloadTime=${day},fields={"itemString","regionSale","regionSoldPerDay","regionSalePercent"},data={{3858,${b32(995)},${b32(2532860)},${b32(50)}}}}]])`,
  `select(2, ...).LoadData("AUCTIONDB_NON_COMMODITY_DATA","Normal-Horde",[[return {downloadTime=${day + 60},fields={"itemString","minBuyout","numAuctions","marketValueRecent"},data={{10504,${b32(25000)},${b32(3)},${b32(26000)}}}}]])`,
].join('\n'));
// GatherMate2's records, with node and zone names from GatherMate2 and Questie
write('WTF/Account/TEST/SavedVariables/GatherMate2.lua', 'GatherMate2MineDB = {\n[1441] = {\n[5937582500] = 206,\n[4000500000] = 206,\n},\n[1443] = {\n[3293615800] = 203,\n},\n}\nGatherMate2HerbDB = {\n}\n');
write('Interface/AddOns/GatherMate2/Constants.lua', 'local x = 1\nlocal node_ids = {\n\t["Mining"] = {\n\t\t["Copper Vein"] = {\n\t\t\tid = 201,\n\t\t\tvariants = {\n\t\t\t\t"Poor Copper Vein"\n\t\t\t}\n\t\t},\n\t\t["Iron Deposit"] = 203,\n\t\t["Mithril Deposit"] = 206,\n\t},\n}\nlocal other = {\n\t["Mining"] = {\n\t\t[201] = "x",\n\t},\n}\n');
write('Interface/AddOns/GatherMate2/Locales/GatherMate2-frFR.lua', 'NL["Mithril Deposit"] = "Gisement de mithril"\nNL["Iron Deposit"] = "Gisement de fer"\n');
write('Interface/AddOns/QuestieDB/support/Forever/Zones/uiMapIdToAreaId.lua', 'ZoneDB.private.uiMapIdToAreaId = [[return {\n    [1441] = 400, -- Thousand Needles\n    [1443] = 405, -- Desolace\n}]]\n');
write('Interface/AddOns/Questie/Localization/lookups/lookupZones.lua', 'l10n.continentLookup = {\n    [1] = "Eastern Kingdoms",\n}\nl10n.zoneLookup = {\n    [1]={\n        [400]="Thousand Needles",\n        [405]="Desolace",\n    },\n}\n');
write('Interface/AddOns/Questie/Localization/Translations/Zones/Kalimdor.lua', 'local zoneLocales = {\n    ["Thousand Needles"] = {\n        ["enUS"] = true,\n        ["frFR"] = "Mille pointes",\n    },\n    ["Desolace"] = {\n        ["frFR"] = "Désolace",\n    },\n}\n');
write('Screenshots/WoWScrnShot_old.jpg', 'x');
const older = new Date(Date.now() - 3600e3);
fs.utimesSync(path.join(wow, 'Screenshots/WoWScrnShot_old.jpg'), older, older);
write('Screenshots/WoWScrnShot_new.jpg', 'x');

// Claude Code's own sessions on this computer: the game's part of the plan is
// estimated from their tokens
const sessions = path.resolve('fakewow/claude/projects');
const sessionFile = (name) => { const file = path.join(sessions, name); fs.mkdirSync(path.dirname(file), { recursive: true }); return file; };
const spoken = (id, output, { entrypoint = 'claude-desktop', cwd = path.resolve('fakewow'), model = 'claude-opus-5-5', at = Date.now() } = {}) =>
  `${JSON.stringify({ message: { id, model, usage: { input_tokens: 0, output_tokens: output } }, type: 'assistant', timestamp: new Date(at).toISOString(), entrypoint, cwd })}\n`;
fs.writeFileSync(sessionFile('game/a.jsonl'), spoken('m1', 100, { entrypoint: 'sdk-cli' }));
fs.writeFileSync(sessionFile('other/b.jsonl'), spoken('m2', 10) + spoken('m2', 300) + '{"type":"user","message":{"content":"x"}}\n' + spoken('m0', 9000, { at: Date.now() - 9 * 86400e3 }));

fs.writeFileSync(path.resolve('fakewow/claude/settings.json'), JSON.stringify({ language: 'German' })); // the language set in Claude Code

function startServer(wowDir) {
  const server = spawn(process.execPath, [path.join(pluginDir, 'server/server.mjs')], {
    // the clipboard written to a file, never the real one; the silent mode
    // with a fake claude, its state in fakewow
    env: {
      ...process.env, CIW_WOW_DIR: wowDir, CIW_CLIPBOARD_FILE: path.resolve('fakewow/clipboard.txt'),
      CIW_CLAUDE: path.join(path.dirname(fileURLToPath(import.meta.url)), 'fake_claude.mjs'),
      CIW_CACHE_S: '0', CIW_CATCH_UP_S: '0', CIW_STARTUP_DIR: path.resolve('fakewow/startup'), CIW_HOME_DIR: path.resolve('fakewow/home'), CLAUDE_CONFIG_DIR: path.resolve('fakewow/claude'),
      CIW_SILENT_DIR: path.resolve('fakewow'), CIW_KEY: path.resolve('fakewow/key.txt'), ANTHROPIC_API_KEY: 'sk-of-another-program', FAKE_CLAUDE_LOG: path.resolve('fakewow/claude.log'),
    },
    stdio: ['pipe', 'pipe', 'inherit'],
  });
  let buffer = '';
  const waiting = new Map();
  const stray = [];
  server.stdout.on('data', (chunk) => {
    buffer += chunk;
    let nl;
    while ((nl = buffer.indexOf('\n')) >= 0) {
      const line = buffer.slice(0, nl);
      buffer = buffer.slice(nl + 1);
      const msg = JSON.parse(line); // anything else on stdout fails here
      if (waiting.has(msg.id)) { waiting.get(msg.id)(msg); waiting.delete(msg.id); } else stray.push(msg);
    }
  });
  let nextId = 1;
  const request = (method, params) => new Promise((resolve) => {
    const id = nextId++;
    waiting.set(id, resolve);
    server.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', id, method, params })}\n`);
  });
  const notify = (method) => server.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', method })}\n`);
  const call = async (name, args = {}) => {
    const res = await request('tools/call', { name, arguments: args });
    const raw = res.result.content[0].text;
    return { isError: res.result.isError, data: res.result.isError ? {} : JSON.parse(raw), raw };
  };
  return { server, request, notify, call, stray };
}

const { server, request, notify, call, stray } = startServer(wow);

const init = await request('initialize', { protocolVersion: '2025-06-18', capabilities: {}, clientInfo: { name: 'test', version: '1' } });
ok('protocol echoed', init.result.protocolVersion, '2025-06-18');
ok('tools capability', !!init.result.capabilities.tools, true);
notify('notifications/initialized');
const odd = await request('initialize', { protocolVersion: '1999-01-01' });
ok('unknown protocol: newest', odd.result.protocolVersion, '2025-11-25');
ok('ping', (await request('ping')).result, {});
ok('unknown method', (await request('nope')).error.code, -32601);

const tools = (await request('tools/list')).result.tools;
ok('tools', tools.map((t) => t.name), ['game_state', 'listen', 'silent_mode', 'answer_to_game', 'game_functions', 'quests', 'find_item', 'inventory', 'lua_errors', 'screenshots', 'addons', 'saved_variables', 'prices', 'quest_info', 'npc_info', 'item_info', 'gathering', 'import_string', 'numbers']);
ok('all read-only', tools.every((t) => t.annotations.readOnlyHint), true);

const state = await call('game_state');
ok('no error', state.isError, false);
ok('character', state.data.character, 'Arden Valcourt');
ok('no question note any more', state.data.note, undefined);
ok('money', state.data.money, '123g 45s 67c');
ok('xp', state.data.xp, '41000/88400 (46%)');
ok('max health', state.data.maxHealth, 2100);
ok('where', [state.data.location.subZone, state.data.location.x, state.data.location.y], ['Grottes orange', 29.1, 62.9]);
ok('instance', state.data.location.instance.name, 'Maraudon');
ok('group', state.data.group.members.map((m) => m.name), ['Vex', 'Mira']);
ok('age', state.data.snapshot.minutesAgo >= 0 && state.data.snapshot.minutesAgo < 5, true);
ok('counts', [state.data.quests, state.data.questsNotListed, state.data.luaErrors], [3, 1, 2]);
ok('equipment', state.data.equipment.head.name, 'Chapeau vert de soie');

const quests = await call('quests', { search: 'pylo' });
ok('search in objectives, accents aside', quests.data.quests.length, 1);
ok('objective', quests.data.quests[0].objectives[0].text, 'Pylônes alimentés : 2/3');
ok('says quests are left out', quests.data.notListed.startsWith('1 more quests'), true);
ok('zone search', (await call('quests', { search: 'desolace' })).data.quests.map((q) => q.title), ["Khan Dez'hepah"]);
ok('grammar code resolved', (await call('quests', { search: 'khan' })).data.quests[0].objectives[0].text, "Khan Dez'hepah : 0/1 personnage tué");

const ore = await call('find_item', { search: 'minerai' });
ok('find by name', ore.data.found.map((f) => [f.place, f.count]), [['bags', 20]]);
const silk = await call('find_item', { search: 'etoffe de soie' });
ok('find in the bank, with its date', [silk.data.found[0].place, !!silk.data.found[0].noted], ['bank', true]);
ok('find by ID', (await call('find_item', { search: '17781' })).data.found[0].name, 'La pierre de Maraudon');
ok('equipped and a copy in the bags', (await call('find_item', { search: 'chapeau' })).data.found.map((f) => f.place).sort(), ['bags', 'equipped (head)']);

const bags = await call('inventory');
ok('bags sorted by name', bags.data.items.map((i) => i.name), ['Chapeau vert de soie', 'La pierre de Maraudon', 'Minerai de cuivre']);
ok('quality names', bags.data.items.map((i) => i.quality), ['rare', 'uncommon', 'common']);
const [hat, stone, ore2] = bags.data.items;
ok('gear: type, slot, item level, vendor price, bound', [hat.type, hat.slot, hat.itemLevel, hat.sells, hat.bound], ['Armure/Tissu', 'Tête', 41, '0g 15s 20c', true]);
ok('a quest item that starts a quest', [stone.type, stone.questItem, stone.startsQuest, stone.sells], ['Quête', true, 7067, undefined]);
ok('trade goods', [ore2.type, ore2.sells, ore2.bound], ['Artisanat/Métal et pierre', '0g 0s 5c', undefined]);
ok('account bank not noted', (await call('inventory', { where: 'account bank' })).data.note.startsWith('Not noted'), true);
ok('gear: stats and effects from its tooltip', [hat.stats, hat.equip.startsWith('Augmente les dégâts')], ['Armure +45, Endurance +5, Intelligence +8', true]);
ok('a quest item: its use and description', [stone.use, stone.text], ['Lit les instructions du paria.', '"Une pierre étrange."']);
ok('the marks pasted in game', [hat.mark, stone.mark, ore2.mark], [{ action: 'bank', reason: 'pour plus tard' }, { action: 'destroy', reason: 'quête déjà rendue' }, undefined]);
ok('marks counted in the game state', state.data.bags.marked, { auction: 1, bank: 1, destroy: 1 });
ok('equipped: stats', (await call('inventory', { where: 'equipped' })).data.equipped.head.stats, 'Armure +45, Endurance +5, Intelligence +8');
const noQuestie = await call('item_info', { query: 'pierre de maraudon' });
ok('item_info without Questie: what the game says of an item the player has', [noQuestie.data.id, noQuestie.data.inGame.use, noQuestie.data.inGame.owned, noQuestie.data.note.includes('QuestieDB')],
  [17781, 'Lit les instructions du paria.', ['Arden Valcourt: bags'], true]);

const errors = await call('lua_errors', { limit: 5 });
ok('errors newest first', errors.data.errors.map((e) => e.kind), ['blocked', 'error']);
ok('stack kept', errors.data.errors[1].stack.includes('Broken.lua'), true);
ok('without stacks', (await call('lua_errors', { include_stack: false })).data.errors[1].stack, undefined);

const shots = await call('screenshots', { count: 2 });
ok('newest screenshot first', shots.data.screenshots.map((s) => path.basename(s.path)), ['WoWScrnShot_new.jpg', 'WoWScrnShot_old.jpg']);

// Addons, from their folders
const addons = await call('addons');
ok('installed and enabled', [addons.data.installed, addons.data.enabled], [4, 3]);
ok('the character played', addons.data.character, 'Arden-Valcourt (93)');
const byName = Object.fromEntries(addons.data.addons.map((a) => [a.name, a]));
ok('title without colour codes, loaded per the snapshot', [byName.ElvUI.title, byName.ElvUI.version, byName.ElvUI.loaded], ['ElvUI', '13.80', true]);
ok('disabled in AddOns.txt, with the game\'s reason', [byName.XLoot.enabled, byName.XLoot.reason], [false, 'DISABLED']);
ok('a missing dependency is a problem', (await call('addons', { problems_only: true })).data.addons.map((a) => [a.name, a.missingDependencies]), [['Broken', ['NotInstalled']]]);
const questie = (await call('addons', { search: 'questie' })).data.addons[0];
ok('the Forever .toc first, French notes', [questie.title, questie.notes, questie.version], ['Questie', 'Assistant de quêtes', '11.0']);

// Saved settings
const elv = await call('saved_variables', { addon: 'elvui' });
ok('account and character files', elv.data.files.map((f) => f.scope), ['account', 'character']);
ok('an outline: tables below it counted', elv.data.files[0].globals.ElvDB.profileKeys, '{1 entries}');
ok('a deeper outline', (await call('saved_variables', { addon: 'elvui', depth: 3 })).data.files[0].globals.ElvDB.profileKeys, { 'Arden Valcourt': 'arden_UI' });
ok('a path', (await call('saved_variables', { addon: 'ElvUI', path: 'ElvDB.profiles.arden_UI.general' })).data.files[0].value, { fontSize: 12 });
ok('nothing there', (await call('saved_variables', { addon: 'ElvUI', path: 'ElvDB.nope' })).data.files[0].value, 'nothing at this path');
ok('an addon saving nothing', (await call('saved_variables', { addon: 'XLoot' })).isError, true);

// Prices
const prices = await call('prices', { items: ['Minerai de cuivre', '3858', 'chapeau vert', 'Gemme inconnue'] });
ok('prices date', prices.data.pricesFrom.at, new Date((day + 60) * 1000).toISOString());
ok('by a name the player owns', [prices.data.items[0].id, prices.data.items[0].regionMarketValue], [2770, '1s 23c']);
ok('by ID, sale and sold per day', [prices.data.items[1].regionAverageSale, prices.data.items[1].regionSoldPerDay], ['9s 95c', 2532.86]);
ok('gear: lowest buyout on the Horde auction house', [prices.data.items[2].auctionHouse.lowestBuyout, prices.data.items[2].auctionHouse.auctions], ['2g 50s 0c', 3]);
ok('unknown name', prices.data.items[3].error.startsWith('Unknown name'), true);

// Gathering, from GatherMate2's records
const mines = await call('gathering');
ok('gathering summary', [mines.data.recorded, mines.data.byKind[0].kind, mines.data.byKind[0].mostSeen], [3, 'Mining', ['Gisement de mithril (2)', 'Gisement de fer (1)']]);
const mithril = await call('gathering', { node: 'mithril' });
ok('a node: its zone in French, coordinates in %', [mithril.data.zones[0].zone, mithril.data.zones[0].coords], ['Mille pointes', ['40 50', '59.37 58.25']]);
ok('a zone', (await call('gathering', { zone: 'desolace' })).data.zones[0].coords, ['Gisement de fer 32.93 61.58']);
ok('a zone\'s map, for links that open it in the game', mithril.data.zones[0].uiMapID, 1441);
ok('nothing seen', (await call('gathering', { node: 'thorium' })).isError, true);
ok('no Questie database: says so', (await call('quest_info', { query: '7' })).raw.includes('QuestieDB'), true);

const nobody = await call('game_state', { character: 'Thrall' });
ok('unknown character: an error that lists the others', [nobody.isError, nobody.raw.includes('Arden Valcourt')], [true, true]);
const unknown = await request('tools/call', { name: 'nope', arguments: {} });
ok('unknown tool', unknown.result.isError, true);
ok('nothing else on stdout', stray.length, 0);
server.stdin.end();

// Photos: the pages addon_test.lua drew, rendered as the game does (white
// glyphs on black, a dot a pixel, a pixel between glyphs) and saved as PNG
// screenshots
const { adler32, ALPHABET, glyphRects, readPage, decodePng } = await import(pathToFileURL(path.join(pluginDir, 'server/photo.mjs')));
function png(width, height, paint) {
  const rgb = Buffer.alloc(width * height * 3);
  paint((x, y) => { if (x >= 0 && y >= 0 && x < width && y < height) rgb.fill(255, (y * width + x) * 3, (y * width + x) * 3 + 3); });
  const raw = Buffer.alloc(height * (width * 3 + 1));
  for (let y = 0; y < height; y++) rgb.copy(raw, y * (width * 3 + 1) + 1, y * width * 3, (y + 1) * width * 3);
  const chunk = (type, body) => {
    const head = Buffer.alloc(8); head.writeUInt32BE(body.length); head.write(type, 4, 'latin1');
    return Buffer.concat([head, body, Buffer.alloc(4)]); // the reader skips CRCs
  };
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(width); ihdr.writeUInt32BE(height, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([Buffer.from('89504e470d0a1a0a', 'hex'), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}
const paintLines = (lines) => (set) => {
  for (const { x, y, text } of lines) {
    [...text].forEach((char, g) => {
      for (const [x0, y0, x1, y1] of glyphRects(ALPHABET.indexOf(char))) {
        for (let py = y0; py < y1; py++) for (let px = x0; px < x1; px++) set(x + g * 10 + px, y + py);
      }
    });
  }
};
const photo = JSON.parse(fs.readFileSync(`${svFile}.photo.json`, 'utf8'));
const shotsDir = path.join(wow, 'Screenshots');
const pageFiles = photo.pages.map((lines, i) => {
  const file = path.join(shotsDir, `WoWScrnShot_photo${i + 1}.png`);
  fs.writeFileSync(file, png(photo.width, photo.height, paintLines(lines)));
  return file;
});
const compact = readPage(decodePng(fs.readFileSync(pageFiles[0])));
ok('a compact photo read back: one page, deflated', [compact.page, compact.pages, compact.encoding], [1, 1, 'deflate']);
// the same data not compact: two pages of JSON as it is (read here, not left in the folder)
const notCompact = JSON.parse(fs.readFileSync(`${svFile}.pages.json`, 'utf8'));
const read = notCompact.pages.map((lines) => readPage(decodePng(png(notCompact.width, notCompact.height, paintLines(lines)))));
ok('not compact: two pages of JSON', read.map((p) => [p.page, p.pages, p.encoding]), [[1, 2, 'json'], [2, 2, 'json']]);
ok('not compact: twice the size at least (small test data compresses less than real bags)', Buffer.concat(read.map((p) => p.chunk)).length > 2 * compact.chunk.length, true);
ok('not compact: the same money', JSON.parse(Buffer.concat(read.map((p) => p.chunk)).toString('utf8')).character.character.money, 2000000);
// an older photo, replaced by a reload since: deleted; a screenshot of the player's own in PNG: kept
const stale = Buffer.from(JSON.stringify({ key: 'Arden Valcourt', savedAt: 1, character: {} }));
const staleText = stale.toString('base64').replace(/=+$/, '');
const header = Buffer.from(`CIW1 7 1 1 100 ${Math.ceil(staleText.length / 100)} ${stale.length} ${adler32(stale)} 8 json 1040 240`.padEnd(72));
const staleLines = [
  { x: 4, y: 4, text: header.toString('base64') },
  ...staleText.match(/.{1,100}/g).map((text, i) => ({ x: 4, y: 12 + i * 8, text })),
];
const staleFile = path.join(shotsDir, 'WoWScrnShot_stale.png');
fs.writeFileSync(staleFile, png(1040, 240, paintLines(staleLines)));
const ownFile = path.join(shotsDir, 'WoWScrnShot_own.png');
fs.writeFileSync(ownFile, png(64, 64, (set) => { for (let i = 0; i < 64; i++) set(i, i); }));

const live = startServer(wow);
await live.request('initialize', { protocolVersion: '2025-06-18' });
const fresh = await live.call('game_state');
ok('photo: newer than the snapshot, it wins', [fresh.data.money, fresh.data.snapshot.by], ['200g 0s 0c', 'photo taken in game']);
ok('photo: the rest of the character too', [fresh.data.location.subZone, fresh.data.quests, fresh.data.equipment.head.name], ['Grottes orange', 3, 'Chapeau vert de soie']);
ok('photo: bags', (await live.call('inventory')).data.items.map((i) => i.name), ['Chapeau vert de soie', 'La pierre de Maraudon', 'Minerai de cuivre']);
ok('photo: tooltips and marks', (await live.call('inventory')).data.items.map((i) => [i.use || i.stats, i.mark?.action]),
  [['Armure +45, Endurance +5, Intelligence +8', 'bank'], ['Lit les instructions du paria.', 'destroy'], [undefined, undefined]]);
ok('photo: the bank as last opened', (await live.call('find_item', { search: 'etoffe' })).data.found[0].place, 'bank');
ok('photo: Lua errors, not doubled', fresh.data.luaErrors, 2);
ok('photo: addons still from the snapshot', (await live.call('addons', { search: 'elvui' })).data.addons[0].loaded, true);
ok('photo: the replaced photo deleted, the player\'s own PNG kept', [fs.existsSync(staleFile), fs.existsSync(ownFile), pageFiles.every((f) => fs.existsSync(f))], [false, true, true]);
ok('photo: left out of the screenshots', (await live.call('screenshots', { count: 5 })).data.screenshots.map((s) => path.basename(s.path)).filter((n) => n.endsWith('.png')), ['WoWScrnShot_own.png']);

// Listening: the photo carried a question from the game's Claude window
ok('photo: the question sent from the game', [fresh.data.question?.text, fresh.data.question?.kind], ['Que faire de mes sacs ?', 'bags']);
const listenTool = (await live.call('listen', { after: 5, hours: 0.001 })).data;
ok('listen: a command to run in the background', [listenTool.command.includes('/server/listen.mjs'), listenTool.command.endsWith('--after 5 --hours 0.001'), listenTool.after],
  [true, true, 5]);
const ANSWER = '## Sacs\n\n- **Vendre** le Minerai de cuivre : 5c, à l\'hôtel des ventes rien de mieux\n\n```\n[claude-in-wow] marques\nvendre 2770 rien de mieux\n```';
const copied = await live.call('answer_to_game', { text: `\n${ANSWER}\n` });
ok('answer to the game: in the clipboard as written, accents kept', [copied.data.copied, fs.readFileSync(path.resolve('fakewow/clipboard.txt'), 'utf8')], [true, ANSWER]);
ok('answer to the game: nothing to copy, an error', (await live.call('answer_to_game', { text: '  ' })).isError, true);
await live.call('answer_to_game', { text: 'Voilà', question: 1795534604 });
ok('answer to the game: marked with its question', fs.readFileSync(path.resolve('fakewow/clipboard.txt'), 'utf8'), '[claude-in-wow réponse 1795534604]\n\nVoilà');
live.server.stdin.end();
const listenScript = path.join(pluginDir, 'server/listen.mjs');
const listenEnv = { ...process.env, CIW_WOW_DIR: wow, CIW_SILENT_DIR: path.resolve('fakewow') }; // not the player's own silent mode
const listen = (after, hours) => new Promise((resolve) => {
  const child = spawn(process.execPath, [listenScript, '--after', String(after), '--hours', String(hours)], { env: listenEnv });
  let out = '';
  child.stdout.on('data', (d) => { out += d; });
  child.on('exit', (code) => resolve({ code, out }));
});
const heard = await listen(0, 0.001);
ok('listen: a question already sent is printed at once', [heard.code, heard.out.includes('kind "bags"'), heard.out.includes('\nQue faire de mes sacs ?\n')], [0, true, true]);
const askedAt = Number(heard.out.match(/after=(\d+)/)?.[1]);
ok('listen: says what to listen after next', askedAt > 0, true);
// a new question while it waits: a photo written a moment later wakes it
const waiting = listen(askedAt, 0.01);
// a photo carrying a question, as the addon draws it (JSON, one page)
const questionPhoto = (file, question) => {
  const data = Buffer.from(JSON.stringify({ key: 'Arden Valcourt', savedAt: question.at, character: {}, question }));
  const text = data.toString('base64').replace(/=+$/, '');
  const head = Buffer.from(`CIW1 ${question.at} 1 1 100 ${Math.ceil(text.length / 100)} ${data.length} ${adler32(data)} 8 json 1040 240`.padEnd(72));
  fs.writeFileSync(file, png(1040, 240, paintLines([
    { x: 4, y: 4, text: head.toString('base64') },
    ...text.match(/.{1,100}/g).map((t, i) => ({ x: 4, y: 12 + i * 8, text: t })),
  ])));
  return file;
};
const nextFile = path.join(shotsDir, 'WoWScrnShot_next.png');
setTimeout(() => questionPhoto(nextFile, { id: askedAt + 30, kind: 'free', text: 'Où est le féticheur Ti\'ik ?', at: askedAt + 30 }), 400);
const woken = await waiting;
ok('listen: woken by the next question', [woken.code, woken.out.includes('\nOù est le féticheur Ti\'ik ?\n'), woken.out.includes(`after=${askedAt + 30}`)], [0, true, true]);
const quiet = await listen(askedAt + 30, 0.0005);
ok('listen: nothing newer, it stops after the hours given', quiet.out.startsWith('Stopped listening'), true);
fs.rmSync(nextFile);

// Releasing: the packages, and what goes to CurseForge (a server of this computer in its place)
{
  const http = await import('node:http');
  const { spawnSync } = await import('node:child_process');
  const here = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
  const copy = path.resolve('fakewow/release');
  for (const name of ['addon', 'plugin', 'tools', 'package.json', 'LICENSE', 'CHANGELOG.md']) fs.cpSync(path.join(here, name), path.join(copy, name), { recursive: true });
  const tool = (name, args = [], env = {}) => spawnSync(process.execPath, [path.join(copy, 'tools', name), ...args], { encoding: 'utf8', env: { ...process.env, ...env } });
  const version = () => /^## Version: (.+)$/m.exec(fs.readFileSync(path.join(copy, 'addon/claude-in-wow.toc'), 'utf8'))[1];
  ok('release: this version is complete', tool('version.mjs').status, 0);
  ok('release: not a version after it', [tool('version.mjs', ['0.0.1']).status, tool('version.mjs', ['new']).status], [1, 1]);
  const next = tool('version.mjs', ['99.1.0', '99.2.0']);
  ok('release: a new version, and what is missing for it', [next.status, version(), JSON.parse(fs.readFileSync(path.join(copy, 'plugin/.claude-plugin/plugin.json'), 'utf8')).version, (next.stderr.match(/^- /gm) || []).length], [1, '99.1.0', '99.2.0', 6]);
  for (const name of fs.readdirSync(path.join(copy, 'addon/Locales'))) { const f = path.join(copy, 'addon/Locales', name); fs.writeFileSync(f, fs.readFileSync(f, 'utf8').replace('    CHANGES = {\n', '    CHANGES = {\n        "= 99.1.0",\n        "Dit \\"oui\\".",\n')); }
  fs.writeFileSync(path.join(copy, 'CHANGELOG.md'), fs.readFileSync(path.join(copy, 'CHANGELOG.md'), 'utf8').replace('## 1.0.0', '## 99.1.0\n\n- Something new.\n\n## 1.0.0'));
  ok('release: then it is', [tool('version.mjs').status, tool('package.mjs').stdout.trim()], [0, '99.1.0']);
  const told = JSON.parse(fs.readFileSync(path.join(copy, 'dist/release.json'), 'utf8'));
  ok('release: what the plugins read', [told.addon.version, told.plugin.version, told.notes.frFR, Object.keys(told.notes).length], ['99.1.0', '99.2.0', ['Dit "oui".'], 5]);
  const { unzip } = await import(pathToFileURL(path.join(pluginDir, 'server/updates.mjs')));
  const inside = (name) => unzip(fs.readFileSync(path.join(copy, 'dist', name)));
  const field = (files) => /^## X-Install: (.+)$/m.exec(files.find(({ name }) => name === 'claude-in-wow.toc').data.toString())?.[1];
  const a = inside('claude-in-wow-99.1.0.zip');
  ok('release: one zip, read back by what installs it', [field(a), fs.readdirSync(path.join(copy, 'dist')).filter((name) => name.endsWith('.zip')).length, a.some(({ name }) => name === 'Inbox/250.wav'), a.some(({ name }) => name === 'LICENSE')], ['release', 1, true, true]);
  ok('release: every file of the .toc is there', fs.readFileSync(path.join(copy, 'addon/claude-in-wow.toc'), 'utf8').split(/\r?\n/).filter((line) => /\.lua$/.test(line) && !line.startsWith('#')).filter((line) => !a.some(({ name }) => name === line.replaceAll('\\', '/'))), []);
  const received = [];
  const web = http.createServer((request, answer) => {
    const body = [];
    request.on('data', (d) => body.push(d));
    request.on('end', () => {
      received.push({ url: request.url, token: request.headers['x-api-token'], body: Buffer.concat(body) });
      answer.end(request.url === '/api/game/versions' ? JSON.stringify([{ id: 7, name: '12.1.5' }, { id: 9, name: '1.60.1' }, { id: 1, name: '1.2.3' }]) : JSON.stringify({ id: 4242 }));
    });
  });
  await new Promise((resolve) => web.listen(0, '127.0.0.1', resolve));
  const send = (env) => new Promise((resolve) => {
    const child = spawn(process.execPath, [path.join(copy, 'tools/curseforge.mjs')], { env: { ...process.env, CF_SITE: `http://127.0.0.1:${web.address().port}`, ...env } });
    let out = '';
    child.stdout.on('data', (d) => { out += d; });
    child.on('exit', (status) => resolve({ status, out }));
  });
  const none = await send({ CF_API_TOKEN: '', CF_PROJECT_ID: '' });
  ok('release: no CurseForge project yet: nothing is sent, nothing fails', [none.status, received.length], [0, 0]);
  const sent = await send({ CF_API_TOKEN: 'a-key-of-the-tests', CF_PROJECT_ID: '123' });
  const upload = received.find(({ url }) => url === '/api/projects/123/upload-file');
  const metadata = JSON.parse(/name="metadata"\r\n\r\n(.*?)\r\n/s.exec(upload.body.toString('latin1'))[1]);
  ok('release: the zip sent to CurseForge, for the versions of the game it knows', [sent.status, sent.out.includes('file 4242'), upload.token, metadata.gameVersions, metadata.releaseType, metadata.changelog, upload.body.includes(fs.readFileSync(path.join(copy, 'dist/claude-in-wow-99.1.0.zip')))], [0, true, 'a-key-of-the-tests', [7, 9], 'release', '- Something new.', true]);
  ok('release: the key is never shown', sent.out.includes('a-key-of-the-tests'), false);
  web.close();
  // a copy put in the games, to try it
  const game = path.join(copy, 'wow/_retail_'), to = path.join(game, 'Interface/AddOns/claude-in-wow');
  fs.mkdirSync(path.join(game, 'WTF'), { recursive: true });
  const running = path.join(copy, 'running');
  const play = (...args) => tool('install.mjs', args, { CIW_WOW_ROOT: path.join(copy, 'wow'), CIW_WOW_DIR: '', WOW_DIR: '', CIW_HOME_DIR: path.join(copy, 'home'), CIW_GAME_RUNNING: running });
  ok('play: only where the addon is, unless asked', [play().status, fs.existsSync(to), play('--all').status, fs.existsSync(path.join(to, 'Core/Core.lua'))], [0, false, 0, true]);
  fs.writeFileSync(path.join(to, 'Inbox/001.wav'), 'an answer');
  fs.writeFileSync(path.join(to, 'Old.lua'), '');
  fs.appendFileSync(path.join(copy, 'addon/Core/Core.lua'), '\n-- changed\n');
  fs.writeFileSync(running, '');
  ok('play: the game open, what a reload reads', [play().stdout.includes('1 written, 1 taken away: /reload'), fs.readFileSync(path.join(to, 'Core/Core.lua'), 'utf8').endsWith('-- changed\n'), fs.existsSync(path.join(to, 'Old.lua')), fs.readFileSync(path.join(to, 'Inbox/001.wav'), 'utf8')], [true, true, false, 'an answer']);
  fs.writeFileSync(path.join(copy, 'addon/Core/New.lua'), '');
  ok('play: a new file waits for the game to be closed', [play().status, fs.existsSync(path.join(to, 'Core/New.lua'))], [1, false]);
  fs.rmSync(running);
  ok('play: then it is there, what was before kept', [play().status, fs.existsSync(path.join(to, 'Core/New.lua')), fs.existsSync(path.join(copy, 'home/before-play/_retail_/Core/Core.lua'))], [0, true, true]);
  fs.rmSync(copy, { recursive: true, force: true });
}

// The updates, with a server of this computer in GitHub's place
{
  const http = await import('node:http');
  const crypto = await import('node:crypto');
  const own = path.resolve('fakewow/updates');
  const keep = Object.fromEntries(['CIW_HOME_DIR', 'CIW_SILENT_DIR', 'CIW_RELEASES', 'CIW_GAME_RUNNING', 'CIW_NO_PAGES', 'CIW_CLAUDE_TOOL', 'CIW_WOW_ROOT', 'CIW_WOW_DIR'].map((name) => [name, process.env[name]]));
  const game = path.join(own, 'wow/_retail_'), addons = path.join(game, 'Interface/AddOns'), dir = path.join(addons, 'claude-in-wow');
  const put = (file, text) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, text); };
  fs.mkdirSync(path.join(game, 'WTF'), { recursive: true });
  const install = (by) => { fs.rmSync(dir, { recursive: true, force: true }); put(path.join(dir, 'claude-in-wow.toc'), `## Interface: 1\n## Version: 1.0.0\n${by ? `## X-Install: ${by}\n` : ''}Old.lua\n`); put(path.join(dir, 'Old.lua'), 'old'); put(path.join(dir, 'Inbox/001.wav'), 'kept'); };
  // a zip as tools/package.mjs makes them
  const crcTable = Array.from({ length: 256 }, (_, n) => { let c = n; for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c >>> 0; });
  const crc = (d) => { let c = 0xffffffff; for (const b of d) c = crcTable[(c ^ b) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
  const zipOf = (files, mode = 0) => {
    const bodies = [], heads = [];
    let offset = 0;
    for (const [name, text] of Object.entries(files)) {
      const d = Buffer.from(text), file = Buffer.from(name), packed = zlib.deflateRawSync(d), common = Buffer.alloc(26), rest = Buffer.alloc(14);
      common.writeUInt16LE(20, 0); common.writeUInt16LE(8, 4); common.writeUInt32LE(crc(d), 10); common.writeUInt32LE(packed.length, 14); common.writeUInt32LE(d.length, 18); common.writeUInt16LE(file.length, 22);
      rest.writeUInt32LE(((mode << 16) >>> 0), 6); rest.writeUInt32LE(offset, 10);
      const local = Buffer.concat([Buffer.from([0x50, 0x4b, 3, 4]), common, file, packed]);
      heads.push(Buffer.concat([Buffer.from([0x50, 0x4b, 1, 2, 20, 0]), common, rest, file]));
      bodies.push(local);
      offset += local.length;
    }
    const head = Buffer.concat(heads), end = Buffer.alloc(22);
    end.writeUInt32LE(0x06054b50, 0); end.writeUInt16LE(heads.length, 8); end.writeUInt16LE(heads.length, 10); end.writeUInt32LE(head.length, 12); end.writeUInt32LE(offset, 16);
    return Buffer.concat([...bodies, head, end]);
  };
  const good = zipOf({ 'claude-in-wow/claude-in-wow.toc': '## Interface: 1\n## Version: 1.1.0\n## X-Install: github\nNew.lua\n', 'claude-in-wow/New.lua': 'new', 'claude-in-wow/Inbox/001.wav': '', 'claude-in-wow/Inbox/002.wav': '' });
  let zip = good, hash = null, plugin = { version: '99.0.0', needsAddon: '1.0.0' }, asked = [], base = '', file = null, nothing = false;
  const web = http.createServer((request, answer) => {
    asked.push([request.url, request.headers['user-agent']]);
    if (request.url === '/latest' && nothing) { answer.statusCode = 404; answer.end('{}'); } else if (request.url === '/latest') answer.end(JSON.stringify({ assets: [{ name: 'release.json', browser_download_url: `${base}/release.json` }, { name: 'a.zip', browser_download_url: file || `${base}/a.zip` }] }));
    else if (request.url === '/release.json') answer.end(JSON.stringify({ addon: { version: '1.1.0', file: 'a.zip', sha256: hash || crypto.createHash('sha256').update(zip).digest('hex') }, plugin, notes: { frFR: ['Du neuf', 'a|b\nc'], nope: ['x'] }, curseforge: 'https://www.curseforge.com/wow/addons/claude-in-wow' }));
    else answer.end(zip);
  });
  await new Promise((resolve) => web.listen(0, '127.0.0.1', resolve));
  base = `http://127.0.0.1:${web.address().port}`;
  const closed = path.join(own, 'running');
  Object.assign(process.env, { CIW_HOME_DIR: path.join(own, 'home'), CIW_RELEASES: base, CIW_GAME_RUNNING: closed, CIW_NO_PAGES: '1', CIW_WOW_ROOT: path.join(own, 'wow') });
  for (const name of ['CIW_SILENT_DIR', 'CIW_WOW_DIR', 'CIW_CLAUDE_TOOL']) delete process.env[name];
  // the plugin as Claude Code keeps it, for its own update
  const cache = path.join(own, 'cache/market/wow-mcp');
  fs.cpSync(path.join(pluginDir, 'server'), path.join(cache, '1.0.0/server'), { recursive: true });
  put(path.join(cache, '1.0.0/.claude-plugin/plugin.json'), JSON.stringify({ version: '1.0.0' }));
  put(path.join(own, 'tool.mjs'), `import fs from 'node:fs'; fs.appendFileSync(${JSON.stringify(path.join(own, 'tool.log'))}, process.argv.slice(2).join(' ') + '\\n'); if (process.argv[3] === 'update') { const to = ${JSON.stringify(path.join(cache, '99.0.0/server'))}; fs.mkdirSync(to, { recursive: true }); fs.writeFileSync(to + '/silent-mode.mjs', ''); }`);
  process.env.CIW_CLAUDE_TOOL = path.join(own, 'tool.mjs');
  const updates = await import(pathToFileURL(path.join(cache, '1.0.0/server/updates.mjs')));
  const told = (text) => Object.fromEntries(text.split('\n').map((line) => line.split(/=(.*)/s)).map(([name, value]) => [name, value]));
  ok('updates: a version after another', [updates.newer('2.10.0', '2.9.9'), updates.newer('2.9', '2.9.0'), updates.newer('2.8.9', '2.9')], [true, false, false]);
  install('curseforge');
  const looked = told(await updates.answerUpdate({ update: { check: true } }, game));
  ok('updates: what is out', [looked.addon, looked.plugin, looked.pluginNow, looked.checked, looked['notes.frFR'], looked['notes.nope'], fs.existsSync(path.join(own, 'tool.log'))], ['1.1.0', '99.0.0', '1.0.0', 'ok', 'a b c', undefined, false]);
  ok('updates: nothing said of the player', asked.every(([url, agent]) => agent === 'claude-in-wow' && ['/latest', '/release.json'].includes(url)), true);
  const news = path.join(addons, 'claude-in-wow_News');
  ok('updates: told to the game at its next login', [fs.readFileSync(path.join(news, 'Inbox.lua'), 'utf8').includes('addon=1.1.0'), /^## LoadOnDemand: 1$/m.test(fs.readFileSync(path.join(news, 'claude-in-wow_News.toc'), 'utf8')), (fs.readFileSync(path.join(news, 'claude-in-wow_News.toc'), 'utf8').match(/## Title/g) || []).length], [true, true, 1]);
  plugin = null;
  ok('updates: the addon left to CurseForge, unless the player chose GitHub', told(await updates.answerUpdate({ update: {} }, game)).addonState, 'curseforge');
  ok('updates: nothing downloaded then', [updates.waitingUpdates().length, asked.some(([url]) => url === '/a.zip')], [0, false]);
  put(closed, 'x'); // the game runs
  const fromGitHub = told(await updates.answerUpdate({ update: { from: 'github' } }, game));
  ok('updates: from GitHub: downloaded, for when the game is closed', [fromGitHub.addonState, fromGitHub.waits, updates.applyWaiting().length, updates.addonVersion(game)], ['ready', '1.1.0', 0, '1.0.0']);
  fs.rmSync(closed);
  ok('updates: installed once it is closed', [updates.applyWaiting().map(({ version, error }) => [version, error]), updates.addonVersion(game), updates.waitingUpdates().length], [[['1.1.0', undefined]], '1.1.0', 0]);
  ok('updates: the new files, not the old ones, what is in the Inbox kept', [fs.readFileSync(path.join(dir, 'New.lua'), 'utf8'), fs.existsSync(path.join(dir, 'Old.lua')), fs.readFileSync(path.join(dir, 'Inbox/001.wav'), 'utf8'), fs.existsSync(path.join(dir, 'Inbox/002.wav'))], ['new', false, 'kept', true]);
  ok('updates: undone, as it was', [updates.undoUpdate().undone?.[0].version, fs.readFileSync(path.join(dir, 'Old.lua'), 'utf8'), fs.existsSync(path.join(dir, 'New.lua'))], ['1.0.0', 'old', false]);
  // what must not get in
  hash = 'f'.repeat(64);
  ok('updates: not as published: refused', [told(await updates.answerUpdate({ update: { from: 'github' } }, game)).addonState, updates.waitingUpdates().length], ['failed', 0]);
  hash = null;
  for (const [what, files, mode] of [['out of the folder', { 'claude-in-wow/../../x.lua': 'x', 'claude-in-wow/claude-in-wow.toc': 'x' }], ['another addon', { 'Other/Other.toc': 'x' }], ['a drive', { 'claude-in-wow/C:x.lua': 'x', 'claude-in-wow/claude-in-wow.toc': 'x' }], ['a link', { 'claude-in-wow/claude-in-wow.toc': 'x' }, 0xa1ff], ['not the addon', { 'claude-in-wow/x.lua': 'x' }]]) {
    zip = zipOf(files, mode);
    ok(`updates: refused: ${what}`, told(await updates.answerUpdate({ update: { from: 'github' } }, game)).addonState, 'failed');
  }
  zip = Buffer.from('not a zip');
  ok('updates: refused: not a zip', told(await updates.answerUpdate({ update: { from: 'github' } }, game)).addonState, 'failed');
  zip = good;
  file = 'http://127.0.0.1:1/a.zip';
  ok('updates: an address of elsewhere is not one', told(await updates.answerUpdate({ update: { from: 'github' } }, game)).addon, undefined);
  file = null;
  install(null);
  ok('updates: a development copy is never replaced', [told(await updates.answerUpdate({ update: { from: 'github' } }, game)).addonState, updates.addonVersion(game)], ['dev', '1.0.0']);
  install('github');
  // changed on the disk between the download and the installation
  await updates.answerUpdate({ update: { from: 'github' } }, game);
  fs.writeFileSync(updates.waitingUpdates()[0].file, 'other');
  ok('updates: a file changed meanwhile: refused', [updates.applyWaiting()[0].error, updates.addonVersion(game)], ['checksum', '1.0.0']);
  // the plugin
  plugin = { version: '99.0.0', needsAddon: '1.0.5' };
  ok('updates: the plugin waits for the addon it needs', told(await updates.answerUpdate({ update: {} }, game)).pluginState, 'addonFirst');
  plugin = { version: '99.0.0', needsAddon: '1.0.0' };
  ok('updates: the plugin, by Claude Code', [told(await updates.answerUpdate({ update: {} }, game)).pluginState, fs.readFileSync(path.join(own, 'tool.log'), 'utf8').trim().split('\n'), path.basename(updates.newerPlugin())], ['done', ['plugin marketplace update market', 'plugin update wow-mcp@market'], '99.0.0']);
  const here = await import(pathToFileURL(path.join(pluginDir, 'server/updates.mjs')));
  ok('updates: a plugin read where it is worked on is not updated', here.newerPlugin(), null);
  // by itself
  const logged = [];
  install('github');
  put(path.join(game, 'WTF/Account/A/SavedVariables/claude-in-wow.lua'), 'ClaudeInWoWDB = {\n["options"] = {\n["updates"] = "auto",\n["updateFrom"] = "github",\n},\n}\n');
  fs.utimesSync(path.join(game, 'WTF/Account/A/SavedVariables/claude-in-wow.lua'), new Date(), new Date(Date.now() + 5000));
  plugin = null;
  await updates.latest(true);
  const known = asked.length;
  await updates.daily((line) => logged.push(line));
  ok('updates: by itself, when the player says so; looked for once a day', [updates.waitingUpdates().map(({ version }) => version), asked.slice(known).map(([url]) => url)], [['1.1.0'], ['/a.zip']]);
  nothing = true;
  ok('updates: nothing published yet: said', told(await updates.answerUpdate({ update: {} }, game)).checked, 'none');
  web.close();
  ok('updates: GitHub not reached: said', told(await updates.answerUpdate({ update: {} }, game)).checked, 'failed');
  for (const [name, value] of Object.entries(keep)) if (value === undefined) delete process.env[name]; else process.env[name] = value;
  fs.rmSync(own, { recursive: true, force: true });
}

// A player's own folders: the game where Battle.net put it, or where they say, what is kept in theirs
{
  const own = path.resolve('fakewow/own');
  const env = { home: path.join(own, 'home'), db: path.join(own, 'product.db') };
  const kept = Object.fromEntries(['CIW_HOME_DIR', 'CIW_PRODUCT_DB', 'CIW_SILENT_DIR', 'PATH', 'APPDATA'].map((name) => [name, process.env[name]]));
  const gameAt = (folder) => fs.mkdirSync(path.join(own, folder, 'WTF'), { recursive: true });
  gameAt('Jeux à moi/WoW (été)/_retail_');
  gameAt('Jeux à moi/WoW (été)/_classic_era_');
  gameAt('ailleurs/_forever_');
  const first = path.join(own, 'Jeux à moi', 'WoW (été)').replace(/\\/g, '/');
  fs.writeFileSync(env.db, Buffer.concat([Buffer.from([0x0a, 0x03]), Buffer.from('wow'), Buffer.from([0x12, 0x30]), Buffer.from(first), Buffer.from('2'), Buffer.from([0x05, 0x00]), Buffer.from('C:/Not/There'), Buffer.from([0x1a])]));
  Object.assign(process.env, { CIW_HOME_DIR: env.home, CIW_PRODUCT_DB: env.db });
  delete process.env.CIW_SILENT_DIR;
  const game = await import(`${pathToFileURL(path.join(pluginDir, 'server/game.mjs'))}?own`);
  const under = () => game.findGames().filter((dir) => path.resolve(dir).startsWith(own)).map((dir) => path.relative(own, dir).replace(/\\/g, '/')).sort();
  ok('own folders: found where Battle.net installed it, accents and all', under(), ['Jeux à moi/WoW (été)/_classic_era_', 'Jeux à moi/WoW (été)/_retail_']);
  ok('own folders: none there, said', Boolean(game.chooseGame(path.join(own, 'nowhere')).error), true);
  ok('own folders: where the player says', game.chooseGame(path.join(own, 'ailleurs')).games.map((dir) => path.basename(dir)), ['_forever_']);
  ok('own folders: kept for the next time, each once', [game.chooseGame(path.join(own, 'ailleurs')) && under().filter((dir) => dir.endsWith('_forever_')).length, JSON.parse(fs.readFileSync(path.join(env.home, 'config.json'), 'utf8')).games.length], [1, 1]);
  const home = await import(pathToFileURL(path.join(pluginDir, 'server/home.mjs')));
  ok('own folders: what is kept is in the player\'s', path.resolve(home.dataDir()) === path.resolve(env.home), true);
  // the claude command: not only where a terminal finds it
  const { claudeCommand } = await import(pathToFileURL(path.join(pluginDir, 'server/claude.mjs')));
  const npm = path.join(own, 'npm'), bin = path.join(own, 'bin dir');
  fs.mkdirSync(path.join(npm, 'node_modules/@anthropic-ai/claude-code'), { recursive: true });
  fs.writeFileSync(path.join(npm, 'claude.cmd'), '');
  fs.writeFileSync(path.join(npm, 'node_modules/@anthropic-ai/claude-code/cli.js'), '');
  if (process.platform === 'win32') {
    Object.assign(process.env, { PATH: npm });
    ok('claude: installed with npm, run without a shell', claudeCommand().map((one) => path.basename(one)).slice(1), ['cli.js']);
    fs.mkdirSync(bin);
    fs.writeFileSync(path.join(bin, 'claude.exe'), '');
    Object.assign(process.env, { PATH: `"${bin}";${npm}` });
    ok('claude: the program itself first', path.resolve(claudeCommand()[0]), path.join(bin, 'claude.exe'));
  }
  for (const [name, value] of Object.entries(kept)) if (value === undefined) delete process.env[name]; else process.env[name] = value;
  fs.rmSync(own, { recursive: true, force: true });
}

// What the player says in the session itself, shown in the game
{
  const inbox = path.join(wow, 'Interface/AddOns/claude-in-wow/Inbox');
  const slotOf = (n) => path.join(wow, `Interface/AddOns/claude-in-wow_S${String(n).padStart(3, '0')}`);
  const made = [];
  fs.mkdirSync(inbox, { recursive: true });
  for (const n of [241, 242]) { const f = path.join(inbox, `${n}.wav`); if (!fs.existsSync(f)) { fs.writeFileSync(f, ''); made.push(f); } }
  for (const n of [191, 192]) if (!fs.existsSync(slotOf(n))) { fs.mkdirSync(slotOf(n), { recursive: true }); const { slotFile } = await import(pathToFileURL(path.join(pluginDir, 'server/slots.mjs'))); fs.mkdirSync(path.dirname(slotFile(wow, n)), { recursive: true }); fs.writeFileSync(slotFile(wow, n), ''); made.push(slotOf(n)); }
  const { slotFile } = await import(pathToFileURL(path.join(pluginDir, 'server/slots.mjs')));
  const spareFile = path.join(shotsDir, 'WoWScrnShot_spare.png');
  const spareAt = askedAt + 40;
  const data = Buffer.from(JSON.stringify({ key: 'Arden Valcourt', savedAt: spareAt, character: {}, spare: { at: spareAt, list: [{ signal: 241, slot: 191, from: 1 }, { signal: 242, slot: 192, from: 1 }] } }));
  const text = data.toString('base64').replace(/=+$/, '');
  const head = Buffer.from(`CIW1 ${spareAt} 1 1 100 ${Math.ceil(text.length / 100)} ${data.length} ${adler32(data)} 8 json 1040 240`.padEnd(72));
  fs.writeFileSync(spareFile, png(1040, 240, paintLines([{ x: 4, y: 4, text: head.toString('base64') }, ...text.match(/.{1,100}/g).map((t, i) => ({ x: 4, y: 12 + i * 8, text: t }))])));
  const saidDir = path.resolve('fakewow/said');
  fs.mkdirSync(saidDir, { recursive: true });
  const keptDir = process.env.CIW_SILENT_DIR;
  process.env.CIW_SILENT_DIR = saidDir;
  const talker = startServer(wow);
  if (keptDir === undefined) delete process.env.CIW_SILENT_DIR; else process.env.CIW_SILENT_DIR = keptDir;
  await talker.request('initialize', { protocolVersion: '2025-06-18' });
  const one = (await talker.call('answer_to_game', { text: 'Au **nord**.', asked: ' Où est Ti\'ik ? ', sound: false })).data;
  const written = fs.readFileSync(slotFile(wow, 191), 'utf8');
  ok('said in the session: in the first place set apart, with what was asked', [one.delivered, /\[claude-in-wow dit (\d+)\]\n\nOù est Ti'ik \?\n\n\[claude-in-wow réponse \1\]\n\nAu \*\*nord\*\*\./.test(written), fs.statSync(path.join(inbox, '241.wav')).size > 0, one.places.startsWith('1 more'), one.next], [true, true, true, true, undefined]);
  const two = (await talker.call('answer_to_game', { text: 'Au sud.', asked: 'Et lui ?', sound: false })).data;
  ok('said in the session: the next one, then no place is left', [two.delivered, fs.readFileSync(slotFile(wow, 192), 'utf8').includes('Et lui ?'), two.places.startsWith('No place')], [true, true, true]);
  const three = (await talker.call('answer_to_game', { text: 'Rien.', asked: 'Encore ?', sound: false })).data;
  ok('said in the session: to paste when no place is left', [three.delivered, three.copied, /^\[claude-in-wow dit \d+\]\n\nEncore \?/.test(fs.readFileSync(path.resolve('fakewow/clipboard.txt'), 'utf8'))], [false, true, true]);
  const asked = (await talker.call('answer_to_game', { text: 'Voilà', question: 1795534604, asked: 'x', sound: false })).data;
  ok('a question of the game: what to run to listen again', [asked.next.includes('listen.mjs" --after 1795534604'), asked.places], [true, undefined]);
  talker.server.stdin.end();
  fs.rmSync(spareFile, { force: true });
  fs.rmSync(saidDir, { recursive: true, force: true });
  for (const f of made) fs.rmSync(f, { recursive: true, force: true });
}

// The silent mode: a hidden program answers each question with claude -p (a
// fake one here), copies the answer marked with its question and what it knows
// of the session, and keeps one Claude session for all questions
const waitFor = async (test, ms = 20000) => {
  for (const end = Date.now() + ms; Date.now() < end; await new Promise((r) => setTimeout(r, 100))) if (test()) return true;
  return false;
};
const clipboardText = () => { try { return fs.readFileSync(path.resolve('fakewow/clipboard.txt'), 'utf8'); } catch { return ''; } };
const isCopy = (question, n, model = 'opus-5.5') => new RegExp(`^\\[claude-in-wow réponse ${question.at} session=session- n=${n} s=\\d+ m=${model} c=\\d+ t=\\d+ r=\\d+ d=[\\d,]+ l=de\\]\\n\\nRéponse : ${question.text.replace('?', '\\?')}$`);
const silentServer = startServer(wow);
await silentServer.request('initialize', { protocolVersion: '2025-06-18' });
process.env.CIW_SILENT_DIR = path.resolve('fakewow'); // here too
ok('silent mode: not running yet', (await silentServer.call('silent_mode', { action: 'status' })).data.running, false);
const silentStarted = await silentServer.call('silent_mode', { action: 'start', folder: path.resolve('fakewow') });
ok('silent mode: started', silentStarted.data.started, true);
ok('silent mode: running', await waitFor(() => fs.existsSync(path.resolve('fakewow/claude-in-wow-silent.json'))), true);
ok('silent mode: a listening session is warned', Boolean((await silentServer.call('listen', {})).data.silentMode), true);
// the addon test's question photo is dated two minutes ahead: answered first
const pending = { at: askedAt, text: 'Que faire de mes sacs ?' };
ok('silent mode: a question sent since it started is answered, marked with its question', await waitFor(() => isCopy(pending, 1).test(clipboardText())), true);
const silentFiles = [];
const seen = [pending.at]; // each question tells which answers are there: one answer in the clipboard
const ask = (question, all = true) => {
  const sent = { id: question.at, kind: 'free', got: all ? [...seen] : undefined, ...question };
  silentFiles.push(questionPhoto(path.join(shotsDir, `WoWScrnShot_silent${question.at}.png`), sent));
  seen.push(question.at);
  return question;
};
const claudeCalls = () => fs.readFileSync(path.resolve('fakewow/claude.log'), 'utf8').trim().split('\n').map((line) => JSON.parse(line));
const option = (call, name) => (call.args.includes(name) ? call.args[call.args.indexOf(name) + 1] : null);
const last = () => claudeCalls().pop();

const t1 = ask({ at: askedAt + 60, text: 'Où est Lard ?', tab: 'Conversation A' });
ok('silent mode: a new question answered and copied', await waitFor(() => isCopy(t1, 2).test(clipboardText())), true);
ok('silent mode: claude -p with the tools, the session resumed, saved', [last().args.slice(0, 5), Boolean(option(last(), '--resume')), last().args.includes('--no-session-persistence'), last().args.includes('--model'), last().args.includes('--effort')],
  [['-p', '--output-format', 'stream-json', '--verbose', '--allowedTools'], true, false, false, false]);
ok('silent mode: the tokens the answer took, in its mark', / c=31 t=31102 r=30000 d=\d+,\d+,\d+,0,100,1 l=de\]/.test(clipboardText()), true);
const session = option(last(), '--resume');
const t2 = ask({ at: askedAt + 70, text: 'Et mes sacs ?', kind: 'bags', tab: 'Conversation B' });
ok('silent mode: the next question too, whatever its tab, in the same session', [await waitFor(() => isCopy(t2, 3).test(clipboardText())), option(last(), '--resume') === session, last().prompt.includes('Conversation B')], [true, true, true]);

// two questions at once: one in the session, the other beside it and unsaved,
// both answers in the clipboard, in order
const t4 = ask({ at: askedAt + 90, text: 'Première ?', tab: 'A' });
const t5 = ask({ at: askedAt + 91, text: 'Seconde ?', tab: 'B' }, false);
ok('silent mode: two at once, both answers in the clipboard, in order', await waitFor(() => {
  const text = clipboardText();
  return text.includes(`réponse ${t4.at} `) && text.includes(`réponse ${t5.at} `) && text.indexOf('Première') < text.indexOf('Seconde');
}), true);
const together = claudeCalls().slice(-2);
const inSession = together.find((c) => option(c, '--resume') === session), beside = together.find((c) => c.args.includes('--no-session-persistence'));
ok('silent mode: one in the session, the other beside it, not saved, with a recap',
  [Boolean(inSession), Boolean(beside) && !beside.args.includes('--resume'), beside?.prompt.includes('for memory:') && beside.prompt.includes('Où est Lard ?')], [true, true, true]);
ok('silent mode: its status, with the session and what is to paste', await waitFor(() => {
  const s = JSON.parse(fs.readFileSync(path.resolve('fakewow/claude-in-wow-silent.json'), 'utf8'));
  return s.answered === 5 && s.waiting === 0;
}), true);
const silentState = (await silentServer.call('silent_mode', { action: 'status' })).data;
ok('silent mode: its status says the session, the model and what is to paste',
  [silentState.running, silentState.answered, silentState.answersToPaste, silentState.questionsWaiting, silentState.model, silentState.sessionTokens], [true, 5, 2, 0, 'claude-opus-5-5', 31102]);

// the session is told of what was answered beside it, once
const t6 = ask({ at: askedAt + 100, text: 'Une question lourde ?' });
ok('silent mode: the session learns what was answered beside it', [await waitFor(() => isCopy(t6, 6).test(clipboardText())), last().prompt.includes('Meanwhile') && last().prompt.includes(`Asked: ${beside.prompt.split('\n')[2]}`), option(last(), '--resume') === session], [true, true, true]);
// a very large session is renewed, with a recap
const t7 = ask({ at: askedAt + 110, text: 'Après la lourde ?' });
ok('silent mode: a very large session is renewed, with a recap', [await waitFor(() => isCopy(t7, 1).test(clipboardText())), option(last(), '--resume'), last().prompt.includes('for memory:') && last().prompt.includes('Asked: Une question lourde ?')], [true, null, true]);
const t8 = ask({ at: askedAt + 120, text: 'Encore une lourde ?', options: { renew: false } });
ok('silent mode: what the session knows is not told again', [await waitFor(() => isCopy(t8, 2).test(clipboardText())), last().prompt.includes('Asked:')], [true, false]);
const t9 = ask({ at: askedAt + 130, text: 'Jamais renouvelée ?', options: { renew: false } });
ok('silent mode: never renewed, when the player prefers so', [await waitFor(() => isCopy(t9, 3).test(clipboardText())), Boolean(option(last(), '--resume'))], [true, true]);
// one no longer cached (CIW_CACHE_S), worth renewing
const t14 = ask({ at: askedAt + 132, text: 'Une longue ?' });
ok('silent mode: a small session is resumed even after a pause', [await waitFor(() => isCopy(t14, 4).test(clipboardText())), Boolean(option(last(), '--resume'))], [true, true]);
const t15 = ask({ at: askedAt + 134, text: 'Après une pause ?' });
ok('silent mode: a session no longer cached is renewed, with a recap', [await waitFor(() => isCopy(t15, 1).test(clipboardText())), option(last(), '--resume'), last().prompt.includes('Asked: Une longue ?')], [true, null, true]);
// the model the player picked; another one renews the session
const t10 = ask({ at: askedAt + 140, text: 'Avec Sonnet ?', model: 'sonnet' });
ok('silent mode: the model picked answers, in a session of its own with a recap', [await waitFor(() => isCopy(t10, 1, 'sonnet-5.5').test(clipboardText())), option(last(), '--model'), option(last(), '--resume'), last().prompt.includes('for memory:')], [true, 'sonnet', null, true]);
const t11 = ask({ at: askedAt + 150, text: 'Un modèle inconnu ?', model: '--dangerously-skip-permissions' });
ok('silent mode: a model it does not know is left out', [await waitFor(() => isCopy(t11, 1).test(clipboardText())), last().args.includes('--dangerously-skip-permissions')], [true, false]);
// the effort the player picked
const t16 = ask({ at: askedAt + 154, text: 'En réfléchissant ?', effort: 'high' });
ok('silent mode: the effort picked, in the same session while it is small', [await waitFor(() => isCopy(t16, 2).test(clipboardText())), option(last(), '--effort'), Boolean(option(last(), '--resume'))], [true, 'high', true]);
const t17 = ask({ at: askedAt + 156, text: 'Un effort inconnu ?', effort: '--model' });
ok('silent mode: an effort it does not know is left out', [await waitFor(() => isCopy(t17, 3).test(clipboardText())), last().args.includes('--effort')], [true, false]);
// a new session asked by the player forgets
const silentSession = () => JSON.parse(fs.readFileSync(path.resolve('fakewow/claude-in-wow-silent.json'), 'utf8')).session;
const leftSession = silentSession(), leftFile = sessionFile(`kept/${leftSession}.jsonl`), otherFile = sessionFile('kept/another-session.jsonl');
for (const file of [leftFile, otherFile]) fs.writeFileSync(file, '');
const t3 = ask({ at: askedAt + 160, text: 'Une nouvelle session ?', newSession: true });
ok('silent mode: a new session asked by the player forgets the rest', [await waitFor(() => isCopy(t3, 1).test(clipboardText())), option(last(), '--resume'), last().prompt.includes('Asked:')], [true, null, false]);
ok('silent mode: one session kept, the one replaced erased, no other touched', [await waitFor(() => !fs.existsSync(leftFile)), fs.existsSync(otherFile), silentSession() !== leftSession], [true, true, true]);
// how much of the player's plan is used, as claude says it; the game's part of it
{
  const { planLedger, weigh } = await import(pathToFileURL(path.join(pluginDir, 'server/share.mjs')).href);
  ok('share: what a message weighs', [weigh('claude-opus-5-5', { input_tokens: 1e6, output_tokens: 0 }), weigh('claude-haiku-5-5', { input_tokens: 1000, output_tokens: 1000 }) * 1e6, weigh('claude-opus-5-5', { cache_creation_input_tokens: 1e6, cache_creation: { ephemeral_1h_input_tokens: 5e5 }, cache_read_input_tokens: 1e6 }).toFixed(3), weigh('<synthetic>', { output_tokens: 5 })],
    [4, 600, '6.700', 0]);
  const ledger = planLedger(path.resolve('fakewow'), { root: sessions });
  const hourAgo = Math.floor(Date.now() / 1000) - 3600;
  ok('share: nothing read yet', ledger.share(hourAgo), null);
  await ledger.refresh();
  ok('share: the game against all the sessions, a message counted once', [ledger.share(hourAgo), ledger.share(hourAgo + 7200), ledger.share(hourAgo, 'haiku')], [0.25, null, null]);
  const more = spoken('m3', 400, { entrypoint: 'sdk-cli' }), file = sessionFile('game/c.jsonl');
  fs.writeFileSync(file, more.slice(0, 40));
  await ledger.refresh();
  ok('share: a line still being written waits', ledger.share(hourAgo), 0.25);
  fs.appendFileSync(file, more.slice(40));
  await ledger.refresh();
  ok('share: then counts', ledger.share(hourAgo), 0.625);
  ledger.note('m4', Date.now(), 'claude-opus-5-5', { output_tokens: 700 });
  ok('share: an answer beside the session', ledger.share(hourAgo), 0.8);
  fs.rmSync(file);
  fs.writeFileSync(sessionFile('game/d.jsonl'), spoken('m5', 500, { entrypoint: 'sdk-cli', cwd: path.resolve('elsewhere') }));
  const again = planLedger(path.resolve('fakewow'), { root: sessions, kept: [{ id: 'm6', at: Date.now(), model: 'claude-opus-5-5', usage: { output_tokens: 100 } }] });
  await again.refresh();
  ok('share: another folder is not the game\'s; those beside are kept', again.share(hourAgo), 0.2);
  fs.rmSync(sessionFile('game/d.jsonl'));
  ok('share: no sessions at all', [await planLedger('x', { root: path.resolve('fakewow/nowhere') }).refresh()], [undefined]);
}
const plan1 = ask({ at: askedAt + 162, text: 'Et mon forfait ?' });
ok('silent mode: the plan in the mark, as claude says it', [await waitFor(() => clipboardText().includes(`réponse ${plan1.at} `)), / p=5h:30:1795567200:750,7d:56:1795870800:1400,7d-opus:10:1795870800:250 l=de\]/.test(clipboardText())], [true, true]);
const plan3 = ask({ at: askedAt + 163, text: 'Mon forfait sans la part ?', options: { off: ['planShare'] } });
ok('silent mode: the game\'s part left out', [await waitFor(() => clipboardText().includes(`réponse ${plan3.at} `)), / p=5h:30:1795567200,7d:56:1795870800,7d-opus:10:1795870800 l=de\]/.test(clipboardText())], [true, true]);
const plan2 = ask({ at: askedAt + 164, text: 'Mon forfait épuisé ?', options: { language: 'itIT' } });
ok('silent mode: no answer, the plan may be why', [await waitFor(() => clipboardText().includes(`réponse ${plan2.at} p=5h:30:`)), clipboardText().includes('il limite del tuo piano è stato raggiunto')], [true, true]);
// an API key of the player's: given to claude alone, paid by use; never another program's
ok('silent mode: another program\'s API key is never used', last().key, undefined);
const KEYQ = [null, 'Avec ma clé', 'Encore avec ma clé', 'Ma clé, refusée', 'Sans ma clé'];
fs.writeFileSync(path.resolve('fakewow/key.txt'), 'sk-test-key\n');
const key1 = ask({ at: askedAt + 164.1, text: 'Avec ma clé ?' });
ok('silent mode: with the player\'s key, a new session, its price in the mark', [await waitFor(() => clipboardText().includes(KEYQ[1])), last().key, option(last(), '--resume'), / u=30000 l=de\]/.test(clipboardText())], [true, 'sk-test-key', null, true]);
const key2 = ask({ at: askedAt + 164.2, text: 'Encore avec ma clé ?' });
ok('silent mode: resumed, the price of this answer alone', [await waitFor(() => clipboardText().includes(KEYQ[2])), Boolean(option(last(), '--resume')), / u=20000 l=de\]/.test(clipboardText())], [true, true, true]);
const key3 = ask({ at: askedAt + 164.3, text: 'Ma clé, refusée ?', options: { language: 'frFR' } });
ok('silent mode: a key refused, said so', [await waitFor(() => clipboardText().includes('Votre clé API a été refusée.')), clipboardText().includes('Votre clé API a été refusée.')], [true, true]);
fs.rmSync(path.resolve('fakewow/key.txt'));
const key4 = ask({ at: askedAt + 164.4, text: 'Sans ma clé ?' });
ok('silent mode: the key removed, the plan again, in a new session', [await waitFor(() => clipboardText().includes(KEYQ[4])), last().key, option(last(), '--resume'), clipboardText().includes(' u=')], [true, undefined, null, false]);
// how much a new session remembers, and past how many tokens it comes
const size1 = ask({ at: askedAt + 165, text: 'Une grande session ?', options: { renewAt: 25000, remember: 1 } });
ok('silent mode: past the tokens the player picked, a new one that remembers so many questions',
  [await waitFor(() => clipboardText().includes(`réponse ${size1.at} `)), option(last(), '--resume'), (last().prompt.match(/- .*Asked: /g) || []).length], [true, null, 1]);
const size2 = ask({ at: askedAt + 166, text: 'Sans mémoire ?', options: { renewAt: 25000, remember: 0 } });
ok('silent mode: one that remembers none', [await waitFor(() => clipboardText().includes(`réponse ${size2.at} `)), option(last(), '--resume'), last().prompt.includes('Asked:')], [true, null, false]);
const size4 = ask({ at: askedAt + 166.5, text: 'Une lourde, sans limite ?', options: { renewAt: 0 } });
ok('silent mode: no size replaces it', [await waitFor(() => clipboardText().includes('Une lourde, sans limite')), Boolean(option(last(), '--resume'))], [true, true]);
const size5 = ask({ at: askedAt + 166.8, text: 'Encore, après la lourde ?', options: { renewAt: 0, renewPause: 0 } });
ok('silent mode: nor a very large one', [await waitFor(() => clipboardText().includes('Encore, après la lourde')), Boolean(option(last(), '--resume'))], [true, true]);
const size6 = ask({ at: askedAt + 166.9, text: 'Toutes retenues ?', options: { renewAt: 20000, remember: -1 } });
ok('silent mode: all the questions remembered', [await waitFor(() => clipboardText().includes('Toutes retenues')), option(last(), '--resume'), (last().prompt.match(/- .*Asked: /g) || []).length > 6], [true, null, true]);
const size3 = ask({ at: askedAt + 167, text: 'Des choix impossibles ?', options: { renewAt: -5, remember: 1e9 } });
ok('silent mode: what makes no sense is left out', [await waitFor(() => clipboardText().includes(`réponse ${size3.at} `)), Boolean(option(last(), '--resume'))], [true, true]);
// after how long a pause, and past how many tokens then (the tests' usual pause is none)
const pause1 = ask({ at: askedAt + 168, text: 'Une longue pause ?', options: { renewPause: 86400, renewPauseAt: 0 } });
ok('silent mode: a pause shorter than the player picked', [await waitFor(() => clipboardText().includes(`réponse ${pause1.at} `)), Boolean(option(last(), '--resume'))], [true, true]);
const pause2 = ask({ at: askedAt + 169, text: 'Une longue, jamais ?', options: { renewPause: 0, renewPauseAt: 0 } });
ok('silent mode: no pause counts', [await waitFor(() => clipboardText().includes(`réponse ${pause2.at} `)), Boolean(option(last(), '--resume'))], [true, true]);
await new Promise((r) => setTimeout(r, 1200));
const pause3 = ask({ at: askedAt + 169.5, text: 'Assez petite ?', options: { renewPause: 1, renewPauseAt: 250000 } });
ok('silent mode: after the pause, small enough to go on', [await waitFor(() => clipboardText().includes('Assez petite')), Boolean(option(last(), '--resume'))], [true, true]);
await new Promise((r) => setTimeout(r, 1200));
const pause4 = ask({ at: askedAt + 169.8, text: 'Trop grande ?', options: { renewPause: 1, renewPauseAt: 20000 } });
ok('silent mode: after the pause, past the size', [await waitFor(() => clipboardText().includes('Trop grande')), option(last(), '--resume')], [true, null]);
// in turn, when the player prefers so: the second goes in the session
const t12 = ask({ at: askedAt + 170, text: 'À tour ?', options: { parallel: false } });
const t13 = ask({ at: askedAt + 171, text: 'De rôle ?', options: { parallel: false } });
ok('silent mode: in turn, when the player prefers so', [await waitFor(() => isCopy(t13, 3).test(clipboardText())), claudeCalls().slice(-2).every((c) => option(c, '--resume') && !c.args.includes('--no-session-persistence'))], [true, true]);
// put in the game: the answer in a slot, the signal filled, and emptied once taken
const addonsDir = path.join(wow, 'Interface', 'AddOns');
const signal = (n) => path.join(addonsDir, 'claude-in-wow', 'Inbox', `${n}.wav`);
const slot = (n) => path.join(addonsDir, `claude-in-wow_S${n}`, 'Inbox.lua');
for (const file of [signal('007'), signal('a007'), slot('003'), signal('009'), slot('004')]) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, '');
}
const t18 = ask({ at: askedAt + 180, text: 'Dans le jeu ?', signal: 7, slot: 3, options: { soundReady: true } });
ok('silent mode: the question is acknowledged in the game', await waitFor(() => fs.statSync(signal('a007')).size > 1000), true);
ok('silent mode: in the game, the signal after the slot', [await waitFor(() => fs.statSync(signal('007')).size > 1000), fs.readFileSync(slot('003'), 'utf8').includes(`ClaudeInWoWInbox = [=[\n[claude-in-wow réponse ${t18.at} `),
  fs.readFileSync(signal('007')).toString('latin1', 0, 4)], [true, true, 'RIFF']);
ok('silent mode: in the clipboard too', await waitFor(() => clipboardText().includes(`réponse ${t18.at} `)), true);
const t19 = ask({ at: askedAt + 190, text: 'Fin ]=] de crochet, sans son ?', signal: 9, slot: 4, options: { soundReady: false } });
ok('silent mode: the files of an answer that arrived are emptied', [await waitFor(() => fs.statSync(signal('009')).size > 0), fs.statSync(signal('007')).size, fs.readFileSync(slot('003'), 'utf8').includes('Inbox =')], [true, 0, false]);
ok('silent mode: a text that closes brackets stays a text', fs.readFileSync(slot('004'), 'utf8').includes('ClaudeInWoWInbox = [==[\n'), true);
const samples = fs.readFileSync(signal('009')).subarray(44);
ok('silent mode: without the sound, a signal as long but silent', [samples.length > 2 * 22050 * 0.5, samples.every((byte) => byte === 0)], [true, true]);
const t20 = ask({ at: askedAt + 200, text: 'Hors du dossier ?', signal: '../../../x', slot: 5000 });
ok('silent mode: only the addon\'s own files', [await waitFor(() => clipboardText().includes(`réponse ${t20.at} `)), fs.existsSync(path.join(addonsDir, 'claude-in-wow_S5000')), fs.readdirSync(addonsDir).includes('x.wav')], [true, false, false]);
const t21 = ask({ at: askedAt + 210, text: 'Pas installé ?', signal: 8, slot: 5 });
ok('silent mode: files that are not there are not made', [await waitFor(() => clipboardText().includes(`réponse ${t21.at} `)), fs.existsSync(signal('008')), fs.existsSync(slot('005'))], [true, false, false]);
const inGame = await silentServer.call('answer_to_game', { text: 'Par la conversation', question: t18.at });
ok('answer to the game: shown in it when the question asks for that', [inGame.data.delivered, fs.statSync(signal('007')).size > 1000, fs.readFileSync(slot('003'), 'utf8').includes(`[claude-in-wow réponse ${t18.at}]\n\nPar la conversation\n]=]`)], [true, true, true]);
const { installedAddons } = await import(pathToFileURL(path.join(pluginDir, 'server/addons.mjs')));
fs.writeFileSync(path.join(addonsDir, 'claude-in-wow_S003', 'claude-in-wow_S003.toc'), '## Interface: 16001\n## Title: slot\nInbox.lua\n');
ok('the slots are not listed among the addons', installedAddons(wow).some((a) => a.name.startsWith('claude-in-wow_S')), false);
// what was read in the game for a question goes to Claude with it, and how to
// propose more
const t24 = ask({ at: askedAt + 212, text: 'Ma guilde ?', read: { guild: { name: 'Cuvée Spéciale', online: [{ name: 'Torvald', zone: 'Orgrimmar' }] } } });
ok('silent mode: what was read for the question, in the prompt', [await waitFor(() => clipboardText().includes(`réponse ${t24.at} `)), last().prompt.includes('"zone":"Orgrimmar"'), last().prompt.includes('limits')], [true, true, false]);
const t25 = ask({ at: askedAt + 216, text: 'Rien de lu ?' });
ok('silent mode: nothing read', [await waitFor(() => clipboardText().includes(`réponse ${t25.at} `)), last().prompt.includes('Read in the game')], [true, false]);
const calls26 = claudeCalls().length;
ask({ at: askedAt + 216.5, text: 'update', kind: 'update', update: { check: true } });
ok('silent mode: an update asked by the game is not a question to Claude', [await waitFor(() => fs.readFileSync(path.resolve('fakewow/claude-in-wow-silent.log'), 'utf8').includes('updates: asked from the game')), claudeCalls().length], [true, calls26]);
const before26 = fs.readFileSync(path.resolve('fakewow/claude-in-wow-silent.log'), 'utf8').length;
const bySession26 = ask({ at: askedAt + 217, text: 'Pour la session visible ?', options: { by: 'session' } });
const seenBy = await new Promise((resolve) => {
  const child = spawn(process.execPath, [listenScript, '--after', String(askedAt + 216), '--hours', '0.005'], { env: { ...listenEnv, CIW_SILENT_DIR: path.resolve('fakewow') } });
  let out = '';
  child.stdout.on('data', (d) => { out += d; });
  child.on('exit', () => resolve(out));
});
ok('a session the player sees: its question is printed there, while the silent mode runs', seenBy.includes('Pour la session visible ?') && seenBy.includes(`question=${bySession26.at}`), true);
const t26 = ask({ at: askedAt + 218, text: 'Sans pastilles ?', options: { off: ['chips', 'actions', '; rm', 'web'] } });
ok('silent mode: leaves the question for the session', [await waitFor(() => clipboardText().includes(`réponse ${t26.at} `)), fs.readFileSync(path.resolve('fakewow/claude-in-wow-silent.log'), 'utf8').slice(before26).includes('Pour la session')], [true, false]);
ok('silent mode: what the player turned off is told', [await waitFor(() => clipboardText().includes(`réponse ${t26.at} `)), last().prompt.includes("The player's limits: no questions block; no buttons block; do not search the web."), option(last(), '--tools'), option(last(), '--allowedTools')], [true, true, 'Read,Grep,Glob', 'mcp__claude-in-wow,Read,Grep,Glob']);
const tWeb = ask({ at: askedAt + 219, text: 'Avec internet ?', options: { off: ['searches', 'addons'] } });
ok('silent mode: how far it may look', [await waitFor(() => clipboardText().includes(`réponse ${tWeb.at} `)), last().prompt.includes('two calls of tools at most'), option(last(), '--tools'), last().args.includes('--add-dir')], [true, true, 'WebSearch,WebFetch', false]);
ok('silent mode: the addons limited, their tools refused', JSON.parse(fs.readFileSync(option(last(), '--mcp-config'), 'utf8')).mcpServers['claude-in-wow'].env.CIW_ADDONS, 'no');
const tAll = ask({ at: askedAt + 219.5, text: 'Sans limite ?' });
await waitFor(() => clipboardText().includes(`réponse ${tAll.at} `));
ok('silent mode: no limit at first', [option(last(), '--tools'), option(last(), '--allowedTools'), last().args.includes('--add-dir'), last().prompt.includes('limits')], ['WebSearch,WebFetch,Read,Grep,Glob', 'mcp__claude-in-wow,WebSearch,WebFetch,Read,Grep,Glob', true, false]);
const tChat = ask({ at: askedAt + 219.7, text: 'Que dit le chat ?', read: { chat: { lines: [] } } });
await waitFor(() => clipboardText().includes(`réponse ${tChat.at} `));
ok('silent mode: players\' chat in the session: a list of sites only', [option(last(), '--allowedTools').includes('WebFetch(domain:www.wowhead.com)'), option(last(), '--allowedTools').split(',').includes('WebFetch'), option(last(), '--tools')], [true, false, 'WebSearch,WebFetch,Read,Grep,Glob']);
// the modules: what Claude is started with, the player's own files over the plugin's
const { loadModules, systemPrompt } = await import(pathToFileURL(path.join(pluginDir, 'server/modules.mjs')));
ok('modules: each with its key, in order', loadModules().map((m) => m.key), ['answer', 'places', 'route', 'players', 'gameLinks', 'web', 'chips', 'why', 'actions', 'strings', 'marks', 'addons']);
fs.mkdirSync(path.resolve('fakewow/modules'), { recursive: true });
fs.writeFileSync(path.resolve('fakewow/modules/30-players.md'), '---\nkey: players\ntitle: Mine\n---\nMy own words.');
fs.writeFileSync(path.resolve('fakewow/modules/99-more.md'), 'One more.');
const own = loadModules(path.resolve('fakewow'));
ok('modules: the player\'s own replace and add', [own.find((m) => m.key === 'players').text, own.at(-1).key, own.length], ['My own words.', 'more', 13]);
ok('quests: those handed in, as the game says', (await silentServer.call('quests', { ids: [7, 8, 7029] })).data.quests.map((q) => [q.id, q.inLog, q.handedIn]), [[7, false, true], [8, false, false], [7029, true, false]]);
// import strings: the format, the aura, their marks
{
  const { decodeForPrint, encodeForPrint, importString, keepString, putStrings, serialize, trackerCode } = await import(pathToFileURL(path.join(pluginDir, 'server/strings.mjs')));
  ok('strings: a table as AceSerializer writes it', serialize({ a: [1, true], 2: 'x y' }), '^1^T^N2^Sx~`y^Sa^T^N1^N1^N2^B^t^t^^');
  const made = importString({ name: 'Foire', list: [1, 2, 3] });
  ok('strings: it reads back', [made[0], zlib.inflateRawSync(decodeForPrint(made.slice(1))).toString()], ['!', serialize({ name: 'Foire', list: [1, 2, 3] })]);
  ok('strings: every length reads back', [0, 1, 2, 3, 4, 5, 6, 7].every((n) => { const bytes = Buffer.from([...Array(n)].map((_, i) => 250 - i * 37)); return decodeForPrint(encodeForPrint(bytes)).equals(bytes); }), true);
  ok('strings: what is written in the aura stays text', trackerCode('A"b\\c', [{ item: '5', need: 3 }, { text: 'x"\ny' }, { quest: 'evil)', text: 'Q' }]).includes('head("A\\"b\\\\c")'), true);
  const mark = keepString(made);
  ok('strings: the mark, then the string in its place', [/^\{\{string:[0-9a-f]{8}\}\}$/.test(mark), putStrings(`a ${mark} b`), putStrings('{{string:00000000}}')], [true, `a ${made} b`, '{{string:00000000}}']);
  const asked = (await silentServer.call('import_string', { name: 'Foire', title: 'Foire', lines: [{ header: true, text: 'Sac' }, { item: 19291, need: 1 }, { quest: 7934 }] })).data;
  ok('import_string: outside the game, the string itself', [asked.string[0], asked.characters === asked.string.length, zlib.inflateRawSync(decodeForPrint(asked.string.slice(1))).toString().includes('item(19291,~`1,~`nil)')], ['!', true, true]);
}
// names: links for what the search knows, never people
{
  const { linkNames, people } = await import(pathToFileURL(path.join(pluginDir, 'server/names.mjs')));
  const asked = [];
  const look = async (site, name) => { asked.push(name); return name === 'Darkmoon Storage Box' ? { type: 'item', id: 19291, name } : null; };
  const leave = people({ guild: { online: [{ name: 'Muspelheim Kvistr', note: 'Forge' }] } });
  ok('names: in bold, made links; people, code and links left', await linkNames('**Darkmoon Storage Box**, **Muspelheim Kvistr**, **pas un nom**, **[Lard](npc:14731)**\n\n```\n**Autre Nom**\n```', leave, look),
    '**[Darkmoon Storage Box](item:19291)**, **Muspelheim Kvistr**, **pas un nom**, **[Lard](npc:14731)**\n\n```\n**Autre Nom**\n```');
  ok('names: nobody looked up but that one', [...new Set(asked)], ['Darkmoon Storage Box']);
  ok('names: found before, linked where they are written, once', await linkNames('Le Darkmoon Storage Box, puis un Darkmoon Storage Box, `Darkmoon Storage Box`.', new Set(), look), 'Le [Darkmoon Storage Box](item:19291), puis un Darkmoon Storage Box, `Darkmoon Storage Box`.');
  asked.length = 0;
  await linkNames('**Darkmoon Storage Box**', new Set(), look);
  ok('names: asked once', asked.length, 0);
}
// the versions of the game
{
  const { FLAVORS, flavorOf, wowheadSites } = await import(pathToFileURL(path.join(pluginDir, 'server/flavors.mjs')));
  const names = ['_retail_', '_classic_', '_classic_era_', '_anniversary_', '_forever_', '_ptr_', '_classic_era_ptr_', '_beta_'];
  ok('versions: each folder\'s', names.map((name) => flavorOf(path.join('W', name)).key), ['retail', 'mop', 'era', 'tbc', 'forever', 'retail', 'era', 'retail']);
  ok('versions: what the addon says comes first', flavorOf('W/_classic_', { game: { flavor: 'cata' } }).key, 'cata');
  ok('versions: Wowhead\'s pages, in the client\'s language', [wowheadSites(FLAVORS.retail, 'frFR'), wowheadSites(FLAVORS.era, 'enUS'), wowheadSites(FLAVORS.forever, 'deDE')[1]],
    [[['https://www.wowhead.com', 'https://www.wowhead.com/fr']], [['https://www.wowhead.com/classic']], ['https://www.wowhead.com/classic', 'https://www.wowhead.com/classic/de']]);
  ok('versions: what Claude is told', [systemPrompt(null, { game: { flavor: 'era' } }, 'W/_classic_era_').includes('a player of World of Warcraft Classic:'), systemPrompt(null, { game: { flavor: 'retail', locale: 'enUS' } }, 'W/_retail_').includes('www.wowhead.com/item=ID'), /\{\{\w+\}\}/.test(systemPrompt(null, {}, wow).replace(/\{\{string:[^}]*\}\}/g, ''))], [true, true, false]);
  // two versions installed: the one played last, its own data, its own answers
  const root = path.resolve('fakewow/_root');
  for (const [name, at] of [['_retail_', 1000], ['_classic_era_', 2000], ['_forever_', 500]]) {
    const dir = path.join(root, name);
    fs.mkdirSync(path.join(dir, 'WTF/Account/A/SavedVariables'), { recursive: true });
    fs.mkdirSync(path.join(dir, 'Screenshots'), { recursive: true });
    if (name !== '_forever_') {
      fs.mkdirSync(path.join(dir, 'Interface/AddOns/claude-in-wow'), { recursive: true });
      fs.writeFileSync(path.join(dir, 'Interface/AddOns/claude-in-wow/claude-in-wow.toc'), '## Title: x');
    }
    const file = path.join(dir, 'WTF/Account/A/SavedVariables/claude-in-wow.lua');
    fs.writeFileSync(file, `ClaudeInWoWDB = {\n["game"] = {\n["flavor"] = "${name === '_retail_' ? 'retail' : 'era'}",\n},\n}\n`);
    for (const each of [file, path.join(dir, 'Screenshots')]) fs.utimesSync(each, at, at);
  }
  const kept = process.env.CIW_WOW_DIR;
  delete process.env.CIW_WOW_DIR;
  process.env.CIW_WOW_ROOT = root;
  const game = await import(pathToFileURL(path.join(pluginDir, 'server/game.mjs')));
  ok('versions: all found, those with the addon served', [game.findGames().length, game.servedGames().map((dir) => path.basename(dir)).sort()], [3, ['_classic_era_', '_retail_']]);
  ok('versions: the one played last, and each one\'s data', [path.basename(game.findWowDir()), game.loadData().db.game.flavor, game.loadData(path.join(root, '_retail_')).db.game.flavor], ['_classic_era_', 'era', 'retail']);
  delete process.env.CIW_WOW_ROOT;
  if (kept) process.env.CIW_WOW_DIR = kept;
  fs.rmSync(root, { recursive: true });
}
ok('modules: the places of the game', systemPrompt(null, { places: [{ name: 'Scholomance', map: 1422 }] }).includes('Scholomance=1422'), true);
const started = last().args, systemAt = option(last(), '--system-prompt-file');
ok('silent mode: these tools alone, the modules as instructions', [started.includes('--strict-mcp-config'), option(last(), '--tools'), started.includes('--disable-slash-commands'), fs.readFileSync(systemAt, 'utf8').includes('My own words.'),
  Object.keys(JSON.parse(fs.readFileSync(option(last(), '--mcp-config'), 'utf8')).mcpServers)], [true, 'WebSearch,WebFetch,Read,Grep,Glob', true, false, ['claude-in-wow']]);
fs.rmSync(path.resolve('fakewow/modules'), { recursive: true });
// the questions proposed: those on the subject of the player's or of the answer
const { keepRelated } = await import(pathToFileURL(path.join(pluginDir, 'server/questions.mjs')));
const fence = '```';
const proposed = (lines) => `Voilà, Shaderz vend ses enchantements.\n\n${fence}\n[claude-in-wow] questions\n${lines.join('\n')}\n${fence}`;
ok('questions proposed: about something else, left out with their block', keepRelated(proposed(['Où est ma pierre de foyer ?']), 'pourquoi les gens font MOOO dans le chat ?'), { text: 'Voilà, Shaderz vend ses enchantements.', dropped: ['Où est ma pierre de foyer ?'] });
ok('questions proposed: on the player\'s subject or the answer\'s, five at most', keepRelated(proposed(['Qui est dans mon groupe ? | topics groups', 'Où est ma pierre de foyer ?', 'Quels groupes cherchent un mage ?', 'Et le groupe de Lazarok ?', 'Combien coûte un enchantement ?', 'Que vend Shaderz ?', 'Un groupe de plus ?']), 'Qui est en groupe maintenant ?').text,
  proposed(['Qui est dans mon groupe ? | topics groups', 'Quels groupes cherchent un mage ?', 'Et le groupe de Lazarok ?', 'Combien coûte un enchantement ?', 'Que vend Shaderz ?']));
ok('questions proposed: not one already asked, nor twice the same', keepRelated(proposed(['Quels groupes cherchent un mage ?', 'Que vend Shaderz ?', 'que vend Shaderz | topics chat']), 'Qui est en groupe ?', ['quels groupes cherchent un MAGE ?']).dropped, ['Quels groupes cherchent un mage ?', 'que vend Shaderz']);
ok('questions proposed: accents, capitals and plurals do not matter', keepRelated(proposed(['Combien coûtent les Réparations ? | read GetRepairAllCost()']), 'combien coute ma reparation').dropped, []);
ok('questions proposed: what is to be read, as the addon takes it', keepRelated(proposed(['Que vend Shaderz ? | chat', 'Shaderz est de la guilde ? | prices', 'Où est Shaderz ? | topics guild, quests', 'Le sac de Shaderz ? | read GetBindLocation()']), 'x').text, proposed(['Que vend Shaderz ? | topics chat', 'Shaderz est de la guilde ?', 'Où est Shaderz ? | topics guild', 'Le sac de Shaderz ? | read GetBindLocation()']));
const { fenced, readLines } = await import(pathToFileURL(path.join(pluginDir, 'server/questions.mjs')));
ok('a block without its fence: put in one', fenced('Voilà.\n\n[claude-in-wow] questions\nQue vend Shaderz ?\n\n[claude-in-wow] boutons\ninviter Merrin'), `Voilà.\n\n${fence}\n[claude-in-wow] questions\nQue vend Shaderz ?\n${fence}\n\n${fence}\n[claude-in-wow] boutons\ninviter Merrin\n${fence}`);
ok('questions under a heading: their block', fenced('Voilà.\n\n**Questions suivantes**\nQue vend Shaderz ?\n- Où est Lard ? | topics chat'), `Voilà.\n\n${fence}\n[claude-in-wow] questions\nQue vend Shaderz ?\nOù est Lard ? | topics chat\n${fence}`);
ok('a heading that is not one: left', fenced('Les questions suivantes\n\nsont posées.'), 'Les questions suivantes\n\nsont posées.');
ok('a block with its fence: left', fenced(proposed(['Que vend Shaderz ?'])), proposed(['Que vend Shaderz ?']));
ok('an older addon: no blocks it does not know', [readLines({}).join(' '), readLines({ options: { blocks: ['route', 'why'] } }).join(' '), readLines({ options: { blocks: ['route', 'why'], off: ['route'] } }).join(' ')],
  [' Their addon is older: no route block; no why block.', '', " The player's limits: no route block."]);
ok('a route and how it was found, without their fences: put in some', fenced('Par là.\n\n[claude-in-wow] route Scholomance\n1422:69.7:73.2 | Entre\n\n[claude-in-wow] why\nTon journal.').match(/```/g).length, 4);
ok('questions proposed: the other blocks untouched', keepRelated(`A\n\n${fence}\n[claude-in-wow] boutons\ninviter Merrin\n${fence}`, 'merci').text.includes('inviter Merrin'), true);
// the functions that only read
const found = (await silentServer.call('game_functions', { search: 'faction index' })).data;
ok('game functions: found by what they are about, with what they give', [found.functions.some((f) => f.function === 'C_Reputation.GetFactionDataByIndex(factionSortIndex:luaIndex)' && f.structures.FactionData.includes('currentStanding'))], [true]);
ok('game functions: none that acts', [(await silentServer.call('game_functions', { search: 'CancelCommoditiesPurchase' })).data.found, (await silentServer.call('game_functions', { search: 'InviteUnit' })).data.found, (await silentServer.call('game_functions', { search: 'GetQuestReward' })).data.functions.filter((f) => f.function.startsWith('GetQuestReward(')).length], [0, 0, 0]);
// as many slots as the player picks, made and taken away, none but ours
const slotDirs = () => fs.readdirSync(addonsDir).filter((name) => /^claude-in-wow_S\d+$/.test(name)).sort();
fs.writeFileSync(path.join(addonsDir, 'claude-in-wow', 'claude-in-wow.toc'), '## Title: claude-in-wow\n');
const { setSlots } = await import(pathToFileURL(path.join(pluginDir, 'server/slots.mjs')));
for (const name of slotDirs()) fs.rmSync(path.join(addonsDir, name), { recursive: true });
ok('slots: made', [setSlots(wow, 12), slotDirs().length, slotDirs()[11], fs.readFileSync(path.join(addonsDir, 'claude-in-wow_S012', 'claude-in-wow_S012.toc'), 'utf8').includes('## LoadOnDemand: 1\n')], [{ made: 12, removed: 0 }, 12, 'claude-in-wow_S012', true]);
fs.mkdirSync(path.join(addonsDir, 'claude-in-wow_S020'));
fs.writeFileSync(path.join(addonsDir, 'claude-in-wow_S020', 'autre.lua'), '-- not ours');
fs.writeFileSync(path.join(addonsDir, 'claude-in-wow_S011', 'note.txt'), 'put there by the player');
ok('slots: taken away, but for folders with anything else in them', [setSlots(wow, 10), slotDirs().slice(10)], [{ made: 0, removed: 1 }, ['claude-in-wow_S011', 'claude-in-wow_S020']]);
ok('slots: a number out of bounds changes nothing', [setSlots(wow, -1), setSlots(wow, 5000), setSlots(wow, '30'), setSlots(wow, undefined), slotDirs().length], [{ made: 0, removed: 0 }, { made: 0, removed: 0 }, { made: 0, removed: 0 }, { made: 0, removed: 0 }, 12]);
const t22 = ask({ at: askedAt + 220, text: 'Vingt ?', options: { slots: 20 } });
ok('silent mode: the slots follow the player\'s choice', [await waitFor(() => clipboardText().includes(`réponse ${t22.at} `)), slotDirs().length], [true, 20]);
const t23 = ask({ at: askedAt + 230, text: 'Sans mini-addons ?', options: { slots: 0 } });
ok('silent mode: none when the answers do not come by themselves', [await waitFor(() => clipboardText().includes(`réponse ${t23.at} `)), slotDirs()], [true, ['claude-in-wow_S011', 'claude-in-wow_S020']]);
for (const name of slotDirs()) fs.rmSync(path.join(addonsDir, name), { recursive: true });
fs.rmSync(path.join(addonsDir, 'claude-in-wow', 'claude-in-wow.toc'));
ok('slots: none made without the addon', [setSlots(wow, 30), slotDirs().length], [{ made: 0, removed: 0 }, 0]);
{
  const { failureText, failureKind } = await import(pathToFileURL(path.join(pluginDir, 'server/messages.mjs')).href);
  ok('messages: why there is no answer', ['spawn claude ENOENT', 'Invalid API key · Please run /login', 'You have hit your limit', 'no answer in time', 'exit 3'].map(failureKind), ['notFound', 'signIn', 'limit', 'late', 'other']);
  ok('messages: English at first, French for a French game', [failureText('exit 3').split('\n')[0], failureText('exit 3', 'koKR').split('\n')[0], failureText('spawn claude ENOENT', 'frFR').split('\n')[0]],
    ['*Claude could not answer: exit 3.*', '*Claude could not answer: exit 3.*', "*Claude n'a pas pu répondre : Claude Code est introuvable sur cet ordinateur.*"]);
  const { languages, say } = await import(pathToFileURL(path.join(pluginDir, 'server/messages.mjs')).href);
  const texts = (code) => JSON.parse(fs.readFileSync(path.join(pluginDir, 'server/locales', `${code}.json`), 'utf8'));
  const parts = (text) => (text.match(/\{\w+\}/g) || []).sort().join();
  const { setSlots } = await import(pathToFileURL(path.join(pluginDir, 'server/slots.mjs')).href);
  const other = path.resolve('fakewow/slots');
  fs.mkdirSync(path.join(other, 'Interface/AddOns/claude-in-wow'), { recursive: true });
  fs.writeFileSync(path.join(other, 'Interface/AddOns/claude-in-wow/claude-in-wow.toc'), '');
  setSlots(other, 1);
  const slotToc = fs.readFileSync(path.join(other, 'Interface/AddOns/claude-in-wow_S001/claude-in-wow_S001.toc'), 'utf8');
  ok('messages: the languages, each with every text and its parts', languages().map((code) => [code, Object.keys(texts('en')).filter((name) => parts(texts(code)[name] || '') !== parts(texts('en')[name]) || !texts(code)[name]).length, Object.keys(texts(code)).length]),
    ['de', 'es', 'fr', 'it'].map((code) => [code, 0, Object.keys(texts('en')).length]));
  ok('messages: a game\'s language, English where there is none', [say('esMX', 'slotTitle', { number: '007' }), say('ptBR', 'slotTitle', { number: '007' }), say(null, 'nothing')], ['claude-in-wow - respuesta 007', 'claude-in-wow - answer 007', 'nothing']);
  const { languageCode } = await import(pathToFileURL(path.join(pluginDir, 'server/language.mjs')).href);
  ok('language: by its code or its name', ['fr-FR', 'Français', 'spanish', 'de', 'klingon', undefined].map(languageCode), ['fr', 'fr', 'es', 'de', null, null]);
  ok('messages: the answers\' addons in each language', slotToc.match(/## Title-(\w+)/g).join(' '), '## Title-deDE ## Title-esES ## Title-esMX ## Title-frFR ## Title-itIT');
  ok('silent mode: the player wants it', JSON.parse(fs.readFileSync(path.resolve('fakewow/claude-in-wow-silent.json'), 'utf8')).wanted, true);
  if (process.platform === 'win32') {
    const vbs = path.resolve('fakewow/startup/claude-in-wow.vbs');
    fs.mkdirSync(path.dirname(vbs), { recursive: true });
    ok('autostart: on', [(await silentServer.call('silent_mode', { action: 'autostart', folder: path.resolve('fakewow') })).data.autostart, fs.readFileSync(vbs, 'utf16le').includes('start.mjs""", 0, False'), JSON.parse(fs.readFileSync(path.resolve('fakewow/home/autostart.json'), 'utf8')).dir], [true, true, path.resolve('fakewow')]);
    ok('autostart: off', [(await silentServer.call('silent_mode', { action: 'no_autostart' })).data.autostart, fs.existsSync(vbs)], [false, false]);
  }
}
ok('silent mode: stopped', (await silentServer.call('silent_mode', { action: 'stop' })).data.stopped, true);
ok('silent mode: no longer running', (await silentServer.call('silent_mode', { action: 'status' })).data.running, false);
ok('silent mode: stopped by the player, not to be started again', JSON.parse(fs.readFileSync(path.resolve('fakewow/claude-in-wow-silent.json'), 'utf8')).wanted, false);
{ // a question asked while it was not running; started again by itself when it was not stopped
  const missed = { id: askedAt + 300, at: askedAt + 300, kind: 'free', text: 'Pendant son absence ?' };
  questionPhoto(path.join(shotsDir, 'WoWScrnShot_missed.png'), missed);
  const stateFile = path.resolve('fakewow/claude-in-wow-silent.json');
  fs.writeFileSync(stateFile, JSON.stringify({ ...JSON.parse(fs.readFileSync(stateFile, 'utf8')), wanted: true, pid: 999999 }));
  const again = startServer(wow);
  await again.request('initialize', { protocolVersion: '2025-06-18' });
  ok('silent mode: started again with the tools, answers what it missed', await waitFor(() => clipboardText().includes('Pendant son absence')), true);
  await again.call('silent_mode', { action: 'stop' });
  again.server.stdin.end();
  ok('silent mode: stopped for good', JSON.parse(fs.readFileSync(stateFile, 'utf8')).wanted, false);
}
silentServer.server.stdin.end();
silentFiles.forEach((file) => fs.rmSync(file));

// A reload after the photo: the snapshot is newer, the photo goes
const sv = path.join(wow, 'WTF/Account/TEST/SavedVariables/claude-in-wow.lua');
fs.writeFileSync(sv, fs.readFileSync(sv, 'utf8').replace(/\["savedAt"\] = (\d+)/g, (_, t) => `["savedAt"] = ${Number(t) + 600}`));
const reloaded = startServer(wow);
await reloaded.request('initialize', { protocolVersion: '2025-06-18' });
const after = await reloaded.call('game_state');
ok('reload after the photo: the snapshot again, the photo of a question just sent kept for its answer', [after.data.snapshot.by, after.data.money, pageFiles.some((f) => fs.existsSync(f))], ['reload or logout', '123g 45s 67c', true]);
reloaded.server.stdin.end();

// Without the addon's data: the game tools say so, the others still work
fs.renameSync(path.join(wow, 'WTF/Account/TEST/SavedVariables/claude-in-wow.lua'), path.join(wow, 'WTF/Account/TEST/SavedVariables/claude-in-wow.lua.off'));
const bare = startServer(wow);
await bare.request('initialize', { protocolVersion: '2025-06-18' });
const noData = await bare.call('game_state');
ok('no addon data: says to install it', [noData.isError, noData.raw.includes('claude-in-wow')], [true, true]);
ok('no addon data: addons still listed', (await bare.call('addons')).data.installed, 4);
bare.server.stdin.end();

// The player's real install (read only): Questie's database and GatherMate2
if (realSV && withAddons) {
  const real = startServer(path.resolve(realSV, '../../../..'));
  await real.request('initialize', { protocolVersion: '2025-06-18' });
  const q7 = await real.call('quest_info', { query: '7' });
  ok('real: quest 7 in French, its giver and where', [q7.data.name, q7.data.startedBy[0].name, q7.data.startedBy[0].where[0].zone, q7.data.startedBy[0].where[0].coords[0], q7.data.kill[0].name],
    ['Nettoyer le camp des kobolds', 'Maréchal McBride', "Forêt d'Elwynn", '48.9 41.6', 'Vermine kobold']);
  const lard = await real.call('quest_info', { query: '7840' });
  ok('real: the game\'s map of each place, for links', [q7.data.startedBy[0].where[0].uiMapID, lard.data.startedBy[0].where[0].uiMapID], [1429, 1425]);
  const rot = await real.call('quest_info', { query: 'pourriture et regret' });
  ok('real: a Forever quest by its French name', [rot.data.id, rot.data.nameEnglish, rot.data.nextQuest.name], [93404, 'Rot and Regret', 'Passer le blâme']);
  ok('real: several matches', (await real.call('quest_info', { query: 'kobold' })).data.matches.length > 1, true);
  const npc = await real.call('npc_info', { query: 'Grippe-charogne' });
  ok('real: an instance boss', [npc.data.nameEnglish, npc.data.rank, npc.data.where[0].zone, npc.data.where[0].coords], ['Rotgrip', 'elite', 'Maraudon', ['inside the instance']]);
  const ore = await real.call('item_info', { query: '2770' });
  ok('real: an item and its nodes', [ore.data.name, ore.data.fromObjects.some((o) => o.name === 'Filon de cuivre')], ['Minerai de cuivre', true]);
  const parchment = await real.call('item_info', { query: '9323' });
  ok('real: an item that comes with a quest', [parchment.data.usedFor[0].id, parchment.data.usedFor[0].role, typeof parchment.data.usedFor[0].handedIn], [2937, 'comes with the quest', 'boolean']);
  const instructions = await real.call('item_info', { query: '17781' });
  ok('real: its quest handed in', [instructions.data.usedFor[0].id, instructions.data.usedFor[0].handedIn], [7067, true]);
  const chalice = await real.call('item_info', { query: '19071' });
  ok('real: an item to collect', [chalice.data.usedFor[0].id, chalice.data.usedFor[0].role], [7850, 'to collect']);
  ok('real: GatherMate2 summary', (await real.call('gathering')).data.recorded > 0, true);
  real.server.stdin.end();
}

// The parser on the player's real SavedVariables files (read only)
if (realSV) {
  const { parseSavedVariables } = await import(pathToFileURL(path.join(pluginDir, 'server/savedvars.mjs')));
  let files = 0, bad = [];
  for (const name of fs.readdirSync(realSV).filter((n) => n.endsWith('.lua'))) {
    files++;
    try { parseSavedVariables(fs.readFileSync(path.join(realSV, name))); } catch (err) { bad.push(`${name}: ${err.message}`); }
  }
  ok(`real files parsed (${files})`, bad, []);
}

console.log(`${passed} passed, ${failed} failed`);
