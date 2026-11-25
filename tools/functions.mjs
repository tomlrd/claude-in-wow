// Makes the list of the game's functions that only read, from Blizzard's own
// documentation of WoW Forever (the wow-ui-source mirror, branch "forever",
// Interface/AddOns/Blizzard_APIDocumentationGenerated): for the addon
// (Functions.lua: what Claude may have read, and nothing else) and for the
// plugin (data/functions.json: their arguments and what they give).
// A function reads when its name says so (Get, Is, Has, Can, Does...) and the
// documentation puts no restriction on it; those about the account, the shop,
// Battle.net friends or the voice chat are left out, and the few whose name
// hides an action. Some the documentation lacks are added by hand.
// node functions.mjs <documentation folder> <addon folder> <plugin folder>

import fs from 'node:fs';
import path from 'node:path';

const [docs, addon, plugin] = process.argv.slice(2);
if (!docs || !addon || !plugin) throw new Error('usage: node functions.mjs <documentation folder> <addon folder> <plugin folder>');

const READS = /^(Get|Is|Has|Can|Does|Are|Should|Find|Unit|Player(Has|Is|Get|Can)|Num)(?=[A-Z0-9]|$)/;
// names that start like a reading and are not one, or do more than read
const ACTS = /^GetWeeklyReward$|RestrictedAccount|AccountSecured|TrialAccount|ChatLine|^(GetQuestReward$|GetGuildRosterInfo$|GetMessageInfo|GetMessagesBefore|GetMessageRanges|GetMOTD|UnitSet|UnitSwitch|UnitPopup|GetNewAutoQuestPopUp|GetAccountExpansion|GetSessionTime|FindAndPlay|UnitMassDispell|GetText$|GetCVarInfo|GetCVarBitfield|GetCVarDefault)/;
const LEFT_OUT = /^C_(PhotoSharing|ExternalEventURL|ConsoleScriptCollection|System|Glue|LobbyMatchmakerInfo|ScriptedAnimations|AccountInfo|AccountStore|BattleNet|Battle|StoreSecure|StoreGlue|PurchaseAPI|WowToken|Login|RealmList|VoiceChat|VoiceChatAlias|Discord|Social|SocialQueue|ReportSystem|RecruitAFriend|GlueParent|CharacterServices|SharedCharacterServices|ClientScene|Commentator|FrameManager|KeyBindings|Secrets|RestrictedActions|WebServices|StorePublic|CatalogShop|ScriptWarnings|Security|PerformanceUI|AddOnProfiler|Trophy|Debug|GameRules|Widget|UIWidget|XMLUtil|CharacterCreation|BarberShop|ConfigurationWarnings|Macro)/;
// the documentation lacks these: they read (not GetGuildRosterInfo: officers' notes)
const BY_HAND = `GetAchievementInfo GetTotalAchievementPoints GetLatestCompletedAchievements GetCategoryInfo GetCategoryList GetCategoryNumAchievements GetAchievementNumCriteria GetAchievementCriteriaInfo GetStatistic
GetGuildInfo GetNumGuildMembers GetGuildRosterLastOnline GetNumSavedInstances GetSavedInstanceInfo GetSavedInstanceEncounterInfo GetInstanceInfo GetDifficultyInfo
GetInventoryItemLink GetInventoryItemID GetInventoryItemDurability GetInventoryItemCooldown GetInventoryItemQuality GetInventorySlotInfo GetAverageItemLevel GetItemGem
GetMacroInfo GetNumMacros GetBinding GetBindingKey GetNumBindings GetActionInfo GetActionCooldown GetActionCount GetActionText HasAction IsUsableAction
GetNumGroupMembers GetNumSubgroupMembers GetRaidRosterInfo IsInGroup IsInRaid IsInGuild IsInInstance GetLootMethod GetPartyAssignment
GetMerchantNumItems GetMerchantItemLink GetMerchantItemMaxStack GetNumBuybackItems GetRepairAllCost CanMerchantRepair
GetNumTrainerServices GetTrainerServiceInfo GetTrainerServiceCost GetTrainerServiceLevelReq GetTrainerServiceSkillReq GetTrainerServiceDescription
GetInboxNumItems GetInboxHeaderInfo GetInboxItem HasNewMail GetLatestThreeSenders
GetMoney GetXPExhaustion GetRestState UnitXP UnitXPMax IsResting GetZoneText GetRealZoneText GetSubZoneText GetMinimapZoneText GetBindLocation
GetCombatRating GetCombatRatingBonus GetSpellBonusDamage GetSpellBonusHealing GetSpellCritChance GetCritChance GetRangedCritChance GetHitModifier GetSpellHitModifier GetHaste GetMeleeHaste GetManaRegen GetPowerRegen GetDodgeChance GetParryChance GetBlockChance GetShieldBlock GetSpellPenetration GetExpertise
GetTime GetServerTime GetGameTime GetBuildInfo GetLocale GetFramerate GetNetStats GetPlayerFacing GetUnitSpeed IsFlying IsMounted IsSwimming IsFalling IsStealthed IsIndoors IsOutdoors
GetNumLootItems GetLootSlotInfo GetLootSlotLink GetPetActionInfo GetPetExperience GetPetHappiness HasPetUI GetShapeshiftForm GetShapeshiftFormInfo GetNumShapeshiftForms GetTotemInfo GetWeaponEnchantInfo
NumTaxiNodes TaxiNodeName TaxiNodeCost TaxiNodeGetType GetLFGQueueStats GetLFGDungeonInfo GetBattlefieldStatus GetPVPLifetimeStats GetPVPSessionStats GetPVPRankInfo GetPVPRankProgress UnitPVPRank UnitHonor UnitHonorMax UnitHonorLevel
GetNumSkillLines GetSkillLineInfo GetNumFactions GetFactionInfo GetNumTalentTabs GetTalentTabInfo GetNumTalents GetTalentInfo GetUnspentTalentPoints GetNumTitles GetTitleName GetCurrentTitle IsTitleKnown
GetNumAuctionItems GetAuctionItemInfo GetNumWhoResults GetMirrorTimerInfo GetPlayerInfoByGUID GetNumQuestChoices GetQuestItemInfo GetNumQuestRewards GetRewardMoney GetRewardXP GetQuestID GetTitleText GetGossipText GetQuestText GetObjectiveText GetProgressText GetRewardText
UnitName UnitLevel UnitClass UnitRace UnitSex UnitExists UnitHealth UnitHealthMax UnitPower UnitPowerMax UnitGUID UnitFactionGroup UnitIsPlayer UnitIsDead UnitClassification UnitCreatureType UnitCreatureFamily UnitReaction UnitStat UnitArmor UnitDamage UnitAttackPower UnitAttackSpeed UnitRangedDamage UnitResistance UnitDefense`.split(/\s+/);

