-- claude-in-wow: the versions of the game. Retail and Forever have the newest
-- functions; the Classic versions (Era, Anniversary, Titan, Mists) keep older ones
-- for the quest log, the reputations, the spells, the talents and the recipes.
-- ns.Game gives each the same way, as the newest do; nothing here touches the
-- game's own tables.
--   ns.Game.flavor: "retail", "mop", "cata", "wrath", "tbc", "forever" or "era"

local addonName, ns = ...

local ipairs, pairs, pcall, select, tonumber, type = ipairs, pairs, pcall, select, tonumber, type

local Game = {}
ns.Game = Game

-- The first of some functions the game has.
local function First(...)
    for index = 1, select("#", ...) do
        local fn = select(index, ...)
        if fn then return fn end
    end
end

local function Try(fn, ...)
    if not fn then return nil end
    local ok, first, second, third, fourth, fifth, sixth, seventh, eighth = pcall(fn, ...)
    if ok then return first, second, third, fourth, fifth, sixth, seventh, eighth end
end

----------------------------------------------------------------------
-- Which version
----------------------------------------------------------------------

local FLAVORS = { -- from this interface number on
    { 100000, "retail", "World of Warcraft" },
    { 50000, "mop", "World of Warcraft: Mists of Pandaria Classic" },
    { 40000, "cata", "World of Warcraft: Cataclysm Classic" },
    { 30000, "wrath", "World of Warcraft: Wrath of the Lich King Classic" },
    { 20000, "tbc", "World of Warcraft: Burning Crusade Classic" },
    { 16000, "forever", "World of Warcraft Forever" },
    { 0, "era", "World of Warcraft Classic" },
}

Game.version, Game.build, Game.date, Game.interface = GetBuildInfo()
for _, flavor in ipairs(FLAVORS) do
    if (tonumber(Game.interface) or 0) >= flavor[1] then
        Game.flavor, Game.title = flavor[2], flavor[3]
        break
    end
end

-- Whether the world is the old one, with its zones' maps (1411 and on).
Game.oldWorld = Game.flavor == "era" or Game.flavor == "forever" or Game.flavor == "tbc" or Game.flavor == "wrath"

----------------------------------------------------------------------
-- The quest log
----------------------------------------------------------------------

local Quests = C_QuestLog or {}

-- The lines of the log, and the quests in it.
Game.QuestLines = First(Quests.GetNumQuestLogEntries, GetNumQuestLogEntries)

-- A line of the log: { title, level, isHeader, questID, suggestedGroup, isHidden, complete, failed }.
function Game.QuestLine(index)
    if Quests.GetInfo then return Quests.GetInfo(index) end
    local title, level, group, isHeader, _, complete, _, questID = GetQuestLogTitle(index)
    if not title then return nil end
    return {
        title = title, level = level, isHeader = isHeader and true or false, questID = questID, questLogIndex = index,
        suggestedGroup = tonumber(group), complete = complete == 1, failed = complete == -1,
    }
end

-- A quest's line in the log, nil when it is not in it.
function Game.QuestIndex(questID)
    local index = Try(First(Quests.GetLogIndexForQuestID, GetQuestLogIndexByID), questID)
    return index and index > 0 and index or nil
end

function Game.QuestComplete(questID)
    if Quests.IsComplete then return Quests.IsComplete(questID) end
    local index = Game.QuestIndex(questID)
    local line = index and Game.QuestLine(index)
    return line and line.complete or false
end

function Game.QuestFailed(questID)
    if Quests.IsFailed then return Quests.IsFailed(questID) end
    local index = Game.QuestIndex(questID)
    local line = index and Game.QuestLine(index)
    return line and line.failed or false
end

function Game.QuestReady(questID)
    return Try(Quests.ReadyForTurnIn, questID)
end

-- "Dungeon", "Elite"...
function Game.QuestTag(questID)
    if Quests.GetQuestTagInfo then
        local tag = Quests.GetQuestTagInfo(questID)
        return tag and tag.tagName or nil
    end
    return (select(2, Try(GetQuestTagInfo, questID)))
end

-- A quest's title, nil until the game has it.
function Game.QuestTitle(questID)
    local title = ns.Clean(Try(First(Quests.GetTitleForQuestID, Quests.GetQuestInfo), questID))
    return title and title ~= "" and title or nil
