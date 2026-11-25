// The versions of the game: their folders in a World of Warcraft install, what
// Claude is told of each, and where the web speaks of them.

import path from 'node:path';

// wowhead: its databases to search, the version's own first. tocs: the endings of
// the .toc files that version loads before the plain one.
export const FLAVORS = {
  retail: {
    title: 'World of Warcraft (Retail)',
    about: 'the current game: its newest expansion, and all the older ones\' content',
    search: 'World of Warcraft', wowhead: [''], tocs: ['_Mainline'],
  },
  mop: {
    title: 'World of Warcraft: Mists of Pandaria Classic',
    about: 'the progression Classic realms, now in Mists of Pandaria',
    search: 'WoW Mists of Pandaria Classic', wowhead: ['/mop-classic'], tocs: ['_Mists', '_Classic'],
  },
  cata: {
    title: 'World of Warcraft: Cataclysm Classic',
    about: 'the progression Classic realms, in Cataclysm',
    search: 'WoW Cataclysm Classic', wowhead: ['/cata'], tocs: ['_Cata', '_Classic'],
  },
  wrath: {
    title: 'World of Warcraft: Wrath of the Lich King Classic',
    about: 'Wrath of the Lich King, on a modern client',
    search: 'WoW Wrath of the Lich King Classic', wowhead: ['/wotlk'], tocs: ['_Wrath', '_Classic'],
  },
  tbc: {
    title: 'World of Warcraft: Burning Crusade Classic',
    about: 'the Anniversary realms, in the Burning Crusade',
    search: 'WoW Burning Crusade Classic', wowhead: ['/tbc'], tocs: ['_TBC', '_BCC', '_Classic'],
  },
  forever: {
    title: 'World of Warcraft Forever',
    about: 'Blizzard\'s classic-era content on a modern client, with Forever\'s own changes and additions (zones, quests with numbers above 90000); characters have first and last names, there are no realms, and some names stay in English on another client',
    search: 'World of Warcraft Forever', wowhead: ['/forever', '/classic'], tocs: ['_Forever', '-Forever', '_Camelot', '-Camelot'],
  },
  era: {
    title: 'World of Warcraft Classic',
    about: 'Classic Era, as in 2004-2006 (also Hardcore and Season of Discovery realms)',
    search: 'WoW Classic', wowhead: ['/classic'], tocs: ['_Vanilla', '_Classic'],
  },
};

// The folders of an install; the same version also has its test realms.
const FOLDERS = [
  [/^_(forever)/, 'forever'], [/^_classic_era/, 'era'], [/^_(anniversary|classic_anniversary)/, 'tbc'], [/^_(classic_titan|titan)/, 'wrath'],
  [/^_classic/, 'mop'], [/^_(retail|ptr|xptr|beta|event)/, 'retail'],
];

// A game's version, by what the addon noted of it (db.game), else by its folder.
export function flavorOf(wowDir, db) {
  const told = db?.game?.flavor;
  const key = FLAVORS[told] ? told : FOLDERS.find(([name]) => name.test(path.basename(wowDir || '')))?.[1] || 'retail';
  return { key, ...FLAVORS[key] };
}

const SITES = { fr: 'fr', de: 'de', es: 'es', pt: 'pt', it: 'it', ru: 'ru', ko: 'ko', zh: 'cn' };

// Wowhead's pages for a version, in English then in the client's language:
// groups, each tried when the one before has nothing.
export function wowheadSites(flavor, locale) {
  const language = SITES[String(locale || '').slice(0, 2).toLowerCase()];
  return flavor.wowhead.map((place) => {
    const base = `https://www.wowhead.com${place}`;
    return language ? [base, `${base}/${language}`] : [base];
  });
}
