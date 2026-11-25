-- claude-in-wow: what else a question's photo holds, by topic: what the
-- question speaks of (the topic's words), or what Claude proposed to look at in
-- an answer and the player clicked (Buttons.lua). Anything without a topic is
-- read function by function (Reads.lua). Nothing here acts in the game. A topic
-- is { words, read } or, when the game must ask its server first, { words, ask,
-- event, read }: read once the event comes, or three seconds later. A module may
-- add its own (ns.Topic), read while it is on (its module field).

local addonName, ns = ...

local find, format, floor, gsub, ipairs, lower, max, pairs, pcall, select, sort, tostring, type =
    string.find, string.format, math.floor, string.gsub, ipairs, string.lower, math.max, pairs, pcall, select, table.sort, tostring, type

local WAIT = 3         -- seconds for the server
local MAX_TOPICS = 6   -- in one photo
local MAX_READS = 20   -- expressions (Reads.lua)
local MAX_OFFLINE = 60 -- guild members

-- What a function of the game gives, nothing when it fails or is not in this
-- version of the game.
local function Results(ok, ...)
    if ok then return ... end
end

local function Try(fn, ...)
    if type(fn) == "function" then return Results(pcall(fn, ...)) end
end

local function Text(text)
    return text ~= "" and text or nil
end

local function ClassName(classID)
    local info = classID and Try(C_CreatureInfo and C_CreatureInfo.GetClassInfo, classID)
    return info and info.className
end

----------------------------------------------------------------------
-- People
----------------------------------------------------------------------

-- The guild: who is on, where, and who was on last. Officers' notes are left out.
local PRESENCE = { [1] = "online", [2] = "mobile app", [4] = "away", [5] = "busy" } -- Enum.ClubMemberPresence

local function Guild()
    local club = Try(C_Club and C_Club.GetGuildClubId)
    if not club then return { none = true } end
    local name, rank = Try(GetGuildInfo, "player")
    local online, offline, total = {}, {}, 0
    for _, id in ipairs(Try(C_Club.GetClubMembers, club) or {}) do
        local info = Try(C_Club.GetMemberInfo, club, id)
        if info and info.name then
            total = total + 1
            local member = {
                name = info.name, level = info.level, class = ClassName(info.classID), rank = info.guildRank, zone = info.zone,
                note = Text(info.memberNote), professions = info.profession1Name and {
                    { name = info.profession1Name, rank = info.profession1Rank }, { name = info.profession2Name, rank = info.profession2Rank },
                } or nil,
            }
            local status = PRESENCE[info.presence]
            if status then
                member.status, member.me = status, info.isSelf or nil
                online[#online + 1] = member
            else
                member.lastOnlineHours = ((info.lastOnlineYear or 0) * 365 + (info.lastOnlineMonth or 0) * 30 + (info.lastOnlineDay or 0)) * 24
                    + (info.lastOnlineHour or 0)
                offline[#offline + 1] = member
            end
        end
    end
    sort(offline, function(a, b) return a.lastOnlineHours < b.lastOnlineHours end)
    local left = max(0, #offline - MAX_OFFLINE)
    for index = #offline, MAX_OFFLINE + 1, -1 do offline[index] = nil end
    return { name = name, myRank = rank, members = total, online = online, offline = offline, offlineNotListed = left > 0 and left or nil }
end

-- Friends, and the Battle.net ones playing WoW by their character only: no
-- real name, no BattleTag.
local function Friends()
    local friends, battleNet = {}, {}
    for index = 1, Try(C_FriendList and C_FriendList.GetNumFriends) or 0 do
        local info = Try(C_FriendList.GetFriendInfoByIndex, index)
        if info then
            friends[#friends + 1] = {
                name = info.name, level = info.level, class = info.className, zone = Text(info.area), online = info.connected,
                status = info.dnd and "busy" or info.afk and "away" or nil, note = Text(info.notes),
            }
        end
    end
    for index = 1, Try(BNGetNumFriends) or 0 do
        local account = Try(C_BattleNet and C_BattleNet.GetFriendAccountInfo, index)
        local game = account and account.gameAccountInfo
        if game and game.isOnline and game.clientProgram == (BNET_CLIENT_WOW or "WoW") and game.characterName then
            battleNet[#battleNet + 1] = {
                name = game.characterName, level = game.characterLevel, class = game.className, zone = game.areaName,
                faction = game.factionName, playing = game.richPresence,
            }
        end
    end
    return { friends = friends, battleNetInWoW = battleNet }
end

-- The player's own listing in the group finder, and the last search's results.
local function Activity(activityIDs)
    local info = activityIDs and activityIDs[1] and Try(C_LFGList.GetActivityInfoTable, activityIDs[1])
    return info and (info.fullName or info.shortName)
end

local function Groups()
    if not C_LFGList then return { none = true } end
    local entry = Try(C_LFGList.GetActiveEntryInfo)
    local mine = entry and { name = entry.name, comment = Text(entry.comment), activity = Activity(entry.activityIDs) } or nil
    local found = {}
    local total, results = Try(C_LFGList.GetSearchResults)
    for index, id in ipairs(results or {}) do
        if index > 40 then break end
        local info = Try(C_LFGList.GetSearchResultInfo, id)
        if info then
            found[#found + 1] = {
                name = info.name, comment = Text(info.comment), leader = info.leaderName, members = info.numMembers,
                activity = Activity(info.activityIDs), level = info.requiredItemLevel,
            }
        end
    end
    return { mine = mine, lastSearch = { total = total or 0, results = found }, note = "the results are those of the player's last search in the group finder" }
end

----------------------------------------------------------------------
-- The character
----------------------------------------------------------------------

local function Reputations()
    local list, header = {}, nil
    for index = 1, Try(ns.Game.Factions) or 0 do
        local info = Try(ns.Game.Faction, index)
        if info then
            if info.isHeader then header = info.name end
            if info.isHeader and info.isCollapsed then
                list[#list + 1] = { header = info.name, folded = true }
            elseif not info.isHeader or info.isHeaderWithRep then
                list[#list + 1] = {
                    name = info.name, header = header, standing = _G["FACTION_STANDING_LABEL" .. (info.reaction or 0)],
                    value = (info.currentStanding or 0) - (info.currentReactionThreshold or 0),
                    of = (info.nextReactionThreshold or 0) - (info.currentReactionThreshold or 0),
                    atWar = info.atWarWith or nil,
                }
            end
        end
    end
    return { factions = list }
end

local function Currencies()
    local list, header = {}, nil
    for index = 1, Try(ns.Game.Currencies) or 0 do
        local info = Try(ns.Game.Currency, index)
        if info and info.isHeader then
            header = info.name
        elseif info then
            list[#list + 1] = { name = info.name, header = header, quantity = info.quantity, max = (info.maxQuantity or 0) > 0 and info.maxQuantity or nil }
        end
    end
    return { currencies = list }
end

-- The talent trees, each talent with its rank, as the talents window names them.
local function Talents()
    local config = Try(C_ClassTalents and C_ClassTalents.GetActiveConfigID)
        or Try(C_SpecializationInfo and C_SpecializationInfo.GetCombatConfigIDForSpecGroup, Try(C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup) or 1)
    local info = config and Try(C_Traits and C_Traits.GetConfigInfo, config)
    if not info then
        local old = ns.Game.OldTalents()
        return old and { trees = old } or { none = true }
    end
    local trees = {}
    for _, tree in ipairs(info.treeIDs or {}) do
        local names, byName = {}, {}
        for _, display in ipairs(Try(C_Traits.GetGroupDisplayInfoByTreeID, tree) or {}) do names[display.groupID] = display.displayName end
        for _, node in ipairs(Try(C_Traits.GetTreeNodes, tree) or {}) do
            local state = Try(C_Traits.GetNodeInfo, config, node)
            local entryID = state and (state.activeEntry and state.activeEntry.entryID or state.entryIDs and state.entryIDs[1])
            local entry = entryID and Try(C_Traits.GetEntryInfo, config, entryID)
            local definition = entry and entry.definitionID and Try(C_Traits.GetDefinitionInfo, entry.definitionID)
            local name = definition and (Text(definition.overrideName) or definition.spellID and Try(C_Spell and C_Spell.GetSpellName, definition.spellID))
            if name and (state.maxRanks or 0) > 0 then
                local treeName = ""
                for _, group in ipairs(state.groupIDs or {}) do treeName = names[group] or treeName end
                local list = byName[treeName]
                if not list then
                    list = { tree = treeName, points = 0, talents = {} }
                    byName[treeName] = list
                    trees[#trees + 1] = list
                end
                local rank = state.currentRank or state.ranksPurchased or 0
                list.points = list.points + rank
                list.talents[#list.talents + 1] = { name = name, rank = rank, of = state.maxRanks }
            end
        end
    end
    return { active = Try(C_SpecializationInfo and C_SpecializationInfo.GetActiveSpecGroup), trees = trees }
end

local function Spells()
    local old = ns.Game.OldSpells()
    if old then return { spells = old } end
    local list = {}
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    for line = 1, Try(C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) or 0 do
        local info = Try(C_SpellBook.GetSpellBookSkillLineInfo, line)
        if info and not info.shouldHide then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local spell = Try(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                if spell and spell.name and not spell.isOffSpec then
                    list[#list + 1] = { name = spell.name, rank = Text(spell.subName), school = info.name, passive = spell.isPassive or nil }
                end
            end
        end
    end
    return { spells = list }
end

-- What the character's sheet says.
local STATS = { "strength", "agility", "stamina", "intellect", "spirit" }
local SCHOOLS = { [2] = "holy", [3] = "fire", [4] = "nature", [5] = "frost", [6] = "shadow", [7] = "arcane" }

local function Stats()
    local stats = {}
    for index, name in ipairs(STATS) do stats[name] = select(2, Try(UnitStat, "player", index)) end
    local spellPower, spellCrit = {}, {}
    for school, name in pairs(SCHOOLS) do
        spellPower[name], spellCrit[name] = Try(GetSpellBonusDamage, school), Try(GetSpellCritChance, school)
    end
    local base, plus, minus = Try(UnitAttackPower, "player")
    return {
        stats = stats, health = Try(UnitHealthMax, "player"), power = Try(UnitPowerMax, "player"),
        armor = select(2, Try(UnitArmor, "player")), attackPower = ns.Clean(base) and base + (ns.Clean(plus) or 0) + (ns.Clean(minus) or 0) or nil,
        meleeCrit = Try(GetCritChance), hit = Try(GetHitModifier), spellHit = Try(GetSpellHitModifier), haste = Try(GetHaste),
        spellPower = spellPower, spellCrit = spellCrit, healing = Try(GetSpellBonusHealing),
        manaRegen = Try(GetManaRegen), itemLevel = Try(GetAverageItemLevel),
    }
end

-- The recipes of the profession whose window is open.
local function Recipes()
    local old, closed = ns.Game.OldRecipes()
    if old then return old end
    if closed or not Try(C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady) then
        return { closed = true, note = "the game only lists recipes while a profession's window is open: the player opens it, then asks again" }
    end
    local profession = Try(C_TradeSkillUI.GetBaseProfessionInfo)
    local known, unknown = {}, 0
    for _, id in ipairs(Try(C_TradeSkillUI.GetAllRecipeIDs) or {}) do
        local info = Try(C_TradeSkillUI.GetRecipeInfo, id)
        if info and info.learned then
            known[#known + 1] = { name = info.name, id = id, canMake = (info.numAvailable or 0) > 0 and info.numAvailable or nil, difficulty = info.relativeDifficulty }
        elseif info then
            unknown = unknown + 1
        end
    end
    return { profession = profession and profession.professionName, rank = profession and profession.skillLevel, known = known, notKnown = unknown }
end

local function Achievements()
    local points = Try(GetTotalAchievementPoints)
    if not points then return { none = true } end
    local latest = {}
    for _, id in ipairs({ Try(GetLatestCompletedAchievements) }) do
        local _, name, worth, _, month, day, year, text = Try(GetAchievementInfo, id)
        if name then latest[#latest + 1] = { name = name, points = worth, date = year and format("%02d/%02d/%02d", day, month, year), text = text } end
    end
    return { points = points, latest = latest }
end

-- The dungeons and raids the character is saved to.
local function Lockouts()
    local list = {}
    for index = 1, Try(GetNumSavedInstances) or 0 do
        local name, _, reset, _, locked, extended, _, isRaid, players, difficulty, bosses, killed = Try(GetSavedInstanceInfo, index)
        if name then
            list[#list + 1] = {
                name = name, resetsInHours = reset and floor(reset / 360 + 0.5) / 10, locked = locked, extended = extended or nil,
                raid = isRaid or nil, players = players, difficulty = difficulty, bosses = bosses, killed = killed,
            }
        end
    end
    return { instances = list }
end

-- The calendar's next two weeks.
local function Calendar()
    local today = Try(C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime)
    if not today or not C_Calendar then return { none = true } end
    Try(C_Calendar.SetAbsMonth, today.month, today.year)
    local month = Try(C_Calendar.GetMonthInfo, 0)
    local days, list = month and month.numDays or 31, {}
    for ahead = 0, 13 do
        local day, offset = today.monthDay + ahead, 0
        if day > days then day, offset = day - days, 1 end
        for index = 1, Try(C_Calendar.GetNumDayEvents, offset, day) or 0 do
            local event = Try(C_Calendar.GetDayEvent, offset, day, index)
            if event then
                list[#list + 1] = {
                    inDays = ahead, title = event.title, kind = event.calendarType,
                    at = event.startTime and format("%02d:%02d", event.startTime.hour or 0, event.startTime.minute or 0),
                }
            end
        end
    end
    return { events = list }
end

local function Played(total, level)
    if not total then return { none = true } end
    return { hours = floor(total / 360 + 0.5) / 10, hoursThisLevel = level and floor(level / 360 + 0.5) / 10 }
end

----------------------------------------------------------------------
-- The topics: words are patterns, in a text without capitals nor accents
----------------------------------------------------------------------

local TOPICS = {
    guild = { words = { "guilde?s?" }, ask = function() C_GuildInfo.GuildRoster() end, event = "GUILD_ROSTER_UPDATE", read = Guild },
    friends = { words = { "amis?", "amies?", "friends?" }, ask = function() C_FriendList.ShowFriends() end, event = "FRIENDLIST_UPDATE", read = Friends },
    groups = { words = { "recherche de groupe", "cherche un groupe", "group finder", "lfg" }, read = Groups },
    reputations = { words = { "reputations?", "reput" }, read = Reputations },
    currencies = { words = { "monnaies?", "currenc%a+" }, read = Currencies },
    talents = { words = { "talents?" }, read = Talents },
    spells = { words = { "mes sorts", "grimoire", "livre de sorts", "my spells", "spell ?book" }, read = Spells },
    stats = { words = { "stats?", "statistiques?", "caracteristiques?", "attributs?", "puissance des sorts", "spell power", "attributes" }, read = Stats },
    recipes = { words = { "recettes?", "recipes?" }, read = Recipes },
    achievements = { words = { "hauts? faits?", "achievements?" }, read = Achievements },
    lockouts = { words = { "verrouillages?", "instances? faites?", "lockouts?", "lock ?out" }, ask = function() RequestRaidInfo() end, event = "UPDATE_INSTANCE_INFO", read = Lockouts },
    calendar = { words = { "calendrier", "evenements?", "calendar" }, ask = function() C_Calendar.OpenCalendar() end, event = "CALENDAR_UPDATE_EVENT_LIST", read = Calendar },
    played = { words = { "temps de jeu", "temps joue", "heures de jeu", "time played", "played" }, ask = function() RequestTimePlayed() end, event = "TIME_PLAYED_MSG", read = Played },
}

-- A topic of a module.
function ns.Topic(name, topic)
    TOPICS[name] = topic
end

local ACCENTS = {
    ["\195\160"] = "a", ["\195\162"] = "a", ["\195\167"] = "c", ["\195\168"] = "e", ["\195\169"] = "e", ["\195\170"] = "e", ["\195\171"] = "e",
    ["\195\174"] = "i", ["\195\175"] = "i", ["\195\180"] = "o", ["\195\185"] = "u", ["\195\187"] = "u", ["\195\137"] = "e", ["\195\128"] = "a",
}

-- What to read for a question: the topics it speaks of and those wanted, and
-- the readings wanted ({ topics, reads }).
function ns.WhatToRead(question, wanted)
    local topics, reads, taken = {}, {}, {}
    if not ns.On("ask") then return topics, reads end
    local function Add(name)
        local topic = TOPICS[name]
        if topic and not taken[name] and #topics < MAX_TOPICS and (not topic.module or ns.On(topic.module)) then
            taken[name] = true
            topics[#topics + 1] = name
        end
    end
    for _, name in ipairs(wanted and wanted.topics or {}) do Add(name) end
    local text = lower(gsub(question or "", "\195[\128-\191]", ACCENTS))
    for name, topic in pairs(TOPICS) do
        for _, word in ipairs(topic.words) do
            if find(text, "%f[%w]" .. word .. "%f[%W]") then Add(name) end
        end
    end
    for _, expression in ipairs(wanted and wanted.reads or {}) do
        if #reads < MAX_READS then reads[#reads + 1] = expression end
    end
    return topics, reads
end

-- Reads topics, by name: done({ name = what it says or { error } }) once all are.
function ns.Gather(names, done)
    local data, left, started, asked = {}, 0, false, 0

    local function Read(name, ...)
        local ok, result = pcall(TOPICS[name].read, ...)
        if ok then ok, result = pcall(ns.Plain, result, 1) end
        data[name] = ok and result or { error = tostring(result) }
    end
    local function Close()
        if started and left == 0 then done(data) end
    end

    for _, name in ipairs(names) do
        local topic = TOPICS[name]
        if not topic then
            data[name] = { error = "not a topic" }
        elseif data[name] == nil and asked < MAX_TOPICS then
            asked = asked + 1
            if topic.ask then
                left = left + 1
                data[name] = {} -- taken
                local frame = CreateFrame("Frame")
                local function Came(...)
                    if not frame then return end
                    frame:UnregisterAllEvents()
                    frame = nil
                    Read(name, ...)
                    left = left - 1
                    Close()
                end
                frame:SetScript("OnEvent", function(_, _, ...) Came(...) end)
                pcall(frame.RegisterEvent, frame, topic.event)
                C_Timer.After(WAIT, function() Came() end)
                pcall(topic.ask)
            else
                Read(name)
            end
        end
    end
    started = true
    Close()
end

ns.Module({ key = "ask", category = "limits", limit = true, order = 30, title = "OPTION_ASK", tip = "OPTION_ASK_TIP" })