end

-- Asks for a quest's data; false when the game loads them by itself.
function Game.LoadQuest(questID)
    if not Quests.RequestLoadQuestByID then return false end
    Quests.RequestLoadQuestByID(questID)
    return true
end

function Game.QuestHandedIn(questID)
    return Try(First(Quests.IsQuestFlaggedCompleted, IsQuestFlaggedCompleted), questID) and true or false
end

-- The quests handed in, a list of numbers.
function Game.QuestsHandedIn()
    if Quests.GetAllCompletedQuestIDs then return Quests.GetAllCompletedQuestIDs() end
    local list = {}
    for questID in pairs(Try(GetQuestsCompleted) or {}) do list[#list + 1] = questID end
    return list
end

-- The log open on a quest of it: false when it is not in the log.
function Game.OpenQuest(questID)
    local index = Game.QuestIndex(questID)
    if not index then return false end
    if QuestMapFrame_OpenToQuestDetails then
        QuestMapFrame_OpenToQuestDetails(questID)
    elseif QuestLog_OpenToQuest then
        QuestLog_OpenToQuest(index, true)
    elseif QuestLogFrame and QuestLog_SetSelection then
        if not QuestLogFrame:IsShown() then ShowUIPanel(QuestLogFrame) end
        QuestLog_SetSelection(index)
        if QuestLog_Update then QuestLog_Update() end
    else
        return false
    end
    return true
end

function Game.WatchQuest(questID)
    if Quests.AddQuestWatch then return Quests.AddQuestWatch(questID) end
    local index = Game.QuestIndex(questID)
    if index and AddQuestWatch then AddQuestWatch(index) end
end

----------------------------------------------------------------------
-- The map
----------------------------------------------------------------------

-- The player's pin, { map, x, y } (percent); nil without one.
function Game.CurrentPin()
    local pin = Try(C_Map.HasUserWaypoint) and Try(C_Map.GetUserWaypoint)
    local position = pin and pin.position
    return position and { map = pin.uiMapID, x = position.x * 100, y = position.y * 100 } or nil
end

function Game.ClearPin()
    Try(C_Map.ClearUserWaypoint)
end

-- Whether the game has pins.
function Game.HasPins()
    return C_Map.SetUserWaypoint ~= nil
end

-- A line over the screen, as the raid alerts are.
function Game.Alert(text)
    local color = ChatTypeInfo and ChatTypeInfo.RAID_WARNING or { r = 1, g = 0.28, b = 0 }
    if RaidWarningUtil and RaidWarningUtil.AddMessage and pcall(RaidWarningUtil.AddMessage, text, color, 8, RaidWarningUtil.MessageType and RaidWarningUtil.MessageType.RaidWarning) then return end
    if RaidNotice_AddMessage and RaidWarningFrame and pcall(RaidNotice_AddMessage, RaidWarningFrame, text, color, 8) then return end
    if UIErrorsFrame then UIErrorsFrame:AddMessage(text, 1, 0.82, 0) end
end

-- A quest out of the tracker, whether it is in it, where that can be asked.
function Game.UnwatchQuest(questID)
    if Quests.RemoveQuestWatch then return Quests.RemoveQuestWatch(questID) end
    local index = Game.QuestIndex(questID)
    if index and RemoveQuestWatch then RemoveQuestWatch(index) end
end

function Game.QuestWatched(questID)
    if Quests.GetQuestWatchType then return Try(Quests.GetQuestWatchType, questID) ~= nil end
    local index = Game.QuestIndex(questID)
    return index and IsQuestWatched and IsQuestWatched(index) and true or false
end

-- The game's own icon, as its friends list shows it.
function Game.ShowIcon(texture)
    local asked = C_Texture and C_Texture.GetTitleIconTexture and Enum.TitleIconVersion and pcall(C_Texture.GetTitleIconTexture, BNET_CLIENT_WOW or "WoW",
        Enum.TitleIconVersion.Medium, function(success, file)
            if success then texture:SetTexture(file) end
        end)
    if not asked then texture:SetTexture("Interface\\FriendsFrame\\Battlenet-WoWicon") end
end

-- A pin there, followed on screen, where the game has them: true when it is set.
function Game.Pin(map, x, y)
    if not (C_Map.SetUserWaypoint and UiMapPoint) then return false end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(map) then return false end
    if C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x / 100, y / 100)) == false then return false end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    return true
