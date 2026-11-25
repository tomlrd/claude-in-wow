// Auction house prices, from the TradeSkillMaster desktop app's data.

import { characters, fold, loadData } from './game.mjs';
import { loadPrices, priceOf, pricesAge } from './prices.mjs';
import { when } from './util.mjs';

// Item names the player's own data knows: bags, bank and equipment of every
// character, and the account bank.
function knownItems(db) {
  const names = new Map(); // folded name -> { id, name }
  const add = (id, name) => { if (id && name) names.set(fold(name), { id: Number(id), name }); };
  for (const { data } of characters(db)) {
    for (const container of [data.bags, data.bank]) {
      for (const [id, item] of Object.entries(container?.items || {})) add(id, item.name);
    }
    for (const item of Object.values(data.equipment || {})) add(item.id, item.name);
  }
  for (const [id, item] of Object.entries(db.warbandBank?.items || {})) add(id, item.name);
  return names;
}

export const PRICE_TOOLS = [
  {
    name: 'prices',
    description: 'Auction house prices from the TradeSkillMaster desktop app\'s data (refreshed when that app runs): region market value, average sale price and how many sell per day (all Forever EU), and for gear the lowest buyout on the Horde auction house. Items by ID, or by name when the player owns one (bags, bank, equipment); for other names, find the ID first (Wowhead).',
    inputSchema: {
      type: 'object',
      properties: {
        items: { type: 'array', items: { type: 'string' }, description: 'Item IDs or names, e.g. ["3858", "Rubis étoilé"].' },
      },
      required: ['items'],
      additionalProperties: false,
    },
    run(args) {
      const data = loadData();
      if (data.error) return data;
      const prices = loadPrices(data.wowDir);
      if (!prices) return { error: 'No TradeSkillMaster price data: the TSM desktop app (with TradeSkillMaster_AppHelper) keeps it up to date.' };
      const known = knownItems(data.db);

      const results = (args.items || []).slice(0, 50).map((asked) => {
        const text = String(asked).trim();
        let item = /^\d+$/.test(text) ? { id: Number(text) } : known.get(fold(text));
        if (!item && !/^\d+$/.test(text)) {
          const q = fold(text);
          item = [...known.values()].find((k) => fold(k.name).includes(q));
        }
        if (!item) return { asked: text, error: 'Unknown name: give its item ID.' };
        const price = priceOf(prices, item.id);
        return { asked: text, id: item.id, name: item.name, ...(price || { note: 'No auction data for this item (not sold on the auction house, or never seen).' }) };
      });
      return { pricesFrom: when(pricesAge(prices)), items: results };
    },
  },
];