// ------------------------------------------------- reading the documentation

const fields = (block) => [...block.matchAll(/\{ Name = "([^"]+)", Type = "([^"]+)"([^}]*)\}/g)].map(([, name, type, rest]) => {
  const inner = /InnerType = "([^"]+)"/.exec(rest)?.[1] || /Mixin = "([^"]+)"/.exec(rest)?.[1];
  const kind = type === 'table' ? (inner ? `${inner}[]` : 'table') : type;
  return `${name}:${kind}${/Nilable = true/.test(rest) ? '?' : ''}`;
});

// The text of a list field of an entry, "Arguments =\n{ ... }".
function list(entry, name) {
  const at = entry.indexOf(`\n\t\t\t${name} =\n\t\t\t{\n`);
  if (at < 0) return '';
  return entry.slice(at, entry.indexOf('\n\t\t\t},', at));
}

const functions = new Map(); // "C_Name.Function" -> { args, gives }
const structures = new Map();
for (const file of fs.readdirSync(docs).filter((name) => name.endsWith('.lua'))) {
  const text = fs.readFileSync(path.join(docs, file), 'utf8').replace(/\r/g, '');
  const head = text.slice(0, text.indexOf('\n\tFunctions ='));
  const namespace = /\n\tNamespace = "([^"]+)"/.exec(head)?.[1] || '';
  const system = /\n\tType = "System"/.test(head);
  for (const entry of text.split(/\n\t\t\{\n/).slice(1)) {
    const name = /^\t\t\tName = "([^"]+)"/.exec(entry)?.[1];
    const type = /\n\t\t\tType = "([^"]+)"/.exec(entry)?.[1];
    if (type === 'Structure') structures.set(name, fields(list(entry, 'Fields')));
    if (type !== 'Function' || !system || !name) continue;
    if (!READS.test(name) || ACTS.test(name) || LEFT_OUT.test(namespace)) continue;
    if (/HasRestrictions = true|IsProtectedFunction = true/.test(entry)) continue;
    functions.set(namespace ? `${namespace}.${name}` : name, { args: fields(list(entry, 'Arguments')), gives: fields(list(entry, 'Returns')) });
  }
}
for (const name of BY_HAND) if (!functions.has(name) && !ACTS.test(name)) functions.set(name, { args: null, gives: null });

// ------------------------------------------------- the two lists

const names = [...functions.keys()].sort();
const groups = new Map();
for (const name of names) {
  const [space, own] = name.includes('.') ? name.split('.') : ['', name];
  if (!groups.has(space)) groups.set(space, []);
  groups.get(space).push(own);
}
const wrap = (words) => {
  const lines = [''];
  for (const word of words) {
    if (lines[lines.length - 1].length + word.length > 150) lines.push('');
    lines[lines.length - 1] += `${word} `;
  }
  return lines.map((line) => `        ${line.trimEnd()}`).join('\n');
};
const lua = `-- claude-in-wow: the game's functions that only read, the only ones Claude
-- may have called (Reads.lua). Made from Blizzard's documentation of WoW
-- Forever by the plugin's tools\\functions.mjs: not to be edited by hand.

local addonName, ns = ...

ns.FUNCTIONS = {
${[...groups].map(([space, own]) => `    [${JSON.stringify(space)}] = [[\n${wrap(own)}\n    ]],`).join('\n')}
}
`;
fs.writeFileSync(path.join(addon, 'Data', 'Functions.lua'), lua);

// the structures the functions give, and those in them
const used = {};
const use = (kinds) => {
  for (const field of kinds || []) {
    const kind = field.split(':')[1].replace(/\[\]|\?/g, '');
    if (!structures.has(kind) || used[kind]) continue;
    used[kind] = structures.get(kind);
    use(used[kind]);
  }
};
for (const { gives } of functions.values()) use(gives);
fs.mkdirSync(path.join(plugin, 'data'), { recursive: true });
fs.writeFileSync(path.join(plugin, 'data', 'functions.json'), JSON.stringify({
  functions: Object.fromEntries(names.map((name) => [name, functions.get(name).args ? [functions.get(name).args.join(', '), functions.get(name).gives.join(', ')] : null])),
  structures: Object.fromEntries(Object.entries(used).map(([name, list]) => [name, list.join(', ')])),
}));
console.log(`${names.length} functions, ${Object.keys(used).length} structures, ${groups.size} groups`);