end

function Game.PinLink()
    return Try(C_Map.GetUserWaypointHyperlink)
end

-- The world map, open on a map; not in combat.
function Game.OpenMap(map)
    local open = First(C_Map.OpenWorldMap, OpenWorldMap)
    if open then return open(map) end
    if not (WorldMapFrame and ToggleWorldMap) then return end
    if not WorldMapFrame:IsShown() then ToggleWorldMap() end
    if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(map) end
end

----------------------------------------------------------------------
-- The character
----------------------------------------------------------------------

-- The reputations: { name, isHeader, isCollapsed, isHeaderWithRep, reaction,
-- currentStanding, currentReactionThreshold, nextReactionThreshold, atWarWith }.
local Reputation = C_Reputation or {}
Game.Factions = First(Reputation.GetNumFactions, GetNumFactions)

function Game.Faction(index)
    if Reputation.GetFactionDataByIndex then return Reputation.GetFactionDataByIndex(index) end
    local name, _, reaction, low, high, value, atWar, _, isHeader, isCollapsed, hasRep = GetFactionInfo(index)
    if not name then return nil end
    return {
        name = name, reaction = reaction, currentStanding = value, currentReactionThreshold = low, nextReactionThreshold = high,
        atWarWith = atWar, isHeader = isHeader, isCollapsed = isCollapsed, isHeaderWithRep = hasRep,
    }
end

-- The currencies: { name, isHeader, quantity, maxQuantity }.
local Currency = C_CurrencyInfo or {}
Game.Currencies = First(Currency.GetCurrencyListSize, GetCurrencyListSize)

function Game.Currency(index)
    if Currency.GetCurrencyListInfo then return Currency.GetCurrencyListInfo(index) end
    local name, isHeader, _, _, _, count, _, most = GetCurrencyListInfo(index)
    return name and { name = name, isHeader = isHeader, quantity = count, maxQuantity = most } or nil
end

