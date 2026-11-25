// Auction house prices from the TradeSkillMaster desktop app's data, which it
// refreshes in TradeSkillMaster_AppHelper\AppData.lua. Each table is
// LoadData("NAME","Realm",[[return {downloadTime=..,fields={..},data={{..}}}]])
// with the item ID first and every value in copper as base-32 digits (0-9A-V).

import fs from 'node:fs';
import path from 'node:path';

const TABLE = /LoadData\("([A-Z_]+)","([^"]+)",\[\[return \{downloadTime=(\d+),fields=\{([^}]*)\},data=\{([\s\S]*?)\}\}\]\]\)/g;

let cache = null;

export function pricesFile(wowDir) {
  return path.join(wowDir, 'Interface', 'AddOns', 'TradeSkillMaster_AppHelper', 'AppData.lua');
}

// { tables: { NAME: { realm, downloadTime, rows: Map(itemString -> row) } } } or null.
export function loadPrices(wowDir) {
  const file = pricesFile(wowDir);
  let stat;
  try { stat = fs.statSync(file); } catch { return null; }
  if (cache && cache.file === file && cache.mtimeMs === stat.mtimeMs) return cache;

  const src = fs.readFileSync(file, 'latin1');
  const tables = {};
  for (const m of src.matchAll(TABLE)) {
    const fields = m[4].split(',').map((f) => f.replace(/"/g, '').trim());
    const rows = new Map();
    for (const row of m[5].matchAll(/\{([^{}]*)\}/g)) {
      const cells = row[1].split(',');
      const entry = {};
      fields.forEach((field, i) => {
        entry[field] = i === 0 ? cells[0].replace(/"/g, '') : parseInt(cells[i], 32);
      });
      rows.set(String(entry.itemString), entry);
    }
    tables[m[1]] = { realm: m[2], downloadTime: Number(m[3]), rows };
  }
  cache = { file, mtimeMs: stat.mtimeMs, tables };
  return cache;
}

function money(copper) {
  if (typeof copper !== 'number' || Number.isNaN(copper)) return undefined;
  const g = Math.floor(copper / 10000);
  const s = Math.floor(copper / 100) % 100;
  const c = copper % 100;
  return [g && `${g}g`, (g || s) && `${s}s`, `${c}c`].filter(Boolean).join(' ');
}

// What the data says about one item, or null.
export function priceOf(prices, itemID) {
  const row = (name) => prices.tables[name]?.rows.get(String(itemID)) || prices.tables[name]?.rows.get(`i:${itemID}`);
  const stat = row('AUCTIONDB_REGION_STAT');
  const sale = row('AUCTIONDB_REGION_SALE');
  const house = row('AUCTIONDB_NON_COMMODITY_DATA');
  const scan = row('AUCTIONDB_NON_COMMODITY_SCAN_STAT');
  if (!stat && !sale && !house && !scan) return null;
  return {
    regionMarketValue: money(stat?.regionMarketValue),
    regionAverageSale: money(sale?.regionSale),
    regionSoldPerDay: sale ? Math.round(sale.regionSoldPerDay / 10) / 100 : undefined,
    auctionHouse: house ? {
      realm: prices.tables.AUCTIONDB_NON_COMMODITY_DATA.realm,
      lowestBuyout: money(house.minBuyout),
      auctions: house.numAuctions,
      recentMarketValue: money(house.marketValueRecent),
      marketValue: money(scan?.marketValue),
    } : undefined,
  };
}

export function pricesAge(prices) {
  const times = Object.values(prices.tables).map((t) => t.downloadTime);
  return times.length ? Math.max(...times) : undefined;
}