-- The talents of the old trees: { { tree, points, talents = { { name, rank, of } } } };
-- nil where the game has the newest ones, or none.
function Game.OldTalents()
    if not GetNumTalentTabs or not GetTalentInfo then return nil end
    local trees = {}
    for tab = 1, Try(GetNumTalentTabs) or 0 do
        local first, second, third, fourth, fifth = Try(GetTalentTabInfo, tab)
        -- some versions give the tree's number first
        local numbered = type(first) == "number"
        local tree = { tree = numbered and second or first, points = numbered and fifth or third, talents = {} }
        for index = 1, Try(GetNumTalents, tab) or 0 do
            local name, _, _, _, rank, most = Try(GetTalentInfo, tab, index)
            if type(name) == "string" and (most or 0) > 0 then tree.talents[#tree.talents + 1] = { name = name, rank = rank, of = most } end
        end
        if #tree.talents > 0 then trees[#trees + 1] = tree end
    end
    return #trees > 0 and trees or nil
end

-- The spells of the old book: { { name, rank, school, passive } }; nil where the
-- game has the newest one.
function Game.OldSpells()
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines or not GetNumSpellTabs then return nil end
    local list = {}
    for tab = 1, Try(GetNumSpellTabs) or 0 do
        local school, _, offset, count = Try(GetSpellTabInfo, tab)
        for slot = (offset or 0) + 1, (offset or 0) + (count or 0) do
            local name, rank = Try(GetSpellBookItemName, slot, BOOKTYPE_SPELL or "spell")
            if name then
                list[#list + 1] = { name = name, rank = rank ~= "" and rank or nil, school = school, passive = Try(IsPassiveSpell, slot, BOOKTYPE_SPELL or "spell") or nil }
            end
        end
    end
    return list
end

-- The recipes of the old profession windows, when one is open: the profession, its
-- rank, the recipes ({ name, canMake, difficulty }).
function Game.OldRecipes()
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo or not GetTradeSkillLine then return nil end
    local profession, rank = Try(GetTradeSkillLine)
    if not profession or profession == "UNKNOWN" then return nil, true end
    local known = {}
    for index = 1, Try(GetNumTradeSkills) or 0 do
        local name, kind, available = Try(GetTradeSkillInfo, index)
        if name and kind ~= "header" and kind ~= "subheader" then
            known[#known + 1] = { name = name, canMake = (available or 0) > 0 and available or nil, difficulty = kind }
        end
    end
    return { profession = profession, rank = rank, known = known }
end

----------------------------------------------------------------------
-- Items
----------------------------------------------------------------------

Game.ItemStats = First(C_Item and C_Item.GetItemStats, GetItemStats)

-- An item's tooltip as the newest versions give it, { lines = { { leftText } } };
-- the others' is read on a tooltip never shown.
local reader

local function Lines(fill)
    if not reader then
        reader = CreateFrame("GameTooltip", "ClaudeInWoWReader", nil, "GameTooltipTemplate")
        reader:SetOwner(UIParent, "ANCHOR_NONE")
    end
    reader:SetOwner(UIParent, "ANCHOR_NONE")
    reader:ClearLines()
    fill(reader)
    local lines = {}
    for index = 1, reader:NumLines() or 0 do
        local text = _G["ClaudeInWoWReaderTextLeft" .. index]
        lines[index] = { leftText = text and text:GetText() }
    end
    return { lines = lines }
end

local Tooltip = C_TooltipInfo or {}

Game.BagTooltip = Tooltip.GetBagItem or function(bag, slot)
    return Lines(function(tooltip) tooltip:SetBagItem(bag, slot) end)
end

Game.WornTooltip = Tooltip.GetInventoryItem or function(unit, slot)
    return Lines(function(tooltip) tooltip:SetInventoryItem(unit, slot) end)
end

-- fn(tooltip, itemID) each time a tooltip shows an item.
function Game.OnItemTooltip(fn)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
        return TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if type(data) == "table" then fn(tooltip, ns.Clean(data.id)) end
        end)
    end
    for _, tooltip in ipairs({ GameTooltip or false, ItemRefTooltip or false }) do
        if tooltip and tooltip.HookScript then
            pcall(tooltip.HookScript, tooltip, "OnTooltipSetItem", function(self)
                local _, link = self:GetItem()
                fn(self, link and tonumber(link:match("item:(%d+)")))
            end)
        end
    end
end

-- The game's own bags drawn again: fn(button, bag, slot) for each slot.
function Game.OnGameBags(fn)
    local redraws = {}
    local containers = { _G.ContainerFrameCombinedBags }
    for index = 1, 13 do containers[#containers + 1] = _G["ContainerFrame" .. index] end
    for _, container in pairs(containers) do
        if type(container) == "table" and type(container.UpdateItems) == "function" then
            local function Draw(frame)
                if not frame.EnumerateValidItems then return end
                for _, button in frame:EnumerateValidItems() do
                    local bag = button.GetBagID and button:GetBagID()
                    if bag then fn(button, bag, button:GetID()) end
                end
            end
            hooksecurefunc(container, "UpdateItems", Draw)
            redraws[#redraws + 1] = function() if container:IsShown() then Draw(container) end end
        end
    end
    if #redraws == 0 and type(_G.ContainerFrame_Update) == "function" then
        local function Draw(frame)
            local name = frame.GetName and frame:GetName()
            for index = 1, name and frame.size or 0 do
                local button = _G[name .. "Item" .. index]
                if button then fn(button, frame:GetID(), button:GetID()) end
            end
        end
        hooksecurefunc("ContainerFrame_Update", Draw)
        redraws[1] = function()
            for index = 1, 13 do
                local frame = _G["ContainerFrame" .. index]
                if frame and frame:IsShown() then Draw(frame) end
            end
        end
    end
    return redraws
end

-- The bank's containers, and the account's bank, where there is one.
local Bags = Enum and Enum.BagIndex or {}
Game.bank, Game.accountBank = {}, {}
for tab = 1, 9 do
    if Bags["CharacterBankTab_" .. tab] then Game.bank[#Game.bank + 1] = Bags["CharacterBankTab_" .. tab] end
    if Bags["AccountBankTab_" .. tab] then Game.accountBank[#Game.accountBank + 1] = Bags["AccountBankTab_" .. tab] end
end
if #Game.bank == 0 then
    Game.bank[1] = Bags.Bank or -1
    for bag = 1, 7 do
        if Bags["BankBag_" .. bag] then Game.bank[#Game.bank + 1] = Bags["BankBag_" .. bag] end
    end
end
