-- Offline test of claude-in-wow: stubs the game API, loads the .toc's
-- files in order, runs a login, errors, the bank and a logout, then writes the
-- saved data the way the game does (for the server's test).
-- lua addon_test.lua <addon folder> <output SavedVariables file>

os.setlocale("C") -- numbers written with a dot, as the game does
local folder, output = arg[1], arg[2]
local passed, failed = 0, 0
local function ok(name, got, want)
    if got == want then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL " .. name .. ": got " .. tostring(got) .. ", want " .. tostring(want))
    end
end

-- Lua 5.x compatibility with the game's globals
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
date, time = os.date, os.time
local clock = 100
GetTime = function() return clock end
debugstack = function() return "Interface/AddOns/Broken/Broken.lua:12: in function <...>" end
local handler = function(message) print("default handler: " .. tostring(message)) end
geterrorhandler = function() return handler end
seterrorhandler = function(fn) handler = fn end
GetLocale = function() return os.getenv("CIW_LOCALE") or "frFR" end
do -- as the game's: "%2$s" takes the second
    local real = string.format
    string.format = function(text, ...)
        if type(text) ~= "string" or not text:find("%%%d%$") then return real(text, ...) end
        local values, order = { ... }, {}
        text = text:gsub("%%(%d)%$(%a)", function(number, kind) order[#order + 1] = values[tonumber(number)] return "%" .. kind end)
        return real(text, table.unpack(order))
    end
end
GetBuildInfo = function() return "1.60.1", "71091", "Nov 25 2026", 16001 end

local printed = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) printed[#printed + 1] = text end }

-- Frames: events and scripts kept, font strings measured (a photo glyph is
-- 9 x 8 pixels, the game leaves one more between glyphs), anything else a no-op
local frames = {}
local noop = function() end
-- methods (capitalised) are no-ops, other fields are nil as on real frames
local stub = { __index = function(_, key) if type(key) == "string" and key:match("^%u") then return noop end end }
local fontMissing = false

local function FontString()
    local fs = setmetatable({ shown = true }, stub)
    function fs:SetText(text)
        if fontMissing then error("Font not set") end
        self.text = text
    end
    function fs:SetPoint(_, _, _, x, y) self.x, self.y = x, y end
    function fs:Show() self.shown = true end
    function fs:Hide() self.shown = false end
    function fs:SetShown(shown) self.shown = shown and true or false end
    function fs:GetStringWidth() return #(self.text or "") * 10 end
    function fs:GetStringHeight() return 8 end
    return fs
end
CreateFrame = function(kind, name)
    local f = setmetatable({ events = {}, scripts = {}, shown = true, strings = {}, kind = kind }, stub)
    function f:RegisterEvent(e) self.events[e] = true end
    function f:GetEffectiveScale() return 1 end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:GetScript(name) return self.scripts[name] end
    function f:GetHighlightTexture() return setmetatable({}, stub) end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(shown) self.shown = shown and true or false end
    function f:IsShown() return self.shown end
    -- sizes and scrolling, as the Claude window reads them
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:SetWidth(w) self.width = w end
    function f:SetHeight(h) self.height = h end
    -- (rawget: the stub answers every missing key with a function)
    function f:GetWidth() return rawget(self, "width") or 0 end
    function f:GetHeight() return rawget(self, "height") or 0 end
    function f:SetFrameLevel(level) self.level = level end
    function f:GetFrameLevel() return rawget(self, "level") or 1 end
    function f:SetVerticalScroll(v) self.vscroll = v end
    function f:GetVerticalScroll() return rawget(self, "vscroll") or 0 end
    -- an edit box: its text, focus and selection; SetText tells OnTextChanged
    function f:SetText(text)
        self.text = text
        if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
    end
    function f:GetText() return rawget(self, "text") end
    function f:SetFocus() self.focused = true end
    function f:ClearFocus() self.focused = false end
    function f:HighlightText() self.highlighted = true end
    function f:GetCursorPosition() return #(rawget(self, "text") or "") end
    function f:Insert(text) self.text = (rawget(self, "text") or "") .. text end
    function f:CreateFontString()
        local fs = FontString()
        self.strings[#self.strings + 1] = fs
        return fs
    end
    function f:CreateAnimationGroup() -- LibDBIcon's fading
        local group = setmetatable({}, stub)
        function group:CreateAnimation() return setmetatable({}, stub) end
        return group
    end
    function f:CreateTexture()
        local t = setmetatable({ points = {} }, stub)
        function t:GetParent() return f end
        function t:SetShown(shown) self.shown = shown and true or false end
        function t:Show() self.shown = true end
        function t:Hide() self.shown = false end
        function t:ClearAllPoints() self.points, self.height = {}, nil end
        function t:SetPoint(point) self.points[point] = true end
        function t:SetHeight(height) self.height = height end
        function t:SetWidth(width) self.width = width end
        return t
    end
    f.name = name
    frames[#frames + 1] = f
    return f
end
local function fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

-- The game's AddOns settings
strmatch = string.match -- for LibStub
local registered = {}
Settings = {
    VarType = { Boolean = "boolean" },
    Default = { True = true },
    RegisterVerticalLayoutCategory = function(name) registered.category = name return {} end,
    RegisterAddOnSetting = function(_, variable, key, tbl, kind, name, default)
        registered.setting = { variable = variable, key = key, tbl = tbl, name = name, default = default }
        return {}
    end,
    CreateCheckbox = function(_, _, tooltip) registered.tooltip = tooltip end,
    RegisterAddOnCategory = function() registered.added = true end,
}

-- The screen and screenshots
UIParent, GameTooltip = setmetatable({}, stub), setmetatable({}, stub)
Minimap = CreateFrame("Frame")
UISpecialFrames = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
securecallfunction = function(fn, ...) return fn(...) end -- CallbackHandler
IsControlKeyDown = function() return false end
local screenWidth, screenHeight = 1040, 240 -- small: a photo not compact takes two pages
GetPhysicalScreenSize = function() return screenWidth, screenHeight end
local cvars = { screenshotFormat = "jpeg" }
GetCVar = function(name) return cvars[name] end
SetCVar = function(name, value) cvars[name] = value end
local inCombat = false
InCombatLockdown = function() return inCombat end
IsShiftKeyDown = function() return false end
local screenshots = 0
Screenshot = function() screenshots = screenshots + 1 end
local timers = {}
local tickers = {}
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTicker = function(_, fn)
        local ticker = { fn = fn }
        function ticker:Cancel() self.cancelled = true end
        tickers[#tickers + 1] = ticker
        return ticker
    end,
}
SlashCmdList = {}

-- The character
-- Forever: no realms, first and last names unique in the region
UnitName = function(unit)
    local names = { player = "Arden", party1 = "Vex", party2 = "Mira" }
    return names[unit]
end
UnitNameUnmodified = function(unit) if unit == "player" then return "Arden", "Valcourt" end end
local regionalNames = true
RegionalUniqueNamesEnabled = function() return regionalNames end
local realmName = ""
GetRealmName = function() return realmName end
UnitClass = function(unit) if unit == "player" then return "Mage", "MAGE" end return "Prêtre", "PRIEST" end
GetGuildInfo = function() return "Les Veilleurs", "Membre" end
UnitLevel = function() return 44 end
UnitRace = function() return "Mort-vivant" end
UnitFactionGroup = function() return "Horde" end
GetMoney = function() return 1234567 end
UnitXP = function() return 41000 end
UnitXPMax = function() return 88400 end
GetXPExhaustion = function() return nil end
UnitHealth = function() return 1800 end
UnitHealthMax = function() return 2100 end
UnitIsDeadOrGhost = function() return false end
C_Map = {
    GetBestMapForUnit = function() return 1443 end,
    GetMapInfo = function() return { name = "Désolace" } end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.29123, 0.62871 end } end,
}
GetRealZoneText = function() return "Maraudon" end
GetSubZoneText = function() return "Grottes orange" end
IsResting = function() return false end
IsInInstance = function() return true, "party" end
GetInstanceInfo = function() return "Maraudon", "party", 1, "Normal" end
GetNumGroupMembers = function() return 3 end
IsInRaid = function() return false end
UnitExists = function(unit) return unit == "party1" or unit == "party2" end
UnitIsUnit = function(a, b) return a == b end
UnitGroupRolesAssigned = function(unit) return unit == "party1" and "TANK" or "HEALER" end
UnitIsConnected = function() return true end
GetProfessions = function() return 1, 2 end
GetProfessionInfo = function(i) if i == 1 then return "Couture", nil, 210, 225 end return "Enchantement", nil, 190, 225 end

-- Quests
local QUESTS = {
    { isHeader = true, title = "Maraudon" },
    { questID = 7064, title = "Pourriture et regret", level = 47, suggestedGroup = 5 },
    { questID = 7029, title = "Corruption de la vallée", level = 47 },
    { isHeader = true, title = "Désolace" },
    { questID = 1365, title = "Khan Dez'hepah", level = 38 },
    { questID = 999, title = "A hidden tracking quest", isHidden = true },
}
C_QuestLog = {
    GetAllCompletedQuestIDs = function() return { 5382, 7 } end,
    -- one more quest than listed: it sits under a folded header
    GetNumQuestLogEntries = function() return #QUESTS, 5 end,
    GetInfo = function(i) return QUESTS[i] end,
    GetQuestObjectives = function(id)
        if id == 7064 then
            return { { text = "Pylônes alimentés : 2/3", type = "event", finished = false, numFulfilled = 2, numRequired = 3 } }
        elseif id == 7029 then
            return { { text = "Vylestem : 8/8 |4vigne soignée:vignes soignées;", type = "monster", finished = true, numFulfilled = 8, numRequired = 8 } }
        elseif id == 1365 then
            return { { text = "Khan Dez'hepah : 0/1 |4personnage tué:personnages tués;", type = "monster", finished = false, numFulfilled = 0, numRequired = 1 } }
        end
        return {}
    end,
    IsComplete = function(id) return id == 7029 end,
    ReadyForTurnIn = function(id) return id == 7029 end,
    IsFailed = function() return false end,
    GetQuestTagInfo = function(id) if id == 7064 then return { tagName = "Donjon" } end end,
}

-- Bags and bank
Enum = { BagIndex = { Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4, ReagentBag = 5, Keyring = -1, Characterbanktab = -2 } }
for tab = 1, 9 do
    Enum.BagIndex["CharacterBankTab_" .. tab] = 5 + tab
    Enum.BagIndex["AccountBankTab_" .. tab] = 14 + tab
end
local bankOpen = false
local CONTENTS = {
    [0] = { { itemID = 2770, itemName = "Minerai de cuivre", stackCount = 12, quality = 1 }, { itemID = 2770, itemName = "Minerai de cuivre", stackCount = 8, quality = 1 }, false, { itemID = 17781, hyperlink = "|cff1eff00|Hitem:17781::::::::44:::::|h[La pierre de Maraudon]|h|r", stackCount = 1, quality = 2 } },
    [1] = { { itemID = 10504, itemName = "Chapeau vert de soie", hyperlink = "|cff0070dd|Hitem:10504::::::::44:::::|h[Chapeau vert de soie]|h|r", stackCount = 1, quality = 3, isBound = true }, false },
    [6] = { { itemID = 4306, itemName = "Étoffe de soie", stackCount = 20, quality = 1 }, false },
}
-- What the game says of items (name, link, quality, item level, required
-- level, type, subtype, stack, slot, icon, vendor price)
ITEM_QUALITY1_DESC, ITEM_QUALITY2_DESC, ITEM_QUALITY3_DESC = "Commun", "Inhabituel", "Rare"
INVTYPE_HEAD = "Tête"
C_Item = {
    GetItemInfo = function(id)
        if id == 2770 then return "Minerai de cuivre", nil, 1, 10, 0, "Artisanat", "Métal et pierre", 20, "", nil, 5 end
        if id == 17781 then return "La pierre de Maraudon", nil, 2, 40, 0, "Quête", "Quête", 1, "INVTYPE_NON_EQUIP_IGNORE", nil, 0 end
        if id == 10504 then return "Chapeau vert de soie", nil, 3, 41, 36, "Armure", "Tissu", 1, "INVTYPE_HEAD", nil, 1520 end
    end,
    GetItemStats = function(link)
        if link and link:find("item:10504", 1, true) then
            return { ITEM_MOD_INTELLECT_SHORT = 8, ITEM_MOD_STAMINA_SHORT = 5, RESISTANCE0_NAME = 45, ITEM_MOD_UNKNOWN = 3 }
        end
    end,
}
ITEM_MOD_INTELLECT_SHORT, ITEM_MOD_STAMINA_SHORT, RESISTANCE0_NAME = "Intelligence", "Endurance", "Armure"
-- What the items' tooltips say (C_TooltipInfo's data); the ore's tooltip fails
ITEM_SPELL_TRIGGER_ONUSE, ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONPROC = "Utiliser :", "Équipé :", "Chances quand vous touchez :"
local HAT_LINES = {
    { leftText = "Chapeau vert de soie" }, { leftText = "Lié quand ramassé" }, { leftText = "45 Armure" },
    { leftText = "|cff1eff00+8 Intelligence|r" },
    { leftText = "|cff1eff00Équipé : Augmente les dégâts et les soins produits par les sorts de 7 au maximum.|r" },
    { leftText = "|cff1eff00Chances quand vous touchez : Vous rend 20 points de mana.|r" },
}
C_TooltipInfo = {
    GetBagItem = function(bag, slot)
        if bag == 0 and slot == 1 then error("tooltip not ready") end
        if bag == 0 and slot == 4 then
            return { lines = { { leftText = "La pierre de Maraudon" }, { leftText = "Objet de quête" },
                { leftText = "|cff1eff00Utiliser : Lit les instructions du paria.|r" }, { leftText = "|cffffd100\"Une pierre étrange.\"|r" } } }
        end
        if bag == 1 and slot == 1 then return { lines = HAT_LINES } end
    end,
    GetInventoryItem = function(unit, slot) if unit == "player" and slot == 1 then return { lines = HAT_LINES } end end,
}
-- Hooks and tooltips, for the marks
hooksecurefunc = function(target, name, hook)
    local original = target[name]
    target[name] = function(...)
        original(...)
        hook(...)
    end
end
local tooltipPostCalls = {}
local function tooltipPostCall(tip, data) for _, fn in ipairs(tooltipPostCalls) do fn(tip, data) end end
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) tooltipPostCalls[#tooltipPostCalls + 1] = fn end }
Enum.TooltipDataType = { Item = 0 }
-- The game's bags, which draw their slots' items
local function Slot(itemID)
    return {
        itemID = itemID,
        CreateTexture = function()
            return {
                SetSize = noop, SetPoint = noop,
                SetTexture = function(self, texture) self.texture = texture end,
                Show = function(self) self.shown = true end,
                Hide = function(self) self.shown = false end,
            }
        end,
    }
end
local SHOWN_BAG = 77
local gameSlots = { Slot(2770), Slot(9999) }
for index, slot in ipairs(gameSlots) do
    slot.GetBagID = function() return SHOWN_BAG end
    slot.GetID = function() return index end
end
ContainerFrameCombinedBags = CreateFrame("Frame")
ContainerFrameCombinedBags.UpdateItems = function(self) self.updated = true end
ContainerFrameCombinedBags.EnumerateValidItems = function() return ipairs(gameSlots) end
C_Container = {
    GetContainerItemQuestInfo = function(bag, slot)
        if bag == 0 and slot == 4 then return { isQuestItem = true, questID = 7067, isActive = false } end
        return { isQuestItem = false }
    end,
    GetContainerNumSlots = function(bag)
        if bag >= 6 and not bankOpen then return 0 end
        return CONTENTS[bag] and #CONTENTS[bag] or 0
    end,
    GetContainerNumFreeSlots = function(bag)
        if bag >= 6 and not bankOpen then return 0 end
        local free = 0
        for _, v in ipairs(CONTENTS[bag] or {}) do if not v then free = free + 1 end end
        return free
    end,
    GetContainerItemInfo = function(bag, slot)
        local v = CONTENTS[bag] and CONTENTS[bag][slot]
        return v or nil
    end,
    GetContainerItemID = function(bag, slot)
        local v = CONTENTS[bag] and CONTENTS[bag][slot]
        return v and v.itemID or nil
    end,
}
GetInventoryItemLink = function(_, slot)
    if slot == 1 then return "|cff0070dd|Hitem:10504::::::::44:::::|h[Chapeau vert de soie]|h|r" end
end
GetInventoryItemDurability = function(slot) if slot == 1 then return 30, 50 end end
GetInventoryItemQuality = function() return 3 end

-- Addons
local ADDONS = {
    { "ElvUI", "|cff1784d1ElvUI|r", "13.80", true, true, "" },
    { "XLoot", "XLoot", "1.0", false, false, "DISABLED" },
}
C_AddOns = {
    DoesAddOnExist = function() return false end, -- no answer addons yet
    IsAddOnLoaded = function() return false end,
    GetNumAddOns = function() return #ADDONS end,
    GetAddOnInfo = function(i) local a = ADDONS[i] return a[1], a[2], "", true, a[6] end,
    GetAddOnEnableState = function(name) return name == "ElvUI" and 2 or 0 end,
    GetAddOnMetadata = function(name, field)
        if name == "claude-in-wow" and field == "Version" then
            return io.open(folder .. "/claude-in-wow.toc"):read("*a"):match("## Version: (%S+)")
        end
        for _, a in ipairs(ADDONS) do if a[1] == name then return a[3] end end
    end,
    IsAddOnLoaded = function(i) return ADDONS[i] and ADDONS[i][5] or false end,
}

-- Load the addon in .toc order
local function load()
    local ns = {}
    local toc = io.open(folder .. "/claude-in-wow.toc"):read("*a")
    for file in toc:gmatch("[^\r\n]+") do
        if not file:match("^##") and file:match("%.lua$") then
            local chunk = assert(loadfile(folder .. "/" .. file))
            chunk("claude-in-wow", ns)
        end
    end
    return ns
end

frames = {}
local ns = load()

-- Saved data already there
local oldChar = { savedAt = 1 }
ClaudeInWoWDB = { version = 1, characters = { ["Arden Valcourt"] = oldChar } }

-- An error before the saved data is loaded, then the login
handler("Interface/AddOns/Broken/Broken.lua:12: attempt to index a nil value")
fire("ADDON_LOADED", "claude-in-wow")
fire("PLAYER_LOGIN")
local db = ClaudeInWoWDB
ok("saved data created", type(db) == "table" and db.version, 1)
ok("one slash command, /claude", SLASH_CLAUDEINWOW1 .. " " .. type(SlashCmdList.CLAUDEINWOW), "/claude function")
ok("an early error is kept", #db.errors, 1)
ok("compact photos by default", db.options.compactPhoto, true)
ok("no entry in the game's AddOns settings: the settings are in the Claude window", tostring(registered.category) .. " " .. tostring(registered.added), "nil nil")
ok("the minimap button on by default", db.options.minimapButton, true)
ok("with its stack", db.errors[1].stack ~= nil, true)
ok("for this character", db.errors[1].character, "Arden Valcourt")
ok("its data kept", db.characters["Arden Valcourt"], oldChar)

-- Keys elsewhere: "Name - Realm", or the name alone
regionalNames, realmName = false, "Forever"
ok("key with a realm", ns.CharacterKey(), "Arden - Forever")
realmName = ""
ok("key without realm nor last name", ns.CharacterKey(), "Arden")
regionalNames = true

handler("Interface/AddOns/Broken/Broken.lua:12: attempt to index a nil value")
ok("the same error in the same moment counts once", db.errors[1].count, 1)
clock = 101
handler("Interface/AddOns/Broken/Broken.lua:12: attempt to index a nil value")
ok("later, it counts twice", db.errors[1].count, 2)
fire("ADDON_ACTION_BLOCKED", "WindTools", "TargetUnit()")
ok("a blocked action", db.errors[1].kind == "blocked" and db.errors[1].message, "WindTools a voulu appeler la fonction protégée TargetUnit().")

-- The bank, noted while open
local char = db.characters["Arden Valcourt"]
ok("no bank yet", char.bank, nil)
bankOpen = true
fire("BANKFRAME_OPENED")
ok("bank read a moment later", char.bank, nil)
timers[#timers]()
ok("bank items", char.bank and char.bank.items[4306].count, 20)
ok("bank time", char.bank.savedAt ~= nil, true)
bankOpen = false
fire("BANKFRAME_CLOSED")
ok("a closed bank keeps what was noted", char.bank.items[4306].count, 20)

-- The logout (or reload): the snapshot
fire("PLAYER_LOGOUT")
ok("snapshot time", char.savedAt ~= nil and char.savedAt > 1, true)
ok("nothing said in chat", #printed, 0)
ok("character", char.character.level .. " " .. char.character.class, "44 Mage")
ok("money", char.character.money, 1234567)
ok("first and last names, no empty realm", char.character.name .. " " .. char.character.surname .. " " .. tostring(char.character.realm), "Arden Valcourt nil")
ok("max health only", tostring(char.character.health) .. " " .. char.character.healthMax, "nil 2100")
ok("place", char.location.subZone .. ", " .. char.location.map, "Grottes orange, Désolace")
ok("coordinates", char.location.x .. " " .. char.location.y, "29.1 62.9")
ok("instance", char.location.instance.name .. " " .. char.location.instance.difficulty, "Maraudon Normal")
ok("group without the player", #char.group.members, 2)
ok("roles", char.group.members[1].role, "TANK")
ok("professions", char.professions[1].name .. " " .. char.professions[1].rank, "Couture 210")
ok("quests", #char.quests, 3)
ok("zone header", char.quests[1].zone .. " / " .. char.quests[3].zone, "Maraudon / Désolace")
ok("objective", char.quests[1].objectives[1].text .. " " .. char.quests[1].objectives[1].have, "Pylônes alimentés : 2/3 2")
ok("dungeon tag and group size", char.quests[1].tag .. " " .. char.quests[1].group, "Donjon 5")
ok("ready to hand in", char.quests[2].ready, true)
ok("hidden quests left out", char.quests[4], nil)
ok("quests under a folded header counted", char.questsNotListed, 1)
ok("grammar code, singular", char.quests[3].objectives[1].text, "Khan Dez'hepah : 0/1 personnage tué")
ok("grammar code, plural", char.quests[2].objectives[1].text, "Vylestem : 8/8 vignes soignées")
ok("grammar code without a number", ns.StripCodes("|4Ennemi:Ennemis; vaincu"), "Ennemi vaincu")
ok("bags add stacks up", char.bags.items[2770].count, 20)
ok("name from the link", char.bags.items[17781].name, "La pierre de Maraudon")
ok("free slots", char.bags.free .. "/" .. char.bags.slots, "2/6")
ok("item type and vendor price", char.bags.items[2770].type .. "/" .. char.bags.items[2770].subType .. " " .. char.bags.items[2770].sell, "Artisanat/Métal et pierre 5")
ok("a quest item that starts a quest", tostring(char.bags.items[17781].questItem) .. " " .. char.bags.items[17781].startsQuest, "true 7067")
ok("no vendor price, no slot, subtype same as type", tostring(char.bags.items[17781].sell) .. tostring(char.bags.items[17781].slot) .. tostring(char.bags.items[17781].subType), "nilnilnil")
ok("gear: slot, item level, soulbound", char.bags.items[10504].slot .. " " .. char.bags.items[10504].itemLevel .. " " .. tostring(char.bags.items[10504].bound), "Tête 41 true")
ok("equipment", char.equipment.head.name .. " " .. char.equipment.head.durability, "Chapeau vert de soie 30/50")
ok("a quest item's tooltip: use and description", char.bags.items[17781].use .. " | " .. char.bags.items[17781].text, "Lit les instructions du paria. | \"Une pierre étrange.\"")
ok("gear's stats in the game's words, sorted, unknown ones left out", char.bags.items[10504].stats, "Armure +45, Endurance +5, Intelligence +8")
ok("gear's equip and proc effects", char.bags.items[10504].equip, "Augmente les dégâts et les soins produits par les sorts de 7 au maximum. / Chances quand vous touchez : Vous rend 20 points de mana.")
ok("a failing tooltip keeps the item", char.bags.items[2770].type .. " " .. tostring(char.bags.items[2770].use), "Artisanat nil")
ok("no stats but for gear", tostring(char.bags.items[17781].stats), "nil")
ok("equipped: stats and effects", char.equipment.head.stats .. " | " .. tostring(char.equipment.head.equip ~= nil), "Armure +45, Endurance +5, Intelligence +8 | true")
ok("addons: colour codes out", char.addons[1].title, "ElvUI")
ok("why an addon did not load", char.addons[2].reason, "DISABLED")
ok("the bank stays", char.bank.items[4306].count, 20)

-- Questions prepared in the game: the window is checked below, the text here
local shown, shownLabel
local realShowCopy = ns.ShowCopy
ns.ShowCopy = function(text, label) shown, shownLabel = text, label end
SlashCmdList.CLAUDEINWOW(" aide ")
ok("/claude aide says how to use it", printed[#printed]:find("/claude sacs", 1, true) ~= nil, true)
SlashCmdList.CLAUDEINWOW(" Sacs ")
local lines = {}
for line in shown:gmatch("[^\n]+") do lines[#lines + 1] = line end
local function line(start)
    for _, l in ipairs(lines) do if l:sub(1, #start) == start then return l end end
end
ok("first line for the assistant", lines[1], "[claude-in-wow 1.0.0] bags")
ok("its bubble says the question", shownLabel, "Que faire de tous ces objets ? Lesquels garder sur moi, mettre en banque, vendre ou détruire ?")
ok("the bags question", lines[2], "Question: Que faire de tous ces objets ? Lesquels garder sur moi, mettre en banque, vendre ou détruire ?")
ok("the character", line("Personnage:"), "Personnage: Arden Valcourt, niveau 44 Mage, Mort-vivant, Horde, 123g 45s 67c, XP 46%")
ok("where", line("Où:"), "Où: Maraudon, Grottes orange, (29.1, 62.9), instance Maraudon")
ok("professions", line("Métiers:"), "Métiers: Couture 210/225, Enchantement 190/225")
ok("quests counted", line("Quêtes"), "Quêtes (3):")
ok("a quest to hand in", line("- 7029"), "- 7029 [47] Corruption de la vallée (Maraudon), à rendre: Vylestem : 8/8 vignes soignées")
ok("equipment, with its stats and effects", line("- head:"), "- head: 10504 Chapeau vert de soie; Armure +45, Endurance +5, Intelligence +8; Équipé : Augmente les dégâts et les soins produits par les sorts de 7 au maximum. / Chances quand vous touchez : Vous rend 20 points de mana.")
ok("bags' slots", line("Sacs"), "Sacs (2 emplacements libres sur 6):")
ok("an item to sell", line("- 2770"), "- 2770 Minerai de cuivre x20: Commun, Artisanat/Métal et pierre, se vend 5c l'unité")
ok("a quest item, with its tooltip", line("- 17781"), "- 17781 La pierre de Maraudon x1: Inhabituel, Quête, objet de quête, commence la quête 7067; Utiliser : Lit les instructions du paria.; \"Une pierre étrange.\"")
ok("gear in the bags", line("- 10504"), "- 10504 Chapeau vert de soie x1: Rare, Armure/Tissu, Tête, niveau d'objet 41, lié, se vend 15s 20c l'unité; Armure +45, Endurance +5, Intelligence +8; Équipé : Augmente les dégâts et les soins produits par les sorts de 7 au maximum. / Chances quand vous touchez : Vous rend 20 points de mana.")
ok("the bank as last opened", (line("Banque:") or ""):match("^Banque: notée le %d+%-%d+%-%d+ %d+:%d+, 1 emplacements libres sur 2$") ~= nil, true)
SlashCmdList.CLAUDEINWOW("Où rendre la Graine de vie ?")
ok("a free question", shown:match("^[^\n]+\n([^\n]+)"), "Question: Où rendre la Graine de vie ?")
ok("its bubble, the question as written", shownLabel, "Où rendre la Graine de vie ?")
ok("without the bags", shown:find("Sacs (", 1, true), nil)
ok("with the quests", shown:find("- 7064 [47] Pourriture et regret", 1, true) ~= nil, true)

-- The assistant's marks: applied from its answer pasted in the Claude window
-- (below), shown on the bags and in tooltips, gone with their item
local opened
local realOpen = ns.OpenClaude
ns.OpenClaude = function(mode) opened = mode or "open" end
local marked = gameSlots[1]
do
    local realID = C_Container.GetContainerItemID
    C_Container.GetContainerItemID = function(bag, slot)
        if bag == SHOWN_BAG then return gameSlots[slot].itemID end
        return realID(bag, slot)
    end
end
ok("no mark on the bags yet", tostring(marked.claudeInWoWMark), "nil")
SlashCmdList.CLAUDEINWOW("Marques")
ok("/claude marques opens the Claude window, waiting for the answer", opened, "paste")
ns.OpenClaude = realOpen
ns.ApplyMarks("Bonjour")
ok("nothing understood: says what to paste", printed[#printed]:find("Aucune marque trouvée", 1, true) ~= nil and char.marks, nil)
local BLOCK = table.concat({
    "[claude-in-wow] marques",
    "vendre 2770 Se vend mieux au marchand",
    "- Détruire 17781 : quête déjà rendue",
    "banque 10504 \226\128\148 pour plus tard",
    "HV 4306",
    "",
    "n'importe quoi 12",
    "garder abc",
}, "\r\n")
local parsed, count, skipped = ns.ParseMarks(BLOCK)
ok("marks read: action, ID, reason", count .. " " .. parsed[2770].action .. " " .. parsed[17781].action .. " " .. parsed[10504].action .. " " .. parsed[4306].action, "4 sell destroy bank auction")
ok("reasons without their colon, dash or list mark", parsed[2770].reason .. " | " .. parsed[17781].reason .. " | " .. parsed[10504].reason .. " | " .. tostring(parsed[4306].reason),
    "Se vend mieux au marchand | quête déjà rendue | pour plus tard | nil")
ok("lines not understood, the header and blanks aside", #skipped .. " " .. skipped[1], "2 n'importe quoi 12")
ns.ApplyMarks(BLOCK)
ok("applied: the character's marks", char.marks[2770].action .. " " .. tostring(char.marks[2770].at ~= nil), "sell true")
ok("says how many, by action", printed[#printed - 1], "|cff4ec9b0claude-in-wow|r 4 marques posées sur vos sacs : 1 pour la banque, 1 pour l'hôtel des ventes, 1 à vendre, 1 à détruire.")
ok("and what was not understood", printed[#printed], "|cff4ec9b0claude-in-wow|r 2 lignes non comprises, par exemple : n'importe quoi 12")
ok("the bags redrawn at once", marked.claudeInWoWMark.texture .. " " .. tostring(marked.claudeInWoWMark.shown), "Interface\\MoneyFrame\\UI-GoldIcon true")
ok("an unmarked slot gets no icon", gameSlots[2].claudeInWoWMark, nil)
marked.itemID = 17781
ContainerFrameCombinedBags:UpdateItems()
ok("the bags drawn first, then the icon", tostring(ContainerFrameCombinedBags.updated) .. " " .. marked.claudeInWoWMark.texture, "true Interface\\Buttons\\UI-GroupLoot-Pass-Up")
marked.itemID = 9999
ContainerFrameCombinedBags:UpdateItems()
ok("an item without mark: icon hidden", marked.claudeInWoWMark.shown, false)
marked.itemID = 2770
local tip = { AddLine = function(self, text, r, g, b, wrap) self.text, self.r, self.wrap = text, r, wrap end }
tooltipPostCall(tip, { id = 17781 })
ok("a line in the item's tooltip", tip.text .. " " .. tip.r .. " " .. tostring(tip.wrap), "|TInterface\\Buttons\\UI-GroupLoot-Pass-Up:14|t À détruire : quête déjà rendue 1 true")
tip.text = nil
tooltipPostCall(tip, { id = 4306 })
ok("a mark without reason", tip.text, "|TInterface\\Minimap\\Tracking\\Auctioneer:14|t À vendre à l'hôtel des ventes")
tip.text = nil
tooltipPostCall(tip, { id = 9999 })
ok("nothing for an unmarked item", tip.text, nil)
ok("the photo carries the marks", ns.Collect({}, { marks = true }).marks, char.marks)
fire("BAG_UPDATE_DELAYED")
ok("marks seen in the bags stay", char.marks[2770] ~= nil, true)
local ore1, ore2 = CONTENTS[0][1], CONTENTS[0][2]
CONTENTS[0][1], CONTENTS[0][2] = false, false
fire("BAG_UPDATE_DELAYED")
ok("an item gone from the bags loses its mark", char.marks[2770], nil)
ok("an item never seen in the bags keeps it", char.marks[4306].action, "auction")
ok("its icon goes too", marked.claudeInWoWMark.shown, false)
CONTENTS[0][1], CONTENTS[0][2] = ore1, ore2

-- Claude's answers as the window reads them
local blocks = ns.Markdown(table.concat({
    "## Ce que je ferais", "", "Tu as **69 places** libres", "sur 108.", "",
    "- vendre le `Bec jaune`", "  et l'oeil", "1. rendre la quête", "> une note", "---",
    "| a | b |", "|---|---|", "| c | d |",
    "```", "[claude-in-wow] marques", "vendre 4590 objet gris", "```", "Un | dans le texte",
}, "\n"))
local kinds = {}
for _, block in ipairs(blocks) do kinds[#kinds + 1] = block.kind end
ok("markdown blocks", table.concat(kinds, " "), "heading para bullet number quote rule row row code para")
ok("a paragraph's lines joined", blocks[2].text, "Tu as **69 places** libres sur 108.")
ok("a list item going on", blocks[3].text, "vendre le `Bec jaune` et l'oeil")
ok("a table row as one line", blocks[7].text, "a  ·  b")
ok("a code block kept as written", blocks[9].text, "[claude-in-wow] marques\nvendre 4590 objet gris")
ok("inline: bold brighter, italics dimmer, code coloured, web links as text, | escaped", ns.MarkdownInline("**Gras** et `co|de` | *pas* [lien](http://x)"),
    "|cffffffffGras|r et |cffe8a88eco||de|r || |cffc2c0b6pas|r lien")

-- links to the game: the game's colours and icons, clickable
C_QuestLog.GetLogIndexForQuestID = function(id) if id == 7029 then return 2 end end
C_QuestLog.IsComplete = function(id) return id == 7029 end
GetQuestDifficultyColor = function(level) return level >= 47 and { r = 1, g = 0.5, b = 0.25 } or { r = 1, g = 1, b = 0 } end
C_Item.GetItemQualityByID = function(id) if id == 2770 then return 1 end end
C_Item.GetItemIconByID = function(id) return id == 2770 and 135232 or 134400 end
local requested = {}
C_Item.RequestLoadItemDataByID = function(id) requested[#requested + 1] = id end
ITEM_QUALITY_COLORS = { [1] = { hex = "|cffffffff" } }
ok("a quest not in the log: yellow, the quest icon", ns.MarkdownInline("[Lard a perdu son déjeuner !](quest:7840)"),
    "|cffffff00|Hciwquest:7840|h|TInterface\\GossipFrame\\AvailableQuestIcon:14:14:0:-1|t Lard a perdu son déjeuner !|h|r")
ok("a quest of the log: its difficulty colour, the turn-in icon once complete", ns.MarkdownInline("**[Corruption de la vallée](quest:7029)**"),
    "|cffffffff|cffff8040|Hciwquest:7029|h|TInterface\\GossipFrame\\ActiveQuestIcon:14:14:0:-1|t Corruption de la vallée|h|r|r")
do -- the game's own title, and the quests handed in
    local keptTitle, keptDone, asked = C_QuestLog.GetTitleForQuestID, C_QuestLog.IsQuestFlaggedCompleted, {}
    C_QuestLog.GetTitleForQuestID = function(id) if id == 5341 then return "Fortune de la famille Barov" end end
    C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 5382 end
    C_QuestLog.RequestLoadQuestByID = function(id) asked[#asked + 1] = id end
    ok("a quest: the game's title, whatever Claude wrote", ns.MarkdownInline("[Barov Family Fortune](quest:5341)"),
        "|cffffff00|Hciwquest:5341|h|TInterface\\GossipFrame\\AvailableQuestIcon:14:14:0:-1|t Fortune de la famille Barov|h|r")
    ok("handed in: dimmed and ticked", ns.MarkdownInline("[Le boucher](quest:5382)"):match("|T(.-):14"), "Interface\\RaidFrame\\ReadyCheck-Ready")
    ns.MarkdownInline("[Le boucher](quest:5382)")
    ok("a title the game has not: asked once", table.concat(asked, " "), "5382")
    C_QuestLog.GetTitleForQuestID, C_QuestLog.IsQuestFlaggedCompleted, C_QuestLog.RequestLoadQuestByID = keptTitle, keptDone, nil
end
ok("an item: its icon and quality colour", ns.MarkdownInline("[Minerai de cuivre](item:2770)"),
    "|cffffffff|Hciwitem:2770|h|T135232:16:16:0:-2:64:64:5:59:5:59|t Minerai de cuivre|h|r")
ns.MarkdownInline("[Longue plume élégante](item:4589)")
ok("an item not known yet: asked for, white until it comes", requested[1] .. " " .. tostring(ns.claudeItemsDue[4589]), "4589 true")
ok("a place: a gold pin", ns.MarkdownInline("[84.5, 41.2](map:1425:84.5:41.2)"),
    "|cffffd100|Hciwmap:1425:84.5:41.2|h|TInterface\\AddOns\\claude-in-wow\\Media\\Claude\\MapPin:14:14:0:-1:32:32:0:32:0:32:255:209:0|t 84.5, 41.2|h|r")
ok("a zone and a creature", ns.MarkdownInline("[Les Hinterlands](zone:1425) et [Lard](npc:14731)"),
    "|cffffd100|Hciwplace:1425:::Les Hinterlands|h" .. ns.PinIcon() .. "Les Hinterlands|h|r et |cffffffff|Hciwnpc:14731|hLard|h|r")
ok("a link with no number: its text", ns.MarkdownInline("[ici](map:abc)"), "ici")

-- The Claude window, from the minimap button
local minimapButton
for _, f in ipairs(frames) do if f.name == "ClaudeInWoWMinimapButton" then minimapButton = f end end
ok("a minimap button", tostring(minimapButton.shown) .. " " .. tostring(db.options.minimapButton) .. " " .. tostring(db.minimap.hide), "true true nil")
ns.SetOption("minimapButton", false)
ok("the setting hides it", tostring(db.minimap.hide) .. " " .. tostring(minimapButton.shown), "true false")
ns.SetOption("minimapButton", true)
ok("and shows it again", tostring(db.minimap.hide) .. " " .. tostring(minimapButton.shown), "nil true")
do -- dragged round the minimap
    local keptCursor = GetCursorPosition
    Minimap.GetCenter = function() return 100, 100 end
    Minimap.GetEffectiveScale = function() return 2 end
    GetCursorPosition = function() return 200, 260 end -- above its middle
    minimapButton.scripts.OnDragStart(minimapButton)
    minimapButton.scripts.OnUpdate(minimapButton)
    minimapButton.scripts.OnDragStop(minimapButton)
    ok("dragged: its place kept", db.minimap.minimapPos .. " " .. tostring(minimapButton.scripts.OnUpdate), "90 nil")
    GetCursorPosition = keptCursor
end
ns.ShowCopy = realShowCopy
char.chat = nil
local windowStart = #frames + 1 -- the window's frames, left out of the photo's tests below
minimapButton.scripts.OnClick(minimapButton, "LeftButton")
local window, input, stripBox
for _, f in ipairs(frames) do
    if f.events.ZONE_CHANGED_NEW_AREA then window = f end
    if f.kind == "EditBox" then
        if input then stripBox = stripBox or f else input = f end
    end
end
local function messages()
    local chat = char.chat
    return chat and chat.tabs and chat.tabs[chat.current] and chat.tabs[chat.current].messages or {}
end
local function findText(start)
    for _, f in ipairs(frames) do
        for _, s in ipairs(f.strings) do
            if type(s.text) == "string" and s.text:sub(1, #start) == start then return s.text end
        end
    end
end
local function findButton(tooltip)
    for _, f in ipairs(frames) do if f.tooltip == tooltip then return f end end
end
ok("a click opens it, the guided tour before the box", tostring(window and window.shown) .. " " .. tostring(input.focused), "true nil")
ok("Escape closes it", UISpecialFrames[1], "ClaudeInWoWWindow")
do -- the guided tour, the first time
    local function chipOf(label) for _, f in ipairs(frames) do if f.label and f.label.text == label and f.scripts.OnClick then return f end end end
    ok("nothing has answered yet: the guided tour", tostring(findText("Bienvenue")) .. " " .. tostring(findText("1 / 8")) .. " " .. tostring(db.tourDone), "Bienvenue 1 / 8 nil")
    local nextStep = chipOf("Suivant")
    nextStep.scripts.OnClick(nextStep)
    ok("the next step, the way back", tostring(findText("D'abord, le plugin")) .. " " .. tostring(findText("Copier /wow-mcp:setup")) .. " " .. tostring(chipOf("Retour").shown), "D'abord, le plugin Copier /wow-mcp:setup true")
    for _ = 1, 6 do nextStep.scripts.OnClick(nextStep) end
    ok("the last one", tostring(findText("8 / 8")) .. " " .. nextStep.label.text, "8 / 8 Terminer")
    nextStep.scripts.OnClick(nextStep)
    ok("done: not again by itself", tostring(db.tourDone) .. " " .. tostring(ns.TourDue()), "true false")
    ns.StartTour(99)
    ok("a step that is not there: the last", findText("8 / 8"), "8 / 8")
    ns.StopTour()
    ns.OpenClaude()
end
do -- the buttons of an empty conversation
    local function labels()
        local list = {}
        for index, shortcut in ipairs(ns.Shortcuts()) do list[index] = shortcut.label end
        return table.concat(list, " | ")
    end
    ok("the first ones", labels(), "Trier mes sacs | Mes quêtes | Que faire à mon niveau | Améliorer mon équipement")
    local asked
    local keptAsk = ns.Ask
    ns.Ask = function(kind, question) asked = kind .. ": " .. tostring(question) end
    ns.Shortcuts()[1].run()
    ok("a click asks its question", asked, "bags: nil")
    ns.EditShortcuts()
    local rows = {}
    for _, f in ipairs(frames) do if f.away and f.up and f.text and f.label then rows[#rows + 1] = f end end
    ok("a row for each, its name and its question", #rows .. " " .. rows[1].label.edit.text .. " | " .. rows[1].text.edit.text, "4 Trier mes sacs | Que faire de tous ces objets ? Lesquels garder sur moi, mettre en banque, vendre ou détruire ?")
    rows[1].text.edit.text = "Que vendre ?"
    rows[1].text.edit.scripts.OnTextChanged(rows[1].text.edit, true)
    rows[1].label.edit.text = "Vendre"
    rows[1].label.edit.scripts.OnTextChanged(rows[1].label.edit, true)
    ns.Shortcuts()[1].run()
    ok("written over: its name and its question", labels() .. " > " .. asked, "Vendre | Mes quêtes | Que faire à mon niveau | Améliorer mon équipement > bags: Que vendre ?")
    ns.Shortcuts()[3].run()
    ok("what to do at one's level", asked, "free: Que faire de mieux à mon niveau en ce moment : zones, quêtes, donjons, métiers ? Donne-moi un ordre.")
    do -- its icon, the player's
        local function icons()
            local list = {}
            for index, one in ipairs(ns.Shortcuts()) do list[index] = tostring(one.icon) end
            return table.concat(list, " ")
        end
        local keptCursor, keptClear, keptItem = GetCursorInfo, ClearCursor, C_Item.GetItemIconByID
        local held = nil
        GetCursorInfo = function() if held then return held[1], held[2] end end
        ClearCursor = function() held = nil end
        C_Item.GetItemIconByID = function(id) return id + 100000 end
        ok("the first icons", icons(), "Bag MapPin Clipboard Check")
        rows[1].icon.scripts.OnClick(rows[1].icon, "LeftButton")
        local box
        for _, f in ipairs(frames) do if f.buttons and f.buttons.none then box = f end end
        ok("a click: those to choose from, none too", tostring(box.shown) .. " " .. tostring(box.buttons.Gear ~= nil), "true true")
        box.buttons.Gear.scripts.OnClick(box.buttons.Gear)
        ok("one chosen", icons() .. " " .. tostring(box.shown), "Gear MapPin Clipboard Check false")
        held = { "item", 4306 }
        rows[2].icon.scripts.OnReceiveDrag(rows[2].icon)
        ok("an item dropped on it: its icon", icons() .. " " .. tostring(held), "Gear 104306 Clipboard Check nil")
        ok("the game's icons are numbers, kept", db.shortcuts[2].icon, 104306)
        rows[3].icon.scripts.OnClick(rows[3].icon, "RightButton")
        ok("a right-click: none", icons() .. " " .. tostring(rows[3].icon.icon.shown), "Gear 104306 nil Check false")
        ns.OpenClaude()
        local chips = {}
        for _, f in ipairs(frames) do if f.shortcut then chips[#chips + 1] = f end end
        ok("on the buttons of an empty conversation too", tostring(chips[3].icon.shown) .. " " .. tostring(chips[2].icon.own), "false true")
        ns.EditShortcuts()
        rows[1].icon.scripts.OnClick(rows[1].icon, "LeftButton")
        box.buttons.Bag.scripts.OnClick(box.buttons.Bag)
        ok("the first one again: nothing to keep", tostring(db.shortcuts[1].icon), "nil")
        db.shortcuts[2].icon, db.shortcuts[3].icon = nil, nil
        GetCursorInfo, ClearCursor, C_Item.GetItemIconByID = keptCursor, keptClear, keptItem
    end
    rows[1].label.edit.text = ""
    rows[1].label.edit.scripts.OnTextChanged(rows[1].label.edit, true)
    ok("emptied: the first name", (labels():match("^[^|]*")), "Trier mes sacs ")
    db.shortcuts[3], db.shortcuts[4] = nil, nil
    rows[1].down.scripts.OnClick(rows[1].down)
    ok("one moved", labels() .. " " .. #db.shortcuts, "Mes quêtes | Trier mes sacs 2")
    rows[1].away.scripts.OnClick(rows[1].away)
    ok("one removed", labels(), "Trier mes sacs")
    local add
    for _, f in ipairs(frames) do if f.label and f.label.text == "Ajouter une question" then add = f end end
    add.scripts.OnClick(add)
    ok("a new one without a question is not shown yet", #db.shortcuts .. " " .. labels(), "2 Trier mes sacs")
    local mine = rows[2]
    mine.text.edit.text = "Où monter ?"
    mine.text.edit.scripts.OnTextChanged(mine.text.edit, true)
    ns.Shortcuts()[2].run()
    ok("then it is, and asks", labels() .. " > " .. asked, "Trier mes sacs | Nouvelle question > free: Où monter ?")
    do -- and in the "+" menu
        local keptMenu, entries = ns.ToggleMenu, nil
        ns.ToggleMenu = function(_, list) entries = list end
        local plusButton
        for _, f in ipairs(frames) do if f.tooltip == ns.L.MORE then plusButton = f end end
        plusButton.scripts.OnClick(plusButton)
        rows[2].menu.scripts.OnClick(rows[2].menu)
        local kept = entries
        plusButton.scripts.OnClick(plusButton)
        ok("one kept out of the menu, as the player chose", kept[2].label .. " / " .. entries[2].label .. " / " .. labels() .. " " .. tostring(db.shortcuts[2].menu), "Nouvelle question / Modifier ces questions / Trier mes sacs | Nouvelle question false")
        rows[2].menu.scripts.OnClick(rows[2].menu)
        plusButton.scripts.OnClick(plusButton)
        ok("in it again", entries[2].label .. " " .. tostring(db.shortcuts[2].menu), "Nouvelle question nil")
        ns.SetOption("shortcutsEdit", false)
        plusButton.scripts.OnClick(plusButton)
        ok("without the way to change them, as the player chose", entries[3].label, "Effacer les marques")
        ns.SetOption("shortcutsEdit", true)
        plusButton.scripts.OnClick(plusButton)
        ns.ToggleMenu = keptMenu
        local said = {}
        for index, entry in ipairs(entries) do said[index] = entry.label end
        entries[2].run()
        ok("in the menu too, then the way to change them", table.concat(said, " | ") .. " > " .. asked, "Trier mes sacs | Nouvelle question | Modifier ces questions | Effacer les marques > free: Où monter ?")
    end
    for _ = 1, 20 do add.scripts.OnClick(add) end
    ok("so many at most", #db.shortcuts, 12)
    local reset
    for _, f in ipairs(frames) do if f.label and f.label.text == "Remettre ceux par défaut" then reset = f end end
    reset.scripts.OnClick(reset)
    ok("the first ones back: at the second click", reset.label.text .. " " .. #db.shortcuts, "Cliquez encore : les vôtres sont perdus 12")
    reset.scripts.OnClick(reset)
    ok("they are back", labels() .. " " .. tostring(db.shortcuts), "Trier mes sacs | Mes quêtes | Que faire à mon niveau | Améliorer mon équipement nil")
    ns.Ask = keptAsk
    db.settingsTab = nil
    ns.OpenClaude()
end
ok("an empty conversation greets, by the whole name in the class' colour", (findText("Bon") or ""):match(", (.*)$"), ns.ClassCode(select(2, UnitClass("player"))) .. "Arden Valcourt|r")
local function findBar(key)
    for _, f in ipairs(frames) do if f.spec and f.spec.key == key then return f end end
end
local function bare(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "po")) end
do -- the character, the server and the layer
    local bar, keptInside, keptRealm = findBar("barCharacter"), IsInInstance, realmName
    local guids = { mouseover = "Creature-0-5842-1-213-3296-00001A2B3C", target = "Creature-0-5842-1-77-3296-00001A2B3C" }
    local controlled = false
    local keptExists, keptGuid, keptControlled = UnitExists, UnitGUID, UnitPlayerControlled
    local keptHardcore, keptZone, keptPvp, keptDesired, keptTimer, keptTaxi, keptDead, keptRegion = C_GameRules, GetZonePVPInfo, UnitIsPVP, GetPVPDesired, IsPVPTimerRunning, UnitOnTaxi, UnitIsDeadOrGhost, GetCurrentRegionName
    local zoneKind, flagged, desired, hardcore = "friendly", false, false, false
    C_GameRules = { IsHardcoreActive = function() return hardcore end }
    GetZonePVPInfo = function() return zoneKind end
    UnitIsPVP = function() return flagged end
    GetPVPDesired = function() return desired end
    IsPVPTimerRunning = function() return false end
    UnitOnTaxi, UnitIsDeadOrGhost = function() return false end, function() return false end
    GetCurrentRegionName = function() return "EU" end
    UnitExists = function(unit) return guids[unit] ~= nil end
    UnitGUID = function(unit) return guids[unit] end
    UnitPlayerControlled = function() return controlled end
    bar.IsVisible = function() return true end
    fire("UPDATE_MOUSEOVER_UNIT")
    ok("in an instance: the character and its zone, no layer", bare(bar.left.text) .. " / " .. bar.right.text, "Arden Valcourt 44  ·  Maraudon / " .. realmName)
    IsInInstance = function() return false, "none" end
    realmName = ""
    ns.OpenClaude()
    ok("no creature seen yet: the layer is not known", bar.right.text, "Serveur EU  ·  Layer ?")
    fire("UPDATE_MOUSEOVER_UNIT")
    ok("a creature under the mouse: the server and the layer", bar.right.text, "Serveur EU  ·  Layer 213")
    fire("PLAYER_TARGET_CHANGED")
    ok("one targeted, on another layer", bar.right.text, "Serveur EU  ·  Layer 77")
    guids.target = "Player-3676-0A1B2C3D"
    fire("PLAYER_TARGET_CHANGED")
    ok("a player says nothing of it", bar.right.text, "Serveur EU  ·  Layer 77")
    controlled = true
    fire("UPDATE_MOUSEOVER_UNIT")
    ok("nor a player's pet", bar.right.text, "Serveur EU  ·  Layer 77")
    controlled = false
    fire("PLAYER_ENTERING_WORLD", false, true)
    ok("after a reload: still known", bar.right.text, "Serveur EU  ·  Layer 77")
    fire("ZONE_CHANGED_NEW_AREA")
    ok("in another zone: to be read again", bar.right.text, "Serveur EU  ·  Layer ?")
    zoneKind, flagged, desired = "contested", true, true
    clock = clock + 2
    fire("UPDATE_MOUSEOVER_UNIT")
    ok("just come in a contested zone: not sure yet", bar.right.text, "Serveur EU  ·  Layer 213")
    clock = clock + 20
    fire("UPDATE_MOUSEOVER_UNIT")
    ok("flagged as you asked for: nothing sure", bar.right.text, "Serveur EU  ·  Layer 213")
    flagged = false
    fire("UPDATE_MOUSEOVER_UNIT")
    ok("not flagged in a contested zone: a normal server", bar.right.text, "Serveur EU Normal  ·  Layer 213")
    flagged, desired = true, false
    fire("UPDATE_MOUSEOVER_UNIT")
    ok("flagged there by itself: a PVP one", bar.right.text, "Serveur EU PVP  ·  Layer 213")
    hardcore = true
    fire("UPDATE_MOUSEOVER_UNIT")
    ok("a hardcore one", bar.right.text, "Serveur EU Hardcore  ·  Layer 213")
    hardcore, flagged = false, false
    fire("UPDATE_MOUSEOVER_UNIT")
    fire("UPDATE_MOUSEOVER_UNIT")
    fire("SHARD_TRANSFER")
    ok("moved to another layer: to be read again", bar.right.text, "Serveur EU Normal  ·  Layer ?")
    realmName = "Sulfuron"
    fire("UPDATE_MOUSEOVER_UNIT")
    ok("a realm's own name", bar.right.text, "Sulfuron  ·  Layer 213")
    fire("UPDATE_MOUSEOVER_UNIT")
    C_GameRules, GetZonePVPInfo, UnitIsPVP, GetPVPDesired, IsPVPTimerRunning, UnitOnTaxi, UnitIsDeadOrGhost, GetCurrentRegionName = keptHardcore, keptZone, keptPvp, keptDesired, keptTimer, keptTaxi, keptDead, keptRegion
    UnitExists, UnitGUID, UnitPlayerControlled, IsInInstance, realmName = keptExists, keptGuid, keptControlled, keptInside, keptRealm
    ns.char.world = nil
    ns.OpenClaude()
end
ok("no session yet, no tokens", findBar("barSession").left.text .. " / " .. bare(findBar("barSession").right.text), "Pas encore de session / Addon : 0")

do -- the box keeps its width and its anchors, whatever the layout goes through
    local area
    for _, f in ipairs(frames) do if not area and f ~= input and f.scripts.OnSizeChanged and f.scripts.OnMouseDown then area = f end end
    input.width = 396
    area.scripts.OnSizeChanged(area, 0, 0)
    ok("the box you write in is never without a width", input.width, 396)
    area.scripts.OnSizeChanged(area, 400, 22)
    ok("it follows its frame's", input.width, 400)
    local before = #timers
    input.scripts.OnSizeChanged(input)
    input.scripts.OnSizeChanged(input)
    ok("laid out once, after the game's own layout", #timers - before, 1)
    timers[#timers]()
end

-- a question written and sent: it goes in a photo
local realTakePhoto, photoQuestion, photoDone = ns.TakePhoto, nil, nil
ns.TakePhoto = function(question, done) photoQuestion, photoDone = question, done return true end
input:SetText("Où est le féticheur Ti'ik ?")
input.scripts.OnEnterPressed(input)
local sentByPhoto = messages()[1]
ok("your question in the conversation, sent in a photo", sentByPhoto.role .. " | " .. sentByPhoto.text .. " | " .. sentByPhoto.state, "you | Où est le féticheur Ti'ik ? | sending")
ok("the photo carries it", photoQuestion.kind .. " | " .. photoQuestion.text .. " | " .. tostring(photoQuestion.at == sentByPhoto.at), "free | Où est le féticheur Ti'ik ? | true")
ok("nothing to copy", tostring(stripBox.focused), "nil")
ok("the box emptied", input.text, "")
ok("the next step: waiting for the photo", tostring(findText("Envoi de votre question")), "Envoi de votre question…")
ok("the photo knows its conversation", photoQuestion.tab .. " | " .. tostring(photoQuestion.newSession), "Où est le féticheur Ti'ik ? | nil")
photoDone(true)
ok("sent once the photo is taken", sentByPhoto.state .. " | " .. tostring(findText("Envoyée à Claude")), "sent | Envoyée à Claude (cliquez pour la copier plutôt)")
ok("the next step: paste at the sound", tostring(findText("Au son")), "Au son, collez la réponse (Ctrl+V)")
ok("Claude at work, with the time it has taken", findText("Claude réfléchit"), "Claude réfléchit : 0 s (d'habitude environ 20 s)")
db.options.soundReady = false
ns.RenderClaude()
ok("without the sound: paste the answer", tostring(findText("Coller la réponse")), "Coller la réponse de Claude (Ctrl+V)")
db.options.soundReady = true
ns.RenderClaude()
sentByPhoto.sentAt = sentByPhoto.sentAt - 60
local nextStep
for _, f in ipairs(frames) do if f.run and f.SetIcon then nextStep = f end end
input.focused = false
nextStep.scripts.OnClick(nextStep)
ok("its button puts the cursor in the box", input.focused, true)

-- the answer carries the question it is for: the wrong one is refused
local function paste(text)
    input.text = text
    input.scripts.OnTextChanged(input, true)
end
paste("[claude-in-wow réponse 999]\n\nUne réponse pour une tout autre question, longue")
ok("an answer for another question is refused", #messages() .. " " .. tostring(findText("Cette réponse est pour")), "1 Cette réponse est pour une autre question")
paste("[claude-in-wow réponse " .. sentByPhoto.at .. " session=abcd1234 n=3 s=38 m=opus-5.5 c=71 t=107901 r=90052 p=5h:30:1795567200 l=fr]\n\nRéponse **juste**, à la bonne question")
ok("the language Claude speaks, in the answer's mark", db.claudeLanguage, "fr")
ok("the plan, in the answer's mark", db.claudePlan.windows[1].window .. " " .. db.claudePlan.windows[1].percent .. " " .. db.claudePlan.windows[1].resets, "5h 30 1795567200")
db.claudePlan = nil
ok("the right one is taken, its mark out of it", #messages() .. " " .. messages()[2].text .. " " .. tostring(sentByPhoto.answered), "2 Réponse **juste**, à la bonne question true")
ok("what its mark says of Claude's session", db.claudeStatus.session .. " " .. db.claudeStatus.questions .. " " .. db.claudeStatus.seconds, "abcd1234 3 38")
ok("the model that answered and the tokens it took, under the answer", ns.AnswerNote(messages()[2]), "Opus 5.5  ·  107 901 jetons (dont 90 052 en cache)")
ok("its tokens noted", #db.usage.list .. " " .. db.usage.list[1].tokens .. " " .. db.usage.list[1].cached .. " " .. db.usage.list[1].model .. " " .. tostring(db.usage.list[1].seconds) .. " " .. db.usage.list[1].who,
    "1 107901 90052 opus-5.5 38 Arden Valcourt")
ok("the session and today's tokens under the box", bare(findBar("barSession").left.text) .. " / " .. bare(findBar("barSession").right.text), "Session : 3 questions  ·  71 k en mémoire / Addon : 108 k")
ok("the model by the button that sends", ns.ChoiceLabel("model"), "Opus 5.5")
ok("figures grouped, whatever their length", ns.AnswerNote({ model = "haiku-5.5", tokens = 1234567 }) .. " | " .. ns.AnswerNote({ model = "haiku-5.5", tokens = 950, effort = "xhigh" }),
    "Haiku 5.5  ·  1 234 567 jetons | Haiku 5.5  ·  effort : Très élevé  ·  950 jetons")
do -- where the tokens went
    local kept, shown = GameTooltip.AddDoubleLine, {}
    GameTooltip.AddDoubleLine = function(_, left, right) shown[#shown + 1] = left .. "=" .. right end
    ns.ShowAnswerDetail(UIParent, { tokens = 30000, cached = 5000, detail = { 8000, 4000, 2000, 15000, 1000, 3 } })
    ok("where the tokens went", table.concat(shown, " | "), "Départ d'une session : consigne, outils, noms=8 000 | Les questions d'avant, dans la session=4 000 | La question et ce qui est lu pour elle=2 000"
        .. " | Recherches : 2 de plus, tout relu à chacune=15 000 | La réponse, réflexion comprise=1 000")
    GameTooltip.AddDoubleLine = kept
end
ok("an answer that does not say: nothing under it", tostring(ns.AnswerNote({ text = "x" })), "nil")
ok("how long it took is noted, as the silent mode says", #db.answerTimes.free .. " " .. db.answerTimes.free[1], "1 38")
paste("[claude-in-wow réponse " .. sentByPhoto.at .. "]\n\nRéponse **juste**, à la bonne question")
ok("the same one twice is refused", #messages() .. " " .. tostring(findText("Cette réponse est déjà")), "2 Cette réponse est déjà collée")

-- while a question waits, a paste with no mark is refused once, then taken
ns.TakePhoto = function(question, done) photoQuestion, photoDone = question, done return true end
input:SetText("Et mes sacs ?")
input.scripts.OnEnterPressed(input)
photoDone(true)
paste("Une vieille réponse longue qui traînait dans le presse-papiers")
ok("a paste with no mark while a question waits: refused once", #messages() .. " " .. tostring(findText("Recollez")), "3 Recollez-la pour l'accepter comme réponse")
paste("Une vieille réponse longue qui traînait dans le presse-papiers")
ok("pasted again: taken", #messages(), 4)

-- no photo possible (in combat): its text to copy instead
ns.TakePhoto = function() return false end
input:SetText("Où est le féticheur Ti'ik ?")
input.scripts.OnEnterPressed(input)
local asked = messages()[#messages()]
ok("no photo: the question to copy", asked.state, "copy")
ok("its full text selected to copy", stripBox.text:match("^[^\n]+") .. " " .. tostring(stripBox.focused) .. " " .. tostring(stripBox.highlighted),
    "[claude-in-wow 1.0.0] free true true")
ns.TakePhoto = realTakePhoto
stripBox.text = "abc"
stripBox.scripts.OnTextChanged(stripBox, true)
ok("the text to copy cannot be changed", stripBox.text:match("^[^\n]+"), "[claude-in-wow 1.0.0] free")
IsControlKeyDown = function() return true end
stripBox.scripts.OnKeyDown(stripBox, "C")
IsControlKeyDown = function() return false end
timers[#timers]()
ok("Ctrl+C: copied, the box waits for the answer", asked.state .. " " .. tostring(stripBox.focused) .. " " .. tostring(input.focused), "copied false true")
ok("the box asks for the answer", findText("Collez la réponse"), "Collez la réponse de Claude ici (Ctrl+V)")

-- the model to ask, picked by the button that sends
local picker, effortPicker, pickedItem
for _, f in ipairs(frames) do
    if f.arrow and f.menuRight and not effortPicker then effortPicker = f
    elseif f.arrow and f.menuRight and not picker then picker = f end
end
picker.scripts.OnClick(picker)
ok("the model's menu: the default by its name", findText("Celui de Claude Code"), "Celui de Claude Code : Opus 5.5")
for _, f in ipairs(frames) do if f.detail and f.label and f.label.text == "Sonnet" then pickedItem = f end end
pickedItem.scripts.OnClick(pickedItem)
ok("a model picked: kept, and on the button", db.options.model .. " " .. picker.label.text, "sonnet Sonnet")
local effortBefore = effortPicker.label.text
effortPicker.scripts.OnClick(effortPicker)
for _, f in ipairs(frames) do if f.detail and f.label and f.label.text == "Élevé" then pickedItem = f end end
pickedItem.scripts.OnClick(pickedItem)
ok("an effort picked too", effortBefore .. " " .. db.options.effort .. " " .. effortPicker.label.text, "Effort high Élevé")
ns.TakePhoto = function(question, done) photoQuestion, photoDone = question, done return true end
db.options.parallel = false
input:SetText("Avec Sonnet ?")
input.scripts.OnEnterPressed(input)
photoDone(true)
ok("the question says the model, its effort and how to answer", photoQuestion.model .. " " .. photoQuestion.effort .. " " .. tostring(photoQuestion.options.renew)
    .. " " .. tostring(photoQuestion.options.parallel) .. " " .. tostring(photoQuestion.options.soundStart) .. " " .. tostring(photoQuestion.options.soundReady),
    "sonnet high true false false true")
ok("as soon as it is sent, the button says to paste at the sound", findText("Au son"), "Au son, collez la réponse (Ctrl+V)")
paste("[claude-in-wow réponse " .. photoQuestion.at .. " session=abcd1234 n=1 s=9 m=sonnet-5.5 c=40]\n\nRéponse de Sonnet, à la question posée à Sonnet")
ok("its version learnt, the default's kept", ns.ChoiceLabel("model") .. " " .. db.claudeDefaultModel, "Sonnet 5.5 opus-5.5")
ok("its effort noted under the answer", ns.AnswerNote(messages()[#messages()]), "Sonnet 5.5  ·  effort : Élevé")
db.options.parallel = true
db.options.model, db.options.effort = "default", "default"
input:SetText("Par défaut ?")
input.scripts.OnEnterPressed(input)
ok("the default: no model asked, nor effort", tostring(photoQuestion.model) .. " " .. tostring(photoQuestion.effort) .. " " .. tostring(photoQuestion.options.parallel), "nil nil true")
photoDone(true)
paste("[claude-in-wow réponse " .. photoQuestion.at .. "]\n\nRéponse sans rien d'autre dans sa marque")
-- sent by photo, or copied as the settings say
local photosAsked = 0
ns.TakePhoto = function() photosAsked = photosAsked + 1 return true end
db.options.sendByPhoto = false
input:SetText("Sans photo ?")
input.scripts.OnEnterPressed(input)
ok("no photo when the player prefers to copy", photosAsked .. " " .. messages()[#messages()].state, "0 copy")
db.options.sendByPhoto = true
ns.TakePhoto = realTakePhoto

-- typing is not an answer, a paste is
local lettersBefore = #messages()
input.text = "a"
input.scripts.OnTextChanged(input, true)
ok("a letter typed stays in the box", (#messages() - lettersBefore) .. " " .. input.text, "0 a")
input:SetText("")
do -- a text pasted to ask with: it stays in the box, to go on writing
    findButton("Nouvelle conversation").scripts.OnClick(findButton("Nouvelle conversation"))
    local before, own = #messages(), "Voici mon macro, pourquoi ne marche-t-elle pas : /cast [mod] Bouclier de givre ; Armure de glace"
    input.text = own
    input.scripts.OnTextChanged(input, true)
    ok("a text pasted stays in the box, nothing is sent", (#messages() - before) .. " " .. input.text, "0 " .. own)
    local keptPhoto, sent = ns.TakePhoto, nil
    ns.TakePhoto = function(question) sent = question return true end
    input.text = "Que fait a || b ?"
    input.scripts.OnEnterPressed(input)
    ok("sent at Enter only, its \"|\" as it was typed", sent and sent.text, "Que fait a | b ?")
    ns.TakePhoto = keptPhoto
    messages()[#messages()].answered = true
    ns.OpenClaude("paste")
    input.text = "Une réponse copiée de l'application, sans marque, assez longue"
    input.scripts.OnTextChanged(input, true)
    ok("waited for (Coller une réponse): taken as the answer", messages()[#messages()].role, "claude")
end
local ANSWER = table.concat({
    "Voici ce que je ferais.", "", "- **Vendre** le Minerai de cuivre", "", "```",
    "[claude-in-wow] marques", "vendre 2770 se vend mieux au marchand", "hv 4306 bon prix", "```",
}, "\n")
input.text = ANSWER
input.scripts.OnTextChanged(input, true)
local answer = messages()[#messages()]
ok("a paste is Claude's answer", answer.role .. " " .. tostring(answer.text == ANSWER) .. " " .. input.text, "claude true ")
ok("its marks block found", select(2, ns.MarksBlock(answer.text)), 2)
ok("prose is never read as marks", ns.MarksBlock("- vendre 3 plumes"), nil)
local chip
for _, f in ipairs(frames) do if f.message == answer and f.block then chip = f end end
ok("a button to put its marks on the bags", chip and chip.label.text, "Afficher sur mes sacs (2 objets)")
local earlierMarks = char.marks -- back after the window's tests
char.marks = nil
chip.scripts.OnClick(chip)
ok("the button applies them", tostring(answer.applied) .. " " .. char.marks[2770].action .. " " .. char.marks[4306].action, "true sell auction")
ok("then takes them off", chip.label.text, "Enlever les marques")
do -- bags another addon draws: slots of the game's template, found by their numbers
    local function Other(bag, slot, texture, where)
        local made = Slot(0)
        made.NewItemTexture, made.BattlepayItemTexture, made.flash = {}, {}, {}
        made.GetID = function() return slot end
        made.SetID, made.HookScript = noop, noop
        made.icon = { GetTexture = function() return texture end }
        if where == "own" then made.GetBagID = function() return bag end else made.GetParent = function() return { GetID = function() return bag end } end end
        return made
    end
    local keptInfo, keptID, keptEnumerate = C_Container.GetContainerItemInfo, C_Container.GetContainerItemID, EnumerateFrames
    local HELD = { [80] = { 2770, 9999 }, [81] = { 4306 } }
    C_Container.GetContainerItemID = function(bag, slot) if HELD[bag] then return HELD[bag][slot] end return keptID(bag, slot) end
    C_Container.GetContainerItemInfo = function(bag, slot) if HELD[bag] then return HELD[bag][slot] and { iconFileID = HELD[bag][slot] } end return keptInfo and keptInfo(bag, slot) end
    local list = { { IsForbidden = function() return true end }, {}, Other(80, 1, 2770), Other(80, 2, 9999), Other(81, 1, 4306, "own"), Other(80, 1, 12345) }
    EnumerateFrames = function(after)
        if not after then return list[1] end
        for index, frame in ipairs(list) do if frame == after then return list[index + 1] end end
    end
    local function shown(index) local mark = list[index].claudeInWoWMark return tostring(mark and mark.shown or false) end
    chip.scripts.OnClick(chip)
    ok("taken off: no mark left", tostring(char.marks) .. " " .. chip.label.text, "nil Afficher sur mes sacs (2 objets)")
    chip.scripts.OnClick(chip)
    ok("on any bags: the marked items, by their parent's or their own numbers", shown(3) .. " " .. shown(4) .. " " .. shown(5), "true false true")
    ok("not on a slot that shows something else", shown(6), "false")
    HELD[80][1], HELD[80][2] = 9999, 2770
    list[3].icon.GetTexture, list[4].icon.GetTexture = function() return 9999 end, function() return 2770 end
    for _, f in ipairs(frames) do if f.events.BAG_UPDATE_DELAYED and f.scripts.OnEvent then f.scripts.OnEvent(f, "BAG_UPDATE_DELAYED") end end
    ok("items moved: the marks follow", shown(3) .. " " .. shown(4), "false true")
    chip.scripts.OnClick(chip)
    ok("taken off every bag", shown(4) .. " " .. shown(5), "false false")
    chip.scripts.OnClick(chip)
    EnumerateFrames, C_Container.GetContainerItemInfo, C_Container.GetContainerItemID = keptEnumerate, keptInfo, keptID
end

-- a marks block pasted alone shows as code
input.text = "[claude-in-wow] marques\nvendre 2770 se vend mieux au marchand\ngarder 4306"
input.scripts.OnTextChanged(input, true)
ok("a block pasted alone, as code", messages()[#messages()].text:sub(1, 4), "```\n")

-- the "+" menu offers the same actions, and clearing the marks
findButton("Demander…").scripts.OnClick(findButton("Demander…"))
ok("the + menu's last entry clears the marks", findText("Effacer les marques"), "Effacer les marques")

-- a click on a place: a pin there, followed, and the map; in combat, the pin only
local pins, superTracked, mapsOpened = {}, nil, {}
UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { map = map, x = x, y = y } end }
C_Map.CanSetUserWaypointOnMap = function() return true end
C_Map.SetUserWaypoint = function(point) pins[#pins + 1] = point return true end
C_Map.OpenWorldMap = function(map) mapsOpened[#mapsOpened + 1] = map end
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) superTracked = on end }
IsModifiedClick = function() return false end
local linked
for _, f in ipairs(frames) do if f.scripts.OnHyperlinkClick then linked = f end end
linked.scripts.OnHyperlinkClick(linked, "ciwmap:1425:84.5:41.2", "84.5, 41.2", "LeftButton")
ok("a place clicked: pinned, followed, its map open", string.format("%d %.3f %.3f %s %d", pins[1].map, pins[1].x, pins[1].y, tostring(superTracked), mapsOpened[1]),
    "1425 0.845 0.412 true 1425")
inCombat = true
linked.scripts.OnHyperlinkClick(linked, "ciwzone:1425", "Les Hinterlands", "LeftButton")
inCombat = false
ok("in combat: no map, says so", #mapsOpened .. " " .. tostring(printed[#printed]:find("hors combat", 1, true) ~= nil), "1 true")
-- an item a link waited for: the window drawn again once it comes
fire("ITEM_DATA_LOAD_RESULT", 4589, true)
ok("an item that came: no longer waited for, a redraw due", tostring(ns.claudeItemsDue[4589]), "nil")

-- tabs: each conversation on its own; an answer goes to the one it is for
local plusTab = findButton("Nouvelle conversation")
local tabsBefore = #char.chat.tabs
plusTab.scripts.OnClick(plusTab)
ok("the + opens a new conversation", #char.chat.tabs .. " " .. #messages(), (tabsBefore + 1) .. " 0")
local keptTakePhoto = ns.TakePhoto
ns.TakePhoto = function(question, done) photoQuestion, photoDone = question, done return true end
input:SetText("Où vendre le mithril ?")
input.scripts.OnEnterPressed(input)
local inTab2 = messages()[1]
photoDone(true)
ns.TakePhoto = keptTakePhoto
local tabButtons = {}
for _, f in ipairs(frames) do if f.index and f.close then tabButtons[f.index] = f end end
tabButtons[1].scripts.OnClick(tabButtons[1])
ok("a tab shows its own conversation", char.chat.current .. " " .. tostring(messages()[1] ~= inTab2), "1 true")
paste("[claude-in-wow réponse " .. inTab2.at .. " session=abcd1234 n=4 s=12]\n\nÀ l'hôtel des ventes, environ 12s pièce")
ok("an answer for another tab goes to it, and shows it", char.chat.current .. " " .. messages()[2].text, (tabsBefore + 1) .. " À l'hôtel des ventes, environ 12s pièce")
local closing, firstMessage = #char.chat.tabs, char.chat.tabs[1].messages[1]
tabButtons[char.chat.current].close.scripts.OnClick(tabButtons[char.chat.current].close)
local closedToo = false
for _, at in ipairs(char.chat.done) do if at == inTab2.at then closedToo = true end end
ok("the answers of a closed tab are no longer wanted", closedToo, true)
ok("a tab closed, the others kept", (closing - #char.chat.tabs) .. " " .. tostring(char.chat.tabs[1].messages[1] == firstMessage), "1 true")

-- two questions at once, in two tabs: each answer goes to its own, in one paste
ns.TakePhoto = function(question, done) photoQuestion, photoDone = question, done return true end
plusTab.scripts.OnClick(plusTab)
input:SetText("Question A ?")
input.scripts.OnEnterPressed(input)
photoDone(true)
local tabA, questionA = char.chat.current, messages()[1]
plusTab.scripts.OnClick(plusTab)
input:SetText("Question B ?")
input.scripts.OnEnterPressed(input)
photoDone(true)
local tabB, questionB = char.chat.current, messages()[1]
ok("both are thought about, each on its own", (findText("Claude réfléchit") or ""):match("^Claude réfléchit : %d+ s %(d'habitude environ %d+ s%)$") ~= nil, true)
local busyTab
for _, f in ipairs(frames) do if f.index == tabB and f.close then busyTab = f end end
ok("a dot on the tab where Claude is at work", busyTab.dot.shown, true)
local bundle = "[claude-in-wow réponse " .. questionA.at .. " session=abcd1234 n=5 s=10]\n\nRéponse A, à la question A\n\n[claude-in-wow réponse " .. questionB.at .. " session=abcd1234 n=6 s=11 m=opus-5.5 c=72]\n\nRéponse B, à la question B"
paste(bundle)
ok("one paste, each answer to its own tab", char.chat.tabs[tabA].messages[2].text .. " | " .. char.chat.tabs[tabB].messages[2].text .. " | " .. char.chat.current, "Réponse A, à la question A | Réponse B, à la question B | " .. tabB)
ok("the last one counts for the session", db.claudeStatus.questions, 6)
paste(bundle)
ok("the same bundle again is refused", tostring(findText("Cette réponse est déjà")), "Cette réponse est déjà collée")
input:SetText("Question C ?")
input.scripts.OnEnterPressed(input)
local gotA, gotB = false, false
for _, at in ipairs(photoQuestion.got) do
    if at == questionA.at then gotA = true end
    if at == questionB.at then gotB = true end
end
ok("the next question says which answers are here", tostring(gotA) .. " " .. tostring(gotB), "true true")
photoDone(true)
paste("[claude-in-wow réponse " .. messages()[#messages()].at .. "]\n\nRéponse C, à la question C")
ns.TakePhoto = keptTakePhoto

-- the answers that come by themselves: a signal (a sound file that goes on
-- playing once filled) and a slot (an addon loaded on demand), for each question
local playing, soundOn, slots, loadedSlots, heardNames = {}, true, {}, {}, {}
PlaySoundFile = function(file, channel)
    local name = file:match("^Interface\\AddOns\\claude%-in%-wow\\Inbox\\(%w+)%.wav$")
    if not soundOn or not name or channel ~= "Master" then return nil end
    heardNames[#heardNames + 1] = name
    return true, #heardNames -- as the game does, empty or not
end
C_Sound = { IsPlaying = function(handle) return playing[heardNames[handle]] or false end }
C_AddOns.IsAddOnLoaded = function(name) return loadedSlots[name] or false end
C_AddOns.IsAddOnLoadable = function(name, _, onDemand) return onDemand and name:match("^claude%-in%-wow_S%d%d%d$") ~= nil end
local found = 30 -- how many slots the game has found
C_AddOns.DoesAddOnExist = function(name) return (tonumber(name:match("^claude%-in%-wow_S(%d%d%d)$")) or 999) <= found end
C_AddOns.LoadAddOn = function(name)
    if slots[name] == nil then return nil, "DISABLED" end
    loadedSlots[name] = true
    ClaudeInWoWInbox = slots[name]
    return true
end
ns.TakePhoto = function(question, done) photoQuestion, photoDone = question, done return true end
local function ask(text)
    plusTab.scripts.OnClick(plusTab)
    input:SetText(text)
    input.scripts.OnEnterPressed(input)
    photoDone(true)
    local message = messages()[1]
    message.sentAt = message.sentAt - 5 -- five seconds ago
    return message, char.chat.current
end
local before = #tickers
local function look() -- the second's look, and the moment after it
    local timersBefore = #timers
    for index = before + 1, #tickers do if not tickers[index].cancelled then tickers[index].fn() end end
    for index = timersBefore + 1, #timers do timers[index]() end
end
local function slotName(number) return string.format("claude-in-wow_S%03d", number) end
ok("a hundred by default", db.options.slots, 100)
db.options.slots = 30 -- for what follows
local first, firstTab = ask("Arrive seule ?")
ok("a question takes a signal and a slot with it", photoQuestion.signal .. " " .. photoQuestion.slot, "1 1")
ok("it says how many slots the player wants", photoQuestion.options.slots, 30)
ok("the button says the answer comes by itself", findText("La réponse arrive seule"), "La réponse arrive seule (sinon, collez : Ctrl+V)")
local looking
for index = before + 1, #tickers do looking = looking or tickers[index] end
local second, secondTab = ask("Et celle-ci ?")
ok("the next question takes the next ones", photoQuestion.signal .. " " .. photoQuestion.slot, "2 2")
look()
ok("empty sounds: both wait", tostring(first.answered) .. " " .. tostring(second.answered) .. " " .. tostring(first.ready), "nil nil nil")
do -- whether somebody received them
    first.sentAt, second.sentAt = first.sentAt - 20, second.sentAt - 20
    look()
    ok("nobody received it: said, with what to do", tostring(findText("Claude n'a pas reçu cette question") ~= nil) .. " " .. tostring(findText("Que faire")), "true Que faire")
    local keptTab = db.settingsTab
    nextStep.scripts.OnClick(nextStep)
    ok("the help opens, says it", db.settingsTab .. " " .. tostring(findText("Votre dernière question n'a pas été reçue") ~= nil), "help true")
    db.settingsTab = keptTab
    ns.OpenClaude()
    playing["a002"] = true
    look()
    ok("received after all: Claude at work", tostring(second.received) .. " " .. tostring(ns.Unheard(second)) .. " " .. tostring(ns.Unheard(first)) .. " " .. tostring(findText("La réponse arrive seule") ~= nil), "true false true true")
    playing["a001"] = true
    look()
    ok("both were", tostring(first.received), "true")
    first.sentAt, second.sentAt = first.sentAt + 20, second.sentAt + 20
end
slots[slotName(1)] = "[claude-in-wow réponse " .. first.at .. " session=abcd1234 n=7 s=5 m=haiku-5.5 c=30 t=1500 r=900]\n\nUne réponse venue seule"
playing["001"] = true
look()
ok("its signal heard: the answer is in its conversation", tostring(first.answered) .. " " .. char.chat.tabs[firstTab].messages[2].text, "true Une réponse venue seule")
ok("the conversation shown stays, a dot on the other", char.chat.current .. " " .. tostring(char.chat.tabs[firstTab].unread) .. " " .. tostring(second.answered), secondTab .. " true nil")
ok("its slot's text gone", tostring(loadedSlots[slotName(1)]) .. " " .. tostring(ClaudeInWoWInbox), "true nil")
playing["002"] = true -- its slot cannot be loaded
look()
ok("no slot: ready, to paste", tostring(second.ready) .. " " .. tostring(second.answered) .. " | " .. tostring(findText("Réponse prête")) .. " | " .. tostring(findText("La réponse est prête")),
    "true nil | Réponse prête : collez-la (Ctrl+V) | La réponse est prête")
look()
ok("nothing waits: nothing is listened to any more", tostring(looking.cancelled), "true")
slots[slotName(2)] = "[claude-in-wow réponse " .. second.at .. "]\n\nAprès un reload, la réponse"
ns.ResumeAnswers()
ok("after a /reload, its slot is read again", tostring(second.answered) .. " " .. messages()[2].text, "true Après un reload, la réponse")
for _, f in ipairs(frames) do if f.index == firstTab and f.close then f.scripts.OnClick(f) end end
ok("its conversation shown: seen", tostring(char.chat.tabs[firstTab].unread), "nil")
playing["003"] = true -- still heard from an earlier question
local third = ask("La suivante ?")
third.sentAt = third.sentAt + 5
look()
ok("a signal heard at once was an earlier one's: the answer is to paste", tostring(third.signal) .. " " .. tostring(third.ready) .. " " .. tostring(findText("Au son")), "nil nil Au son, collez la réponse (Ctrl+V)")
local fourth = ask("Collée avant ?")
ok("a slot read already is not taken", photoQuestion.signal .. " " .. photoQuestion.slot, "4 3")
paste("[claude-in-wow réponse " .. fourth.at .. "]\n\nCollée avant d'arriver, pour voir")
slots[slotName(3)], playing["004"] = "[claude-in-wow réponse " .. fourth.at .. "]\n\nCollée avant d'arriver, pour voir", true
look()
ok("pasted first: not taken twice", #messages(), 2)
soundOn = false
ask("Sans le son du jeu ?")
ok("the game's sound off: no signal, the answer is to paste", tostring(photoQuestion.signal) .. " " .. tostring(photoQuestion.slot) .. " " .. tostring(findText("Au son")), "nil nil Au son, collez la réponse (Ctrl+V)")
soundOn = true
db.options.arrive = false
ask("Sans réponse automatique ?")
ok("turned off: no signal, and no slots wanted", tostring(photoQuestion.signal) .. " " .. tostring(photoQuestion.options.slots), "nil 0")
db.options.arrive = true
db.options.slots = 2 -- both read already
ask("Plus de place ?")
ok("no slot left: the signal alone", tostring(photoQuestion.signal ~= nil) .. " " .. tostring(photoQuestion.slot) .. " " .. tostring(findText("Au son")), "true nil Au son, collez la réponse (Ctrl+V)")
db.options.slots = 30
do -- how many answers may still come by themselves
    local left, all = ns.SlotsLeft()
    local loaded = 0
    for _ in pairs(loadedSlots) do loaded = loaded + 1 end
    ok("those left until a reload", left .. " " .. all .. " " .. tostring(ns.SlotsWarning()), (30 - loaded) .. " 30 nil")
    local keptLoaded = {}
    for number = 1, 28 do
        keptLoaded[number] = loadedSlots[slotName(number)] or false
        loadedSlots[slotName(number)] = true
    end
    ok("few left: said", ns.SlotsWarning(), "2 réponses automatiques restantes : recharger")
    ns.OpenClaude()
    ok("in the bar of the session too", tostring(bare(findBar("barSession").left.text):find("2 réponses restantes sur 30", 1, true) ~= nil), "true")
    for number = 29, 30 do loadedSlots[slotName(number)] = true end
    ok("none left: said", ns.SlotsWarning(), "Plus de réponse automatique : recharger")
    ns.SetOption("arrive", false)
    ns.OpenClaude()
    ok("turned off: nothing to say", tostring(ns.SlotsWarning()) .. " " .. tostring(findBar("barSession").left.text:find("restantes") ~= nil), "nil false")
    ns.SetOption("arrive", true)
    local reloaded
    local keptUI = C_UI
    C_UI = { Reload = function() reloaded = true end }
    ns.ReloadInterface()
    C_UI = keptUI
    ok("a click reloads the interface", reloaded, true)
    local keptTab = db.settingsTab
    db.settingsTab = "answers"
    ns.OpenClaude("settings")
    ok("in the settings", findText("0 réponses automatiques restantes sur 30"), "0 réponses automatiques restantes sur 30")
    db.claudeNewSession = true
    db.settingsTab = "claude"
    ns.OpenClaude("settings")
    ok("beside a new session", findText("Recharger aussi l'interface"), "Recharger aussi l'interface")
    db.claudeNewSession, db.settingsTab = nil, keptTab
    for number = 1, 30 do loadedSlots[slotName(number)] = keptLoaded[number] or nil end
    ns.OpenClaude()
end
-- the window closed: a line in the chat
local last, lastTab = ask("Fenêtre fermée ?")
slots[slotName(photoQuestion.slot)] = "[claude-in-wow réponse " .. last.at .. "]\n\nPendant que la fenêtre est fermée"
playing[string.format("%03d", photoQuestion.signal)] = true
ns.ToggleClaude()
look()
ok("the window closed: the answer waits in its conversation, the chat says so", tostring(char.chat.tabs[lastTab].unread) .. " " .. tostring(printed[#printed]:find("Claude a répondu", 1, true) ~= nil), "true true")
ns.ToggleClaude()
ok("opened again: seen", tostring(char.chat.tabs[lastTab].unread), "nil")

-- what a question speaks of is read for its photo, and only that
ns.TakePhoto = function(question, done) photoQuestion, photoDone = question, done return true end
local CLUB = {
    { name = "Torvald", level = 60, classID = 8, zone = "Orgrimmar", presence = 1, guildRank = "Membre", memberNote = "", officerNote = "secret", isSelf = false },
    { name = "Merrin", level = 42, classID = 8, zone = "Les Hinterlands", presence = 4, guildRank = "Ancien", memberNote = "tailleur", officerNote = "secret" },
    { name = "Absent", level = 20, classID = 8, presence = 3, guildRank = "Membre", lastOnlineYear = 0, lastOnlineMonth = 0, lastOnlineDay = 2, lastOnlineHour = 3 },
}
C_Club = {
    GetGuildClubId = function() return "club" end,
    GetClubMembers = function() return { 1, 2, 3 } end,
    GetMemberInfo = function(_, id) return CLUB[id] end,
}
C_CreatureInfo = { GetClassInfo = function() return { className = "Mage" } end }
GetGuildInfo = function() return "Cuvée Spéciale", "Membre" end
local rosterAsked = 0
C_GuildInfo = { GuildRoster = function() rosterAsked = rosterAsked + 1 end }
UnitStat = function(_, index) return index * 10, index * 10 + 1 end
GetCritChance = function() error("not here") end
photoQuestion, photoDone = nil, nil
plusTab.scripts.OnClick(plusTab)
input:SetText("Que font les gens de ma Guilde, et mes caractéristiques ?")
input.scripts.OnEnterPressed(input)
local speaking = messages()[1]
ok("the guild is asked of the server first, nothing sent yet", rosterAsked .. " " .. tostring(photoQuestion) .. " " .. speaking.state, "1 nil sending")
fire("GUILD_ROSTER_UPDATE")
local guild = photoQuestion.read.guild
ok("then one photo, with what the question speaks of", guild.name .. " " .. guild.members .. " | " .. guild.online[1].name .. " " .. guild.online[1].class .. " " .. guild.online[1].level .. " " .. guild.online[1].zone .. " " .. guild.online[1].status
    .. " | " .. guild.online[2].status .. " " .. guild.online[2].note, "Cuvée Spéciale 3 | Torvald Mage 60 Orgrimmar online | away tailleur")
ok("who was on last", guild.offline[1].name .. " " .. guild.offline[1].lastOnlineHours, "Absent 51")
ok("the officers' notes are left out", tostring(guild.online[1].officerNote) .. " " .. tostring(guild.online[1].note), "nil nil")
ok("capitals and accents do not matter, what the game lacks is left out", photoQuestion.read.stats.stats.intellect .. " " .. tostring(photoQuestion.read.stats.meleeCrit), "41 nil")
photoDone(true)
ok("sent", speaking.state, "sent")
paste("[claude-in-wow réponse " .. speaking.at .. "]\n\nVoilà ce que font les gens de la guilde.")
local plain = ask("Où est Lard ?")
ok("a question that speaks of none: nothing more read", tostring(photoQuestion.read), "nil")
paste("[claude-in-wow réponse " .. plain.at .. "]\n\nAux Hinterlands, comme toujours.")
local function topicsOf(text)
    local names = ns.WhatToRead(text)
    table.sort(names)
    return table.concat(names, " ")
end
ok("the words of each topic", topicsOf("Mes amis et ma réputation ?") .. " | " .. topicsOf("Quels talents, quels Hauts Faits ?") .. " | " .. topicsOf("je guilde-run ce soir, l'amiral est là") .. " | " .. topicsOf("Je sors du sort"),
    "friends reputations | achievements talents | guild | ")
-- the recent chat: the open channels only, for a question that speaks of it
fire("CHAT_MSG_GUILD", "MOOO", "Merrin Dolwyn")
fire("CHAT_MSG_CHANNEL", "vends |cff1eff00|Hitem:2770|h[Minerai de cuivre]|h|r", "Torvald Grimm", nil, nil, nil, nil, nil, nil, "Général - Baie-du-Butin")
fire("CHAT_MSG_WHISPER", "un secret", "Ami")
fire("CHAT_MSG_BN_WHISPER", "un autre", "Ami")
fire("CHAT_MSG_OFFICER", "entre officiers", "Chef")
ok("the chat: a topic of its module", topicsOf("pourquoi les gens font MOOO dans le chat ?"), "chat")
local chatRead
ns.Gather({ "chat" }, function(data) chatRead = data.chat end)
ok("the chat: what was said in the open channels, links as they show", #chatRead.lines .. " " .. chatRead.lines[1].where .. " " .. chatRead.lines[1].who .. " " .. chatRead.lines[1].said .. " | " .. chatRead.lines[2].where .. " " .. chatRead.lines[2].said,
    "2 guild Merrin Dolwyn MOOO | Général - Baie-du-Butin vends [Minerai de cuivre]")
for index = 1, 200 do fire("CHAT_MSG_SAY", "ligne " .. index, "Quelqu'un") end
ns.Gather({ "chat" }, function(data) chatRead = data.chat end)
ok("the chat: the last ones only", #chatRead.lines .. " " .. chatRead.lines[60].said, "60 ligne 200")
ns.SetOption("chat", false)
fire("CHAT_MSG_GUILD", "après", "Merrin Dolwyn")
ok("the chat turned off: not a topic, nothing kept nor noted", topicsOf("dans le chat ?"), "")
ns.SetOption("chat", true)
ns.Gather({ "chat" }, function(data) chatRead = data.chat end)
ok("on again: from then on", #chatRead.lines, 0)
db.options.ask = false
ok("turned off: nothing read", #ns.WhatToRead("ma guilde"), 0)
db.options.ask = true

-- the readings: any function of the game that only reads, and nothing else
local acted = {}
local function acts(name) return function() acted[#acted + 1] = name end end
C_Reputation = {
    GetNumFactions = function() return 2 end,
    GetFactionDataByIndex = function(index) return { name = "Faction " .. index, currentStanding = index * 1000, officerNote = "secret", accountName = "moi" } end,
}
C_PartyInfo, CastSpellByName, RunScript, GetQuestReward = { InviteUnit = acts("invite") }, acts("cast"), acts("run"), acts("reward")
C_CVar = { GetCVar = function(name) return "value of " .. name end }
Enum = Enum or {}
Enum.TestKind = { Second = 2 }
local function value(text) return ns.ReadAll({ text })[1].value end
local function refused(text) return ns.ReadAll({ text })[1].error or "read" end
ok("read: a call", value("C_Reputation.GetNumFactions()"), 2)
ok("read: one call for each number", #value("C_Reputation.GetFactionDataByIndex(1..3)") .. " " .. value("C_Reputation.GetFactionDataByIndex( 1 .. 3 )")[3].name, "3 Faction 3")
ok("read: a call in a call, a field, an Enum value", value("C_Reputation.GetFactionDataByIndex(C_Reputation.GetNumFactions()).currentStanding") .. " " .. value("C_Reputation.GetFactionDataByIndex(Enum.TestKind.Second).name"), "2000 Faction 2")
ok("read: one call for each element of a list", value('C_Club.GetMemberInfo(C_Club.GetGuildClubId(), each(C_Club.GetClubMembers(C_Club.GetGuildClubId())))')[2].zone, "Les Hinterlands")
ok("read: officers' notes and accounts left out", tostring(value("C_Reputation.GetFactionDataByIndex(1)").officerNote) .. " " .. tostring(value("C_Reputation.GetFactionDataByIndex(1)").accountName) .. " " .. tostring(value("C_Club.GetMemberInfo('club', 1)").officerNote), "nil nil nil")
ok("read: a setting, but not those about the account", value("C_CVar.GetCVar('autoLootDefault')") .. " | " .. refused("C_CVar.GetCVar('accountName')"), "value of autoLootDefault | about the account")
for _, text in ipairs({ "C_PartyInfo.InviteUnit('x')", "CastSpellByName('x')", "RunScript('x')", "GetQuestReward(1)", "print('x')", "os.exit()", "GetMoney", "GetMoney();GetMoney()", "1+1",
    "GetMoney() CastSpellByName('x')", "_G.CastSpellByName('x')", "C_Reputation.GetFactionDataByIndex(CastSpellByName('x'))", "C_Reputation.GetFactionDataByIndex(1..90000)", "each(GetMoney())", "function() end" }) do
    if refused(text) == "read" then ok("read: refused: " .. text, "read", "refused") end
end
ok("read: nothing that acts was called", #acted, 0)
ok("read: an error of the game is told", refused("C_Reputation.GetFactionDataByIndex('x')"):find("C_Reputation.GetFactionDataByIndex: ", 1, true), 1)
local listed, total = 0, 0
for space, names in pairs(ns.FUNCTIONS) do
    for own in names:gmatch("%S+") do
        total = total + 1
        if not own:match("^Get") and not own:match("^Is") and not own:match("^Has") and not own:match("^Can[A-Z]") and not own:match("^Does") and not own:match("^Are") and not own:match("^Should")
            and not own:match("^Find") and not own:match("^Unit") and not own:match("^Player") and not own:match("^Num") and not own:match("^TaxiNode") then listed = listed + 1 end
    end
end
ok("the list: thousands, all named as readings", tostring(total > 3000) .. " " .. listed, "true 0")

-- the buttons of an answer: what the player may click
local PROPOSED = table.concat({ "Voici ta guilde.", "", "~~~", "[claude-in-wow] boutons", "chuchoter Torvald Grimm | Salut, tu viens ?", "écrire /g | Quelqu'un pour Uldaman ?",
    "inviter Merrin", "équiper 10465", "suivre 7840", "macro Bandage | /use Bandage épais\\n/say ok", "qui mage 60", "vendre 2770", "détruire 2770", "lancer Boule de feu", "écrire /script | x", "~~~", "", "Bon jeu !" }, "\n"):gsub("~~~", string.rep(string.char(96), 3))
C_Item = C_Item or {}
C_Item.GetItemNameByID = C_Item.GetItemNameByID or function() return "Robe" end
C_Item.GetItemCount, C_Item.EquipItemByName = function() return 1 end, acts("equip")
local buttons, shown = ns.ButtonsBlock(PROPOSED)
ok("the block is left out of the answer shown", shown, "Voici ta guilde.\n\nBon jeu !")
local labels = {}
for index, button in ipairs(buttons) do labels[index] = button.label end
ok("a button for each action of the list, none for the others", #buttons .. " " .. labels[1] .. " | " .. labels[3] .. " | " .. labels[6], "7 Chuchoter à Torvald Grimm | Inviter Merrin | Ajouter la macro Bandage")
ok("nothing done without a click", #acted, 0)
buttons[3].run()
ok("a click invites", acted[#acted], "invite")
local opened, told, inserted
ChatFrame_OpenChat = function(text) opened = text end
ChatFrame_SendTell = function(name) told = name end
ChatEdit_GetActiveWindow = function() return { Insert = function(_, text) inserted = text end } end
buttons[1].run()
buttons[2].run()
ok("a message is put in the chat box, not sent", told .. " | " .. inserted .. " | " .. opened, "Torvald Grimm | Salut, tu viens ? | /g Quelqu'un pour Uldaman ?")
local macros = {}
GetMacroIndexByName = function(name) return macros[name] and 1 or 0 end
CreateMacro = function(name, _, body) macros[name] = body return 1 end
buttons[6].run()
ok("a macro is added, its lines kept", macros.Bandage, "/use Bandage épais\n/say ok")
macros.Bandage = "mine"
ok("never one of the player's changed", tostring((buttons[6].run())) .. " " .. macros.Bandage, "nil mine")
inCombat = true
ok("not in combat", tostring((buttons[4].run())), "nil")
inCombat = false
do -- what opens something of the game
    local list = ns.ButtonsBlock("```\n[claude-in-wow] boutons\nquête 7029\ncarte 1425:84.5:41.2 | Lard\ncarte ici\nouvrir sacs\nouvrir vente\n```")
    local said = {}
    for index, button in ipairs(list) do said[index] = button.label end
    ok("a quest, a place, a window; what is not known is left out", table.concat(said, " | "), "Quête : 7029 | Sur la carte : Lard | Ouvrir mes sacs")
    local openedQuest, bagsOpened
    QuestMapFrame_OpenToQuestDetails = function(id) openedQuest = id end
    OpenAllBags = function() bagsOpened = true end
    ok("the quest log on it", tostring(list[1].run()) .. " " .. tostring(openedQuest), "true 7029")
    ok("the bags", tostring(list[3].run()) .. " " .. tostring(bagsOpened), "true true")
    openedQuest = nil
    linked.scripts.OnHyperlinkClick(linked, "ciwquest:7029", "x", "LeftButton")
    ok("a click on a quest of the log: there too", openedQuest, 7029)
    openedQuest = nil
    linked.scripts.OnHyperlinkClick(linked, "ciwquest:5341000", "x", "LeftButton")
    ok("one that is not in the log: said", tostring(openedQuest) .. " " .. printed[#printed]:match("Cette quête.*"), "nil Cette quête n'est pas dans votre journal.")
    inCombat = true
    linked.scripts.OnHyperlinkClick(linked, "ciwquest:7029", "x", "LeftButton")
    ok("not in combat", tostring(openedQuest) .. " " .. printed[#printed]:match("Le journal.*"), "nil Le journal des quêtes s'ouvre hors combat.")
    inCombat = false
    QuestMapFrame_OpenToQuestDetails = nil
    local chosen
    QuestLog_OpenToQuest = function(index) chosen = index end
    ok("in an older log", tostring(ns.ShowQuest(7029)) .. " " .. tostring(chosen == ns.Game.QuestIndex(7029)), "true true")
    QuestLog_OpenToQuest, OpenAllBags = nil, nil
end
do -- a long code block: folded until it is clicked
    local asked = ask("Un bloc ?")
    paste("[claude-in-wow réponse " .. asked.at .. "]\n\nVoici.\n\n```\n1\n2\n3\n4\n5\n6\n7\n8\n```")
    local box
    for _, f in ipairs(frames) do if f.more and f.raw and f.raw:sub(1, 3) == "1\n2" then box = f end end
    ok("a long block folded, all of it to copy", box.text.text:gsub("\n", ",") .. " " .. box.more.label.text .. " " .. tostring(box.more.shown) .. " " .. #box.raw, "1,2,3 Déplier (8 lignes) true 15")
    box.more.scripts.OnClick(box.more)
    ok("a click unfolds it", #box.text.text .. " " .. box.more.label.text, "15 Replier")
    box.more.scripts.OnClick(box.more)
    ok("and folds it again", (box.text.text:gsub("\n", ",")), "1,2,3")
    ok("a long line is cut in the middle, between letters", table.concat({ ns.FoldText(("é"):rep(50), 10, 3) }, " "), ("é"):rep(29) .. "… 5")
    ok("its lines counted as they wrap", select(2, ns.FoldText("a\n\n" .. ("b"):rep(25), 10, 3)), 5)
    ok("a short one is whole", (ns.FoldText("a\nb", 10, 3)), "a\nb")
end
do -- what is done is undone by the same button, each says what it is
    local tips = {}
    local keptLine, keptText = GameTooltip.AddLine, GameTooltip.SetText
    GameTooltip.SetText = function(_, text) tips = { text } end
    GameTooltip.AddLine = function(_, text) tips[#tips + 1] = bare(text) end
    local function tip(button) ns.ButtonTip(button) return table.concat(tips, " | ") end
    local list = ns.ButtonsBlock("```\n[claude-in-wow] buttons\ninvite Merrin\nsay /g | Bonjour\ntrack 7029\nmap 1425:84.5:41.2 | Lard\nmacro Soin | /use Bandage\nequip 10465\n```")
    local badges = {}
    for index, button in ipairs(list) do badges[index] = ns.ButtonBadge(button) end
    ok("the kind of each", table.concat(badges, " "), "Jeu Chat Affichage Affichage Jeu Jeu")
    ok("what cannot be undone says so", tip(list[1]):match("Jeu : .*"), "Jeu : ça agit dans le jeu, seulement à votre clic. | Ne peut pas être annulé d'ici.")
    ok("what only shows says the interface stays as it is", tip(list[4]):find("Votre interface et ses réglages restent tels quels. | Le même bouton l'annule, et un /reload aussi.", 1, true) ~= nil, true)
    GameTooltip.AddLine, GameTooltip.SetText = keptLine, keptText
    local message = {}
    -- the tracker
    local watched = {}
    local keptQuest = { C_QuestLog.AddQuestWatch, C_QuestLog.RemoveQuestWatch, C_QuestLog.GetQuestWatchType }
    C_QuestLog.AddQuestWatch = function(id) watched[id] = true end
    C_QuestLog.RemoveQuestWatch = function(id) watched[id] = nil end
    C_QuestLog.GetQuestWatchType = function(id) return watched[id] and 1 or nil end
    ns.ClickButton(message, 3, list[3])
    ok("a quest followed, its button undoes it", tostring(watched[7029]) .. " " .. tostring(ns.ButtonUndoes(list[3], message.done[3])), "true true")
    ns.ClickButton(message, 3, list[3])
    ok("undone", tostring(watched[7029]) .. " " .. tostring(message.done[3]), "nil nil")
    watched[7029] = true
    ns.ClickButton(message, 3, list[3])
    ok("one already followed: nothing to undo", tostring(ns.ButtonUndoes(list[3], message.done[3])), "false")
    C_QuestLog.AddQuestWatch, C_QuestLog.RemoveQuestWatch, C_QuestLog.GetQuestWatchType = keptQuest[1], keptQuest[2], keptQuest[3]
    -- the pin
    local pin = { uiMapID = 1411, position = { x = 0.5, y = 0.25 } }
    local kept = { C_Map.HasUserWaypoint, C_Map.GetUserWaypoint, C_Map.ClearUserWaypoint, C_Map.SetUserWaypoint, C_Map.CanSetUserWaypointOnMap, UiMapPoint, C_Map.GetBestMapForUnit, C_Map.GetPlayerMapPosition }
    C_Map.HasUserWaypoint = function() return pin ~= nil end
    C_Map.GetUserWaypoint = function() return pin end
    C_Map.ClearUserWaypoint = function() pin = nil end
    C_Map.CanSetUserWaypointOnMap = function() return true end
    UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { uiMapID = map, position = { x = x, y = y } } end }
    C_Map.SetUserWaypoint = function(point) pin = point return true end
    local function at() return pin and string.format("%d:%.1f", pin.uiMapID, pin.position.x * 100) or "none" end
    ns.ClickButton(message, 4, list[4])
    ok("a pin, the player's own kept aside", at() .. " " .. tostring(ns.ButtonUndoes(list[4], message.done[4])), "1425:84.5 true")
    ns.ClickButton(message, 4, list[4])
    ok("undone: the player's pin is back", at(), "1411:50.0")
    ns.ClickButton(message, 4, list[4])
    local started = ns.startedAt
    ns.startedAt = started + 1
    ok("after a reload it is no longer there to undo", tostring(ns.ButtonUndoes(list[4], message.done[4])), "false")
    ns.startedAt = started
    fire("PLAYER_LOGIN")
    ok("a reload takes our pin away", at() .. " " .. tostring(char.pinned), "none nil")
    -- the macro
    GetMacroBody = function(name) return macros and macros[name] end
    DeleteMacro = function(name) macros[name] = nil end
    ns.ClickButton(message, 5, list[5])
    ok("a macro added", macros.Soin, "/use Bandage")
    macros.Soin = "/dance"
    ns.ClickButton(message, 5, list[5])
    ok("changed since by the player: left as it is", macros.Soin, "/dance")
    macros.Soin = "/use Bandage"
    ns.ClickButton(message, 5, list[5])
    ok("taken off again", tostring(macros.Soin), "nil")
    -- what was worn
    local worn, equipped = { [5] = 111 }, {}
    GetInventoryItemID = function(_, slot) return worn[slot] end
    C_Item.EquipItemByName = function(id, slot) equipped[#equipped + 1] = id .. ":" .. tostring(slot) worn[5] = id end
    ns.ClickButton(message, 6, list[6])
    ns.ClickButton(message, 6, list[6])
    ok("a piece put on, then the one before", table.concat(equipped, " "), "10465:nil 111:5")

    -- a route
    pin = { uiMapID = 1411, position = { x = 0.5, y = 0.25 } }
    local alerts, errors = {}, {}
    RaidWarningUtil = { AddMessage = function(text) alerts[#alerts + 1] = text end, MessageType = { RaidWarning = 1 } }
    local answer = "Par là.\n\n```\n[claude-in-wow] route Scholomance\n1425:84.5:41.2 | Prends le vol | au bord de l'eau\n1422 | Va aux Maleterres\n- | Parle au garde\n1422:69.7:73.2 | Entre\nn'importe quoi\n```\n\n```\n[claude-in-wow] why\nRegardé : ton journal.\nPas sûr : rien.\n```\n\nBon voyage."
    local buttons, text, why = ns.ButtonsBlock(answer)
    ok("a route and how it was found, out of the text", text .. " / " .. why:gsub("\n", "; ") .. " / " .. buttons[1].label, "Par là.\n\nBon voyage. / Regardé : ton journal.; Pas sûr : rien. / Suivre l'itinéraire (4 étapes)")
    local far = { 0, 0 }
    C_Map.GetBestMapForUnit = function() return 1411 end
    C_Map.GetPlayerMapPosition = function() return { x = far[1], y = far[2], GetXY = function() return far[1], far[2] end } end
    local there = {}
    ns.ClickButton(there, 1, buttons[1])
    ok("followed: its pin, its line over the screen", at() .. " " .. alerts[1]:gsub("\n", " / ") .. " " .. tostring(ns.ButtonUndoes(buttons[1])), "1425:84.5 Étape 1/4 : Prends le vol / au bord de l'eau true")
    fire("PLAYER_STOPPED_MOVING")
    ok("not there yet", (ns.RouteLine()), "Étape 1/4 : Prends le vol")
    fire("NAVIGATION_DESTINATION_REACHED", true)
    ok("a stage of the game's own way is not the step", (ns.RouteLine()), "Étape 1/4 : Prends le vol")
    fire("NAVIGATION_DESTINATION_REACHED", false)
    ok("there: the next step, without a pin when it has none", (ns.RouteLine()) .. " " .. at(), "Étape 2/4 : Va aux Maleterres none")
    C_Map.GetBestMapForUnit = function() return 1422 end
    fire("ZONE_CHANGED_NEW_AREA")
    ok("a zone entered: the next", (ns.RouteLine()), "Étape 3/4 : Parle au garde")
    fire("PLAYER_STOPPED_MOVING")
    ok("a step without a place waits for the player", (ns.RouteLine()), "Étape 3/4 : Parle au garde")
    ns.OpenClaude()
    ok("the bar of the route", tostring(findBar("route").shown) .. " " .. bare(findBar("route").left.text), "true Étape 3/4 : Parle au garde")
    local entries
    local keptMenu = ns.ToggleMenu
    ns.ToggleMenu = function(_, list) entries = list end
    findBar("route").scripts.OnClick(findBar("route"))
    ns.ToggleMenu = keptMenu
    ok("its menu", entries[1].label .. " | " .. entries[2].label .. " | " .. entries[3].label, "Étape précédente | Étape suivante | Arrêter l'itinéraire")
    entries[1].run()
    ok("the step before", (ns.RouteLine()), "Étape 2/4 : Va aux Maleterres")
    ns.SetOption("routeAuto", false)
    fire("ZONE_CHANGED")
    ok("by hand, as the player chose", (ns.RouteLine()), "Étape 2/4 : Va aux Maleterres")
    ns.SetOption("routeAuto", true)
    ns.RouteMove(1)
    ns.RouteMove(1)
    far = { 0.69, 0.735 }
    fire("PLAYER_STOPPED_MOVING")
    ok("the last one: arrived, the player's pin back", alerts[#alerts] .. " " .. at() .. " " .. tostring(ns.RouteActive()), "Vous êtes arrivé : Scholomance 1411:50.0 false")
    ns.ClickButton(there, 1, buttons[1])
    ns.ClickButton(there, 1, buttons[1])
    ok("stopped by the same button", tostring(ns.RouteActive()) .. " " .. at(), "false 1411:50.0")
    do -- short cuts
        local here, spot = 1411, { 0.5, 0.5 }
        C_Map.GetBestMapForUnit = function() return here end
        C_Map.GetPlayerMapPosition = function(map) if map == here then return { x = spot[1], y = spot[2], GetXY = function() return spot[1], spot[2] end } end end
        local function go(map, x, y) here, spot = map, { (x or 0) / 100, (y or 0) / 100 } fire(x and "PLAYER_STOPPED_MOVING" or "ZONE_CHANGED_NEW_AREA") end
        local function follow(lines) ns.StopRoute() ns.StartRoute("test", "", ns.ParseRoute(lines)) end
        local function step() return ns.RouteActive() and ns.RouteLine():match("%d+/%d+") or "over" end
        local way = "1411:10:10 | a\n1413 | b\n1425:84:41 | c\n- | d\n1422 | e\n1422:69:73 | f"
        follow(way)
        go(1425, 84, 41)
        ok("a short cut to the third step: the fourth", step(), "4/6")
        go(1422)
        ok("past one without a place, into a zone", step(), "6/6")
        follow(way)
        go(1413)
        ok("a zone further on, come into", step(), "3/6")
        go(1411, 10, 10)
        ok("the steps before are behind", step(), "3/6")
        follow(way)
        go(1422, 69, 73)
        ok("both at once: the first of the two, then the other", step(), "6/6")
        go(1422, 69, 73)
        ok("then the other", step(), "over")
        here, spot = 1411, { 0.5, 0.5 }
        follow("1413:20:20 | a\n1411:50:50 | back")
        go(1411, 50, 50)
        ok("a way that ends where it begins is not over at once", step(), "1/2")
        go(1413, 20, 20)
        go(1411, 50, 50)
        ok("but at its end", step(), "over")
        here = 1411
        follow("1413:20:20 | a\n1413 | b\n1411 | back\n1413 | c")
        go(1413, 80, 80)
        ok("crossing a zone for the step in it does not skip that step", step(), "1/4")
        ns.StopRoute()
        C_Map.GetBestMapForUnit = function() return 1422 end
        C_Map.GetPlayerMapPosition = function() return { x = far[1], y = far[2], GetXY = function() return far[1], far[2] end } end
    end
    ns.SetOption("routeAlerts", false)
    local before = #alerts
    ns.ClickButton(there, 1, buttons[1])
    ok("no line over the screen, as the player chose", #alerts - before, 0)
    ns.SetOption("route", false)
    ok("turned off: stopped, and no button", tostring(ns.RouteActive()) .. " " .. tostring((ns.ButtonsBlock(answer))), "false nil")
    ns.SetOption("route", true)
    ns.SetOption("routeAlerts", true)
    ns.SetOption("why", false)
    ok("how it was found: turned off, still out of the text", tostring(select(3, ns.ButtonsBlock(answer))) .. " " .. select(2, ns.ButtonsBlock(answer)):sub(1, 8), "nil Par là.")
    ns.SetOption("why", true)
    ok("a pin for nothing that is known: none", #ns.ParseRoute("- | a\nx | b\n1425:1:1 | " .. ("c"):rep(5) .. "\n" .. ("- | d\n"):rep(20)), 12)
    -- in the conversation, folded
    local asked = ask("Par où ?")
    paste("[claude-in-wow réponse " .. asked.at .. "]\n\n" .. answer)
    local shown
    for _, f in ipairs(frames) do if f.why and f.whyText and f.why.message == messages()[2] then shown = f end end
    ok("how it was found: folded", tostring(shown.why.shown) .. " " .. shown.why.label.text .. " " .. tostring(shown.whyText.shown), "true Comment Claude a trouvé false")
    shown.why.scripts.OnClick(shown.why)
    ok("a click unfolds it", tostring(shown.whyText.shown) .. " " .. shown.whyText.text:sub(1, 8), "true Regardé")
    C_Map.HasUserWaypoint, C_Map.GetUserWaypoint, C_Map.ClearUserWaypoint, C_Map.SetUserWaypoint, C_Map.CanSetUserWaypointOnMap, UiMapPoint, C_Map.GetBestMapForUnit, C_Map.GetPlayerMapPosition = kept[1], kept[2], kept[3], kept[4], kept[5], kept[6], kept[7], kept[8]
    RaidWarningUtil = nil
    C_Item.EquipItemByName = acts("equip")
end
local proposing = ask("Un bouton ?")
paste("[claude-in-wow réponse " .. proposing.at .. "]" .. string.rep(string.char(10), 2) .. PROPOSED)
local chipThere
for _, f in ipairs(frames) do if f.button and f.button.label == "Inviter Merrin" then chipThere = f end end
ok("the window shows them under the answer", chipThere and chipThere.label.text, "Inviter Merrin")
acted = {}
chipThere.scripts.OnClick(chipThere)
ok("a click there does it, and shows it done", acted[1] .. " " .. tostring(messages()[2].done[3]), "invite true")
ok("no block: the answer as it is", tostring((ns.ButtonsBlock("Bonjour"))) .. " " .. select(2, ns.ButtonsBlock("Bonjour")), "nil Bonjour")
-- the questions Claude proposes: the click asks, in one photo with what was read
local CHIPS = table.concat({ "Je ne vois pas ta guilde dans la photo.", "", "~~~", "[claude-in-wow] questions", "Que font les gens de ma guilde ? | topics guild | read GetMoney() | read CastSpellByName('x')",
    "Et pour les Hinterlands ?", "~~~", "", "~~~", "[claude-in-wow] boutons", "inviter Merrin", "~~~" }, "\n"):gsub("~~~", string.rep(string.char(96), 3))
local chips, without = ns.ButtonsBlock(CHIPS)
ok("the questions' block and the buttons', both left out", without, "Je ne vois pas ta guilde dans la photo.")
ok("a chip for each, the actions first", #chips .. " " .. chips[1].label .. " | " .. chips[2].label .. " | " .. chips[3].label, "3 Inviter Merrin | Que font les gens de ma guilde ? | Et pour les Hinterlands ?")
do -- an import string: a button that shows it to copy
    local text = "Voici.\n\n```\n[claude-in-wow] string Foire de Sombrelune\n!TA1cVTTnq4)lAia2\n```\n\nColle-la."
    local list, shown = ns.ButtonsBlock(text)
    ok("an import string: a button, the string out of the text", #list .. " " .. list[1].label .. " | " .. shown, "1 Copier la string : Foire de Sombrelune | Voici.\n\nColle-la.")
    ns.OpenClaude()
    list[1].run()
    ok("its click shows it, selected", stripBox.copyText .. " " .. tostring(findText("La string")), "!TA1cVTTnq4)lAia2 La string, sélectionnée : Ctrl+C")
    IsControlKeyDown = function() return true end
    stripBox.scripts.OnKeyDown(stripBox, "C")
    IsControlKeyDown = function() return false end
    timers[#timers]()
    ok("copied: said", findText("String copiée"), "String copiée : collez-la dans l'addon")
    ok("a mark left by mistake: no button", tostring((ns.ButtonsBlock("```\n[claude-in-wow] string X\n{{string:1a2b3c4d}}\n```"))), "nil")
end
ok("its tooltip says what is read", chips[2].tip, "Pose cette question, avec ce que le jeu dit de : guilde, GetMoney(), CastSpellByName('x').")
photoQuestion = nil
acted = {}
local askedBefore = #messages()
chips[2].run()
fire("GUILD_ROSTER_UPDATE")
ok("a click asks it, with what was read", photoQuestion.text .. " | " .. photoQuestion.read.guild.name .. " | " .. tostring(photoQuestion.read.reads[1].value == GetMoney()), "Que font les gens de ma guilde ? | Cuvée Spéciale | true")
ok("what acts is refused, and not called", photoQuestion.read.reads[2].error .. " " .. #acted, "not a function that only reads: CastSpellByName 0")
ok("in the conversation, as any question", #messages() - askedBefore, 1)
photoDone(true)
inCombat = true
ok("not in combat", tostring((chips[3].run())), "nil")
inCombat = false
db.options.ask = true
for _, tab in ipairs(char.chat.tabs) do
    for _, message in ipairs(tab.messages) do if message.role == "you" then message.answered = true end end
end
while #char.chat.tabs > 2 do
    for _, f in ipairs(frames) do if f.index == #char.chat.tabs and f.close then f.close.scripts.OnClick(f.close) break end end
end
ns.TakePhoto = keptTakePhoto

do -- the text selected with the mouse
    ns.OpenClaude()
    local kept, keptScroll, keptInput = ns.ConversationTexts, ns.ConversationScroll, ns.ConversationInput
    -- texts 100 wide, 20 high, one under the other: a letter each unit
    local function Text(raw, top)
        return setmetatable({
            raw = raw, GetText = function(self) return self.raw end, GetTop = function() return top end, GetBottom = function() return top - 20 end,
            GetLeft = function() return 0 end, GetRight = function() return 100 end, SetPoint = noop,
            FindCharacterIndexAtCoordinate = function(_, x) return math.min(math.floor(x) + 1, #raw + 1) end,
            CalculateScreenAreaFromCharacterSpan = function(_, low, high) return { { left = low - 1, bottom = 0, width = high - low, height = 20 } } end,
        }, stub)
    end
    local one, two, three = Text("Va à |cffffd100|Hciwplace:1:::X|h|TInterface\\x:14|t Orgrimmar|h|r.", 200), Text("Minerai", 170), Text("Fin||", 150)
    local list = { { text = one, before = "", gap = "\n\n" }, { text = two, before = "- ", gap = "\n" }, { text = three, before = "- ", gap = "\n" } }
    ns.ConversationTexts = function() return list end
    ns.ConversationScroll = function() return { GetTop = function() return 300 end, GetBottom = function() return 0 end, IsMouseOver = function() return true end, GetVerticalScroll = function() return 0 end, To = noop } end
    local part
    for _, f in ipairs(frames) do if f.scripts.OnMouseDown and f.scripts.OnMouseUp and f.scripts.OnHyperlinkClick then part = f end end
    local layer, copyBox
    for _, f in ipairs(frames) do
        if f.events.MODIFIER_STATE_CHANGED then layer = f end
        if f.kind == "EditBox" and f.scripts.OnKeyDown and f ~= stripBox then copyBox = f end
    end
    local cursorX, cursorY = 0, 190
    GetCursorPosition = function() return cursorX, cursorY end
    local focused = nil
    GetCurrentKeyBoardFocus = function() return focused end
    layer.IsVisible = function() return true end
    local function drag(x1, y1, x2, y2)
        clock = clock + 5
        cursorX, cursorY = x1, y1
        part.scripts.OnMouseDown(part, "LeftButton")
        cursorX, cursorY = x2, y2
        if layer.scripts.OnUpdate then layer.scripts.OnUpdate(layer) end
        part.scripts.OnMouseUp(part, "LeftButton")
    end
    local function ctrl() copyBox.copyText = nil layer.scripts.OnEvent(layer, "MODIFIER_STATE_CHANGED", "LCTRL", 1) return copyBox.copyText end
    drag(0, 190, 3, 160)
    ok("text dragged over: from one paragraph to the next, as it reads", ctrl(), "Va à Orgrimmar.\n- Min")
    drag(3, 160, 0, 190)
    ok("the other way round: the same", ctrl(), "Va à Orgrimmar.\n- Min")
    drag(2, 160, 4, 140)
    ok("from the middle of a line, over others", ctrl(), "nerai\n- Fin|")
    drag(0, 160, 1, 160)
    ok("a click: nothing selected", tostring(ctrl()), "nil")
    clock = clock + 5
    cursorX, cursorY = 3, 160
    part.scripts.OnMouseDown(part, "LeftButton")
    part.scripts.OnMouseUp(part, "LeftButton")
    clock = clock + 0.1
    part.scripts.OnMouseDown(part, "LeftButton")
    part.scripts.OnMouseUp(part, "LeftButton")
    ok("a double click: the paragraph", ctrl(), "- Minerai")
    focused = { other = true }
    ok("another box's own Ctrl+C is left alone", tostring(ctrl()), "nil")
    focused = nil
    two.raw = "Autre chose"
    ns.SelectionLaidOut()
    ok("its text changed: no selection left", tostring(ctrl()), "nil")
    ns.SetOption("select", false)
    drag(0, 190, 3, 160)
    ok("the module off: none", tostring(ctrl()), "nil")
    ns.SetOption("select", true)
    ok("a whole answer, for its copy button", ns.PlainOf(list), "Va à Orgrimmar.\n- Autre chose\n- Fin|")
    ns.ConversationTexts, ns.ConversationScroll, ns.ConversationInput = kept, keptScroll, keptInput
    GetCurrentKeyBoardFocus = nil
    -- the conversation's own texts, in order
    local real = ns.ConversationTexts()
    ok("every text of the conversation is there", #real > 0 and type(real[1].text) == "table" and real[1].gap ~= nil, true)
end

-- the places the game knows, in an answer
local realMap = {}
for key, fn in pairs(C_Map) do realMap[key] = fn end
local MAPS = { [947] = { name = "Azeroth", mapType = 1, parentMapID = 0 }, [1414] = { name = "Kalimdor", mapType = 2, parentMapID = 947 }, [1425] = { name = "Les Hinterlands", mapType = 3, parentMapID = 1415 },
    [1454] = { name = "Orgrimmar", mapType = 3, parentMapID = 1414 }, [1434] = { name = "Vallée de Strangleronce", mapType = 3, parentMapID = 1415 }, [1422] = { name = "Maleterres", mapType = 3, parentMapID = 1415 }, [2652] = { name = "Shen’dralas", mapType = 3, parentMapID = 1414 } }
C_Map.GetBestMapForUnit = function() return 1454 end
C_Map.GetMapInfo = function(id) return MAPS[id] end
C_Map.GetMapChildrenInfo = function()
    local list = {}
    for id, info in pairs(MAPS) do list[#list + 1] = { mapID = id, name = info.name, mapType = info.mapType, parentMapID = info.parentMapID } end
    return list
end
C_EncounterJournal = { GetDungeonEntrancesForMap = function(map) return map == 1422 and { { name = "Scholomance", position = { x = 0.69, y = 0.73 } } } or {} end }
-- every zone's list holds the continent's towns, as Forever's
C_TaxiMap = { GetTaxiNodesForMap = function(map)
    return { { nodeID = 18, name = "Baie-du-Butin, Strangleronce", position = map == 1434 and { x = 0.27, y = 0.77 } or map == 1414 and { x = 0.4, y = 0.9 } or { x = -0.3, y = 1.4 } },
        { nodeID = 19, name = "zzOLDBolder'ok", position = { x = 0.5, y = 0.5 } } }
end }
C_Map.GetMapInfoAtPosition = function(map, x) return map == 1414 and x == 0.4 and { mapID = 1434, mapType = 3 } or nil end
local PIN = ns.PinIcon()
local function place(map, x, y, name, label) return "|cffffd100|Hciwplace:" .. map .. ":" .. x .. ":" .. y .. ":" .. name .. "|h" .. PIN .. (label or name) .. "|h|r" end
ok("a zone of an answer", ns.MarkdownInline("Va à Orgrimmar."), "Va à " .. place(1454, "", "", "Orgrimmar") .. ".")
ok("its article left out of the link", ns.MarkdownInline("dans les Hinterlands"), "dans les " .. place(1425, "", "", "Les Hinterlands", "Hinterlands"))
ok("a dungeon: its entrance; a town: its flight master", ns.MarkdownInline("Scholomance, Baie-du-Butin"), place(1422, "69.0", "73.0", "Scholomance") .. ", " .. place(1434, "27.0", "77.0", "Baie-du-Butin"))
ok("not within a word, nor in code", ns.MarkdownInline("Orgrimmarien `Orgrimmar`"):find("ciwplace", 1, true), nil)
ok("Claude's link to a zone: drawn the same, once", ns.MarkdownInline("[Orgrimmar](zone:1454)"), place(1454, "", "", "Orgrimmar"))
ok("a place only Claude knows: its zone's map", ns.MarkdownInline("[Caer Darrow](zone:1422)"), place(1422, "", "", "Caer Darrow"))
GetRealZoneText = function(id) return id == 48 and "Profondeurs noires" or id and "Donjon " .. id or "Maraudon" end -- at the next reading
ok("a dungeon the game does not list: its zone's map", ns.MarkdownInline("les Profondeurs de Brassenoire"), "les " .. place(1440, "", "", "Profondeurs de Brassenoire"))
ok("the English names", ns.MarkdownInline("The Hinterlands, Western Plaguelands"), place(1425, "", "", "Les Hinterlands", "The Hinterlands") .. ", " .. place(1422, "", "", "Maleterres", "Western Plaguelands"))
ok("the French ones, which a Forever client may not have", ns.MarkdownInline("Maleterres de l'Ouest"), place(1422, "", "", "Maleterres", "Maleterres de l'Ouest"))
ok("a name the game writes with a curved apostrophe", ns.MarkdownInline("Shen'dralas et Shen’dralas"):gsub("|T.-|t ", ""), "|cffffd100|Hciwplace:2652:::Shen’dralas|hShen'dralas|h|r et |cffffd100|Hciwplace:2652:::Shen’dralas|hShen'dralas|h|r")
ok("the game's leftovers are no places", ns.FindPlace("zzOLDBolder'ok"), nil)
ok("other capitals", ns.MarkdownInline("Vallée de strangleronce"), place(1434, "", "", "Vallée de Strangleronce", "Vallée de strangleronce"))
ok("but the first letter's", ns.MarkdownInline("maleterres"), "maleterres")
ok("a typographic apostrophe", ns.MarkdownInline("Donjon d’Ombrecroc"):find("ciwplace:1421", 1, true) ~= nil, true)
local saved = {}
for _, entry in ipairs(db.places) do saved[entry.name] = entry.map end
ok("the places saved for Claude, each once", tostring(saved.Orgrimmar) .. " " .. tostring(saved["Les Hinterlands"]) .. " " .. tostring(saved.Hinterlands) .. " " .. tostring(saved["Baie-du-Butin"]), "1454 1425 nil 1434")
-- a dungeon's entrance, learnt by going in
local keptInside, keptInstance, keptGroup = IsInInstance, GetInstanceInfo, IsInGroup
LE_PARTY_CATEGORY_INSTANCE = 2
IsInGroup = function(category) return category ~= 2 end
IsInInstance = function() return false, "none" end
C_Map.GetBestMapForUnit = function() return 1440 end
C_Map.GetPlayerMapPosition = function() return { GetXY = function() return 0.1409, 0.142 end } end
fire("PLAYER_LEAVING_WORLD")
IsInInstance = function() return true, "party" end
GetInstanceInfo = function() return "Profondeurs de Brassenoire", "party", 1, "Normal", 5, 0, false, 48 end
fire("PLAYER_ENTERING_WORLD")
ok("the entrance of a dungeon entered", ns.MarkdownInline("Blackfathom Deeps"):match("ciwplace:[^|]+"), "ciwplace:1440:14.1:14.2:Profondeurs noires")
fire("PLAYER_LEAVING_WORLD")
fire("PLAYER_ENTERING_WORLD")
IsInInstance = function() return false, "none" end
C_Map.GetBestMapForUnit = function() return 1454 end
fire("PLAYER_LEAVING_WORLD")
IsInInstance = function() return true, "party" end
GetInstanceInfo = function() return "Uldaman", "party", 1, "Normal", 5, 0, false, 70 end
fire("PLAYER_ENTERING_WORLD")
ok("not from another zone (a portal)", tostring(db.entrances[70]), "nil")
IsInInstance, GetInstanceInfo, IsInGroup = keptInside, keptInstance, keptGroup
ok("in bold", ns.MarkdownInline("**Orgrimmar** : deux"), "|cffffffff" .. place(1454, "", "", "Orgrimmar") .. "|r : deux")
ns.SetOption("placesIcon", false)
ok("without the pin", ns.MarkdownInline("Orgrimmar"), "|cffffd100|Hciwplace:1454:::Orgrimmar|hOrgrimmar|h|r")
ns.SetOption("placesIcon", true)
ns.SetOption("places", false)
ok("the module off: as it was written", ns.MarkdownInline("Va à Orgrimmar."), "Va à Orgrimmar.")
ns.SetOption("places", true)
pins, mapsOpened = {}, {}
linked.scripts.OnHyperlinkClick(linked, "ciwplace:1422:69.0:73.0:Scholomance", "Scholomance", "LeftButton")
ok("a click: the map, and a pin at the entrance", mapsOpened[1] .. " " .. pins[1].map .. " " .. pins[1].x, "1422 1422 0.69")
linked.scripts.OnHyperlinkClick(linked, "ciwplace:1454:::Orgrimmar", "Orgrimmar", "LeftButton")
ok("a zone: the map only", mapsOpened[2] .. " " .. #pins, "1454 1")

-- the players the game knows, in an answer
CLUB[1] = { name = "Joseph Hartwell", level = 49, classID = 5, zone = "Orgrimmar", presence = 1, guildRank = "Membre", memberNote = "soin/tank" }
CLUB[2] = { name = "Abbé Tonnerre", level = 42, classID = 8, zone = "Vallée de Strangleronce", presence = 1, guildRank = "Membre", memberNote = "" }
C_CreatureInfo.GetClassInfo = function(id) return id == 5 and { className = "Prêtre", classFile = "PRIEST" } or { className = "Mage", classFile = "MAGE" } end
C_ClassColor = { GetClassColor = function(file) return file == "PRIEST" and { r = 1, g = 1, b = 1 } or { r = 0.25, g = 0.78, b = 0.92 } end }
fire("GUILD_ROSTER_UPDATE")
local MUTED = ns.Theme.Code("muted")
ok("a player: their class's colour, their level", ns.MarkdownInline("Abbé Tonnerre arrive."), "|cff3fc6ea|Hciwplayer:Abbé Tonnerre|hAbbé Tonnerre|h|r " .. MUTED .. "42|r arrive.")
ok("not the level twice", ns.MarkdownInline("Joseph Hartwell (49, soin/tank)"), "|cffffffff|Hciwplayer:Joseph Hartwell|hJoseph Hartwell|h|r (49, soin/tank)")
ok("a first name alone, once the whole name is there", ns.MarkdownInline("Joseph soigne", "Joseph Hartwell (49). Joseph soigne"):find("ciwplayer:Joseph Hartwell", 1, true) ~= nil, true)
ok("but not else", ns.MarkdownInline("Joseph soigne", "Joseph soigne"), "Joseph soigne")
ns.SetOption("playersClass", false)
ns.SetOption("playersLevel", false)
ok("without colour nor level", ns.MarkdownInline("Abbé Tonnerre"), "|cffffffff|Hciwplayer:Abbé Tonnerre|hAbbé Tonnerre|h|r")
ns.SetOption("playersClass", true)
ns.SetOption("playersLevel", true)
local menuEntries
local realMenu = ns.MenuAtCursor
ns.MenuAtCursor = function(entries) menuEntries = entries end
linked.scripts.OnHyperlinkClick(linked, "ciwplayer:Joseph Hartwell", "Joseph Hartwell", "LeftButton")
ns.MenuAtCursor = realMenu
local menuLabels = {}
for index, entry in ipairs(menuEntries) do menuLabels[index] = entry.label end
ok("a click: what can be done with them, where they are", table.concat(menuLabels, " | "), "Chuchoter | Inviter dans le groupe | Chercher (/who) | Ouvrir la carte : Orgrimmar")
mapsOpened = {}
menuEntries[4].run()
ok("their zone's map", mapsOpened[1], 1454)
ns.SetOption("players", false)
ok("the module off: as it was written", ns.MarkdownInline("Abbé Tonnerre"), "Abbé Tonnerre")
ns.SetOption("players", true)
-- the other modules of an answer
ns.SetOption("gameLinks", false)
ok("quests and items off: their names", ns.MarkdownInline("[Lard a perdu son déjeuner !](quest:7840)"), "Lard a perdu son déjeuner !")
ns.SetOption("gameLinks", true)
ns.SetOption("chips", false)
ns.SetOption("actions", false)
ok("chips and actions off: none, their blocks left out", tostring((ns.ButtonsBlock(CHIPS))) .. " " .. select(2, ns.ButtonsBlock(CHIPS)), "nil Je ne vois pas ta guilde dans la photo.")
ns.TakePhoto = function(question, done) photoQuestion, photoDone = question, done return true end
ask("Sans pastilles ?")
ok("and Claude is told", table.concat(photoQuestion.options.off, " "), "actions chips")
paste("[claude-in-wow réponse " .. photoQuestion.at .. "]\n\nSans pastilles, donc.")
ns.SetOption("chips", true)
ns.SetOption("actions", true)
ns.TakePhoto = keptTakePhoto
for key, fn in pairs(realMap) do C_Map[key] = fn end

-- the settings, behind the gear: switches, no AddOns settings entry
findButton("Réglages").scripts.OnClick(findButton("Réglages"))
local tabNames, tabsByKey = {}, {}
for _, f in ipairs(frames) do if f.category and f.label then tabNames[#tabNames + 1] = f.label.text tabsByKey[f.category] = f end end
ok("the gear shows the settings page, its tabs on the left", tostring(findText("Réglages")) .. " | " .. table.concat(tabNames, " "),
    "Réglages | Claude Questions Réponses Conversation Limitations Sacs Consommation Fenêtre Aide Nouveautés À propos")
local settingRows = {}
local function openTabs() -- each in turn, as the player would
    for _, key in ipairs({ "claude", "questions", "answers", "conversation", "limits", "bags", "usage", "window", "help", "updates", "about" }) do
        tabsByKey[key].scripts.OnClick(tabsByKey[key])
    end
    for _, f in ipairs(frames) do if f.option and f.option.key then settingRows[f.option.key] = f end end
end
openTabs()
ok("a tab opened is kept", db.settingsTab, "about")
ok("the first one shows Claude's", tostring(findText("Photo compacte")) .. " " .. tostring(findText("Bouton de la mini-carte")), "Photo compacte Bouton de la mini-carte")
local minimapSwitch = settingRows.minimapButton.switch
ok("a switch shows the setting", minimapSwitch.checked, true)
local settingsOn = {}
for key, row in pairs(settingRows) do if row.switch and row.switch.checked then settingsOn[#settingsOn + 1] = key end end
table.sort(settingsOn)
ok("every module and setting on by default, but the sound at the start", table.concat(settingsOn, " "), "answerNote arrive bagButton barCharacter barSession chips compactPhoto gameLinks marks minimapButton parallel places placesIcon placesPin players playersClass playersLevel renew route routeAlerts routeAuto saidInGame select sendByPhoto shortcutsEdit soundReady why")
-- the usage
ok("short figures", table.concat({ ns.ShortNumber(950), ns.ShortNumber(1000), ns.ShortNumber(52499), ns.ShortNumber(999400), ns.ShortNumber(999600), ns.ShortNumber(1240000) }, " | "), "950 | 1 k | 52 k | 999 k | 1 M | 1,2 M")
do
    local keptTime, kept = time, db.usage
    db.usage = { list = {}, days = {}, models = {} }
    local now = keptTime()
    ns.NoteUsage("Où est Lard ?", { at = now - 10 * 86400, model = "opus-5.5", tokens = 200000, cached = 100000 })
    ns.NoteUsage("Que vendre ?", { at = now - 3 * 86400, model = "haiku-5.5", tokens = 40000, cached = 30000 })
    local answer = { at = now, model = "haiku-5.5", effort = "medium", tokens = 10000, cached = 5000, detail = { 8000, 0, 500, 0, 1500, 1 } }
    ns.NoteUsage("Où est Scholomance ?", answer, 9)
    ns.NoteUsage("Où est Scholomance ?", answer, 9)
    ns.NoteUsage("Sans jetons", { at = now })
    ok("today, the last days, everything; an answer counted once", table.concat({ ns.UsageOf(1) }, " ") .. " | " .. table.concat({ ns.UsageOf(7) }, " ") .. " | " .. table.concat({ ns.UsageOf() }, " "),
        "10000 5000 1 | 50000 35000 2 | 250000 135000 3")
    tabsByKey.usage.scripts.OnClick(tabsByKey.usage)
    ok("the tab: each answer, the last one first", tostring(findText("Où est Scholomance ?") ~= nil) .. " " .. tostring(findText("Que vendre ?") ~= nil) .. " " .. tostring(findText("Par modèle")), "true true Par modèle")
    ok("by model", bare(findText("|cfffaf9f5Opus 5.5|r   ") or ""), "Opus 5.5   200 k jetons, 1 réponse")
    -- the player's plan
    ok("the plan, before an answer says it", tostring(findText("Affiché avec la prochaine réponse") ~= nil), "true")
    ns.NotePlan(" session=a n=1")
    ok("nothing said of it: nothing noted", tostring(db.claudePlan), "nil")
    ns.NotePlan((" session=a p=5h:30:%d:5,7d:55:%d:250,7d-opus:120:%d"):format(now + 2 * 3600 + 120, now + 3 * 86400, now - 60))
    local lines = ns.PlanLines()
    local read = {}
    for index, line in ipairs(lines) do
        local percent, own = ns.PlanPercent(line)
        read[index] = line.name .. " " .. percent .. " " .. tostring(own)
    end
    ok("the plan's windows, the game's part of them", table.concat(read, " | "), "Sur 5 heures 30 % dont 0,05 % pour l'addon | Sur la semaine 55 % dont 2,5 % pour l'addon | Sur la semaine, Opus  nil")
    local parts = {}
    for index, own in ipairs({ 0, 100, 210, 999, 1249, 10000 }) do parts[index] = select(2, ns.PlanPercent({ own = own })):match("dont (.-) pour") end
    ok("small parts with their decimals", table.concat(parts, " "), "0 % 1 % 2,1 % 9,99 % 12 % 100 %")
    ok("when they are back to zero", lines[1].note .. " | " .. lines[2].note .. " | " .. lines[3].note,
        os.date("Revient à zéro à %H:%M, dans 2 h 02", now + 2 * 3600 + 120) .. " | " .. os.date("Revient à zéro le %d/%m à %H:%M", now + 3 * 86400)
        .. " | " .. os.date("Revenu à zéro à %H:%M ; à jour avec la prochaine réponse", now - 60))
    ns.RenderClaude()
    ok("in the bar under the box: the addon's, then the plan's", tostring(bare((function() ns.OpenClaude() return findBar("barSession").right.text end)()):match("^Addon : .+  ·  Forfait : 30 %%$") ~= nil), "true")
    db.settingsTab = "usage"
    ns.OpenClaude("settings")
    ok("apart in the tab: the plan, then the addon", tostring(findText("Tout ce que vous faites avec Claude.") ~= nil) .. " " .. tostring(findText("L'addon seulement") ~= nil), "true true")
    ok("in the tab on the usage", tostring(findText("Votre forfait")) .. " " .. bare(findText("|cfffaf9f530 %") or "") .. " " .. tostring(findText("Sur la semaine, Opus")) .. " " .. tostring(findText("Le reste de votre forfait")),
        "Votre forfait 30 %, dont 0,05 % pour l'addon Sur la semaine, Opus Le reste de votre forfait")
    do
        local rows = {}
        for _, f in ipairs(frames) do if f.own and f.rest and f.note then rows[#rows + 1] = f end end
        local full = {}
        for _, row in ipairs(rows) do
            row:Fill({ name = "x", percent = 50, own = 2500 }, 200)
            full[1] = tostring(row.own.width) .. "+" .. tostring(row.rest.width)
            row:Fill({ name = "x", percent = 50, own = 5 }, 200)
            full[2] = tostring(row.own.width) .. "+" .. tostring(row.rest.width)
            row:Fill({ name = "x", percent = 50 }, 200)
            full[3] = tostring(row.own.shown) .. "+" .. tostring(row.rest.width)
            row:Fill({ name = "x", percent = 1, own = 100 }, 200)
            full[4] = tostring(row.own.width) .. "+" .. tostring(row.rest.shown)
            row:Fill({ name = "x" }, 200)
            full[5] = tostring(row.own.shown) .. "+" .. tostring(row.rest.shown)
        end
        ok("the bar: the game's part, always seen, then the rest", table.concat(full, " "), "50+50 3+97 false+100 3+false false+false")
    end
    db.claudePlan = nil
    for index = 1, 30 do ns.NoteUsage("Question " .. index, { at = now + index, model = "haiku-5.5", tokens = 100 + index, cached = 0 }) end
    ns.RenderClaude()
    local lines = 0
    for _, f in ipairs(frames) do if f.entry and f.question and f.tokens and rawget(f, "shown") ~= false then lines = lines + 1 end end
    ok("the last ten questions shown, all of them kept", tostring(findText("Les 10 dernières questions")) .. " " .. lines .. " " .. tostring(findText("Question 30") ~= nil) .. " " .. tostring((findText("Voir plus"))) .. " " .. #db.usage.list .. " " .. select(3, ns.UsageOf()), "Les 10 dernières questions 10 true nil 33 33")
    db.usage.list = { db.usage.list[1], db.usage.list[2], db.usage.list[3] }
    local clear
    for _, f in ipairs(frames) do if f.label and f.label.text == "Effacer l'historique" then clear = f end end
    clear.scripts.OnClick(clear)
    ok("the history: cleared at the second click only", #db.usage.list .. " " .. clear.label.text, "3 Cliquez encore pour effacer")
    clear.scripts.OnClick(clear)
    ok("cleared", #db.usage.list .. " " .. tostring(findText("Aucune réponse")), "0 Aucune réponse pour l'instant.")
    -- what the conversations still hold, for a first time
    db.usage = nil
    db.characters["Autre Perso"] = { character = { level = 12, class = "Mage", classFile = "MAGE", money = 5000000 }, savedAt = now,
        chat = { tabs = { { messages = { { role = "you", text = "Combien ?", at = now }, { role = "claude", text = "Trois.", at = now, model = "haiku-5.5", tokens = 777, cached = 7 } } } } } }
    local found
    ns.UsageOf()
    for _, entry in ipairs(db.usage.list) do if entry.who == "Autre Perso" then found = entry end end
    ok("the answers already in the conversations", found.question .. " " .. found.tokens, "Combien ? 777")
    ns.OpenClaude()
    do -- in the bar's tooltip
        local lines, keptAdd, keptDouble = {}, GameTooltip.AddLine, GameTooltip.AddDoubleLine
        GameTooltip.AddDoubleLine = function(_, left, right) lines[#lines + 1] = bare(left) .. "=" .. bare(right) end
        findBar("barCharacter").scripts.OnEnter(findBar("barCharacter"))
        GameTooltip.AddDoubleLine = keptDouble
        ok("the account's gold, in the tooltip", table.concat(lines, " "):match("Autre Perso 12.*$"):gsub("  %d+/%d+", ""), "Autre Perso 12=500po Arden Valcourt 44=123po Compte=623po")
    end
    findBar("barSession").scripts.OnClick(findBar("barSession"))
    ok("a click on the session's bar: the usage", db.settingsTab, "usage")
    db.characters["Autre Perso"] = nil
    db.usage = kept
    ns.SetOption("barCharacter", false)
    ns.OpenClaude()
    ok("a bar turned off", tostring(findBar("barCharacter").shown) .. " " .. tostring(findBar("barSession").shown), "false true")
    ns.SetOption("barCharacter", true)
    ns.OpenClaude("settings")
    openTabs()
end
local limits = {}
for key, row in pairs(settingRows) do if row.option.limit then limits[#limits + 1] = key .. "=" .. tostring(row.switch.checked) end end
table.sort(limits)
ok("no limit at first: none ticked", table.concat(limits, " "), "actions=false addons=false ask=false chat=false planShare=false searches=false web=false")
settingRows.web.switch.scripts.OnClick(settingRows.web.switch)
ok("a limit ticked: what it limits is off", tostring(settingRows.web.switch.checked) .. " " .. tostring(db.options.web) .. " " .. table.concat(ns.ModulesOff(), " "), "true false web")
settingRows.web.switch.scripts.OnClick(settingRows.web.switch)
ok("and on again", tostring(settingRows.web.switch.checked) .. " " .. tostring(db.options.web), "false true")
local function tab(key) tabsByKey[key].scripts.OnClick(tabsByKey[key]) end
tab("answers")
ok("the answers that come by themselves: possible now", settingRows.arrive.tip.text:sub(1, 23), "La réponse s'affiche d")
soundOn = false
ns.RenderClaude()
ok("not possible now: the settings say why", settingRows.arrive.tip.text:sub(1, 12), "Pas possible")
soundOn = true
ns.RenderClaude()
ok("as many mini-addons as the settings say: a word on them", settingRows.slots.tip.text:sub(1, 24) .. " " .. settingRows.slots.picker.label.text, "Chaque réponse automati 30")
settingRows.slots.picker.scripts.OnClick(settingRows.slots.picker)
for _, f in ipairs(frames) do if f.detail and f.label and f.label.text == "50" then pickedItem = f end end
pickedItem.scripts.OnClick(pickedItem)
ok("another number picked: how many there are now", db.options.slots .. " | " .. settingRows.slots.tip.text:sub(1, 22), "50 | 30 en ce moment. Le pl")
db.options.slots = 30
ns.RenderClaude()
-- a module turned off: its own settings dimmed, and it does nothing
tab("conversation")
local alpha
settingRows.placesIcon.SetAlpha = function(_, value) alpha = value end
settingRows.places.switch.scripts.OnClick(settingRows.places.switch)
ok("a module turned off: its settings dimmed", tostring(ns.On("places")) .. " " .. alpha, "false 0.4")
settingRows.places.switch.scripts.OnClick(settingRows.places.switch)
ok("on again", tostring(ns.On("places")) .. " " .. alpha, "true 1")
-- a module of one's own: declared, it has its tab, its switch and its settings
ns.Category({ key = "mine", title = "MINE_TAB", order = 65 })
ns.Locale("enUS", { MINE_TAB = "Mine", MINE = "My module", MINE_TIP = "Does mine." })
ns.Locale("frFR", { MINE = "Mon module" })
ns.Locale("deDE", { MINE_TIP = "Nicht hier" })
local mineChanged
ns.Module({ key = "mine", category = "mine", title = "MINE", tip = "MINE_TIP", changed = function(on) mineChanged = on end,
    settings = { { key = "mineLoud", label = "MINE", tip = "MINE_TIP", default = false } } })
ns.ModuleDefaults(db.options)
ok("a module of one's own: its defaults, its text in French", tostring(ns.On("mine")) .. " " .. tostring(ns.On("mineLoud")) .. " " .. ns.L.MINE .. " " .. ns.L.MINE_TIP, "true false Mon module Does mine.")
ns.SetOption("mine", false)
ok("told when it is switched", mineChanged, false)
do -- who answers: the silent mode, or a session the player sees
    local keptSpare, keptArrive = db.spare, db.options.arrive
    local keptPlay, keptSound = PlaySoundFile, C_Sound
    local loading, loadable, exists, load = C_AddOns.IsAddOnLoaded, C_AddOns.IsAddOnLoadable, C_AddOns.DoesAddOnExist, C_AddOns.LoadAddOn
    local on, loadedSlots, texts = {}, {}, {}
    local function older() for _, one in ipairs(db.spare.list) do one.from = one.from - 60 end end
    db.options.arrive, db.spare = true, nil
    PlaySoundFile = function(file) return true, file:match("([^\\]+)%.wav$") end
    C_Sound = { IsPlaying = function(handle) return on[handle] or false end }
    C_AddOns.DoesAddOnExist = function(name) return name:find("claude-in-wow_S", 1, true) ~= nil end
    C_AddOns.IsAddOnLoaded = function(name) return loadedSlots[name] or false end
    C_AddOns.IsAddOnLoadable = function() return true end
    C_AddOns.LoadAddOn = function(name) loadedSlots[name] = true ClaudeInWoWInbox = texts[name] return true end
    ok("the silent mode answers at first", db.options.answerBy .. " " .. tostring(ns.BySession()) .. " " .. tostring(select(3, ns.QuestionChoices()).by) .. " " .. tostring(ns.SpareChannels()), "silent false silent nil")
    ns.SetOption("answerBy", "session")
    local spare = ns.SpareChannels()
    ok("a session: said with each question, places set apart for it", select(3, ns.QuestionChoices()).by .. " " .. #spare.list, "session 5")
    local first, second = spare.list[1], spare.list[2]
    ok("each its own", (first.signal ~= second.signal and first.slot ~= second.slot), true)
    ns.SpareChannels()
    ok("the same ones told again", #db.spare.list .. " " .. tostring(db.spare.list[1] == first), "5 true")
    local taken = {}
    ns.TakeChannel(taken)
    local apart = true
    for _, one in ipairs(spare.list) do apart = apart and one.slot ~= taken.slot end
    ok("a question does not take one of them", tostring(apart), "true")
    local function tick()
        local was = #timers
        for index = 1, #tickers do if not tickers[index].cancelled then tickers[index].fn() end end
        for index = was + 1, #timers do timers[index]() end
    end
    local count = #messages()
    texts[("claude-in-wow_S%03d"):format(first.slot)] = "[claude-in-wow dit 1795600000]\n\nOù est |Ti'ik ?\n\nEt son camp ?\n\n[claude-in-wow réponse 1795600000]\n\nAu **nord**.\n\nPrès de l'eau."
    tick()
    ok("nothing said yet", #messages() - count, 0)
    older()
    on[("%03d"):format(first.signal)] = true
    tick()
    local list = messages()
    ok("said in Claude: shown here with its answer", list[#list - 1].text:gsub("\n", "/") .. " > " .. list[#list].text:gsub("\n", "/") .. " " .. list[#list - 1].state, "Où est |Ti'ik ?//Et son camp ? > Au **nord**.//Près de l'eau. said")
    ok("its place is used up", #db.spare.list .. " " .. tostring(db.spare.list[1] == second), "4 true")
    ns.OpenClaude()
    ok("under it: where it was said", tostring(findText("Dit dans Claude") ~= nil), "true")
    local before = #messages()
    paste(texts[("claude-in-wow_S%03d"):format(first.slot)])
    ok("pasted once more: not taken twice", #messages() - before, 0)
    paste("[claude-in-wow dit 1795600050]\n\nEt ensuite ?\n\n[claude-in-wow réponse 1795600050]\n\nAu sud.")
    ok("pasted, when it could not come by itself", messages()[#messages()].text, "Au sud.")
    local third = db.spare.list[2]
    on = { [("%03d"):format(third.signal)] = true }
    texts[("claude-in-wow_S%03d"):format(third.slot)] = "[claude-in-wow dit 1795600100]\n\nEt là ?\n\n[claude-in-wow réponse 1795600100]\n\nOui."
    tick()
    ok("one that was not heard does not hold up the next", messages()[#messages()].text .. " " .. #db.spare.list, "Oui. 3")
    on = {}
    ns.SpareChannels()
    ok("as many again with the next photo", #db.spare.list, 5)
    on = { [("%03d"):format(db.spare.list[1].signal)] = true }
    db.spare.list[1].from = time()
    tick()
    ok("a sound left by an earlier one: not taken for it", #db.spare.list .. " " .. messages()[#messages()].text, "4 Oui.")
    on = {}
    -- a question nobody received
    local lost = { role = "you", text = "Personne ?", at = 5, state = "sent", sentAt = time() - 60, signal = 200 }
    table.insert(messages(), lost)
    ok("nobody received it: what to do with a session", ns.Unheard(lost) and "unheard", "unheard")
    db.settingsTab = "help"
    ns.OpenClaude("settings")
    ok("the help says it for a session", tostring(findText("Votre dernière question n'a pas été reçue : aucune session") ~= nil), "true")
    ns.SetOption("answerBy", "silent")
    local keptStatus, keptUsage = db.claudeStatus, db.usage
    db.claudeStatus, db.usage = nil, nil
    ns.OpenClaude("settings")
    ok("never an answer: Node may be missing, the help says it", tostring(findText("Votre question n'a pas été reçue, et rien n'a encore jamais répondu ici : Node.js") ~= nil) .. " " .. tostring(findText("Jamais de réponse : Node.js") ~= nil), "true true")
    db.claudeStatus, db.usage = keptStatus, keptUsage
    ns.SetOption("answerBy", "session")
    lost.answered = true
    ns.SetOption("saidInGame", false)
    ok("not shown here, as the player chose", tostring(ns.SpareChannels()), "nil")
    ns.SetOption("saidInGame", true)
    ns.SetOption("answerBy", "silent")
    tick()
    ok("back to the silent mode: nothing is listened to any more", tostring(ns.SpareChannels()), "nil")
    db.spare, db.options.arrive = keptSpare, keptArrive
    PlaySoundFile, C_Sound = keptPlay, keptSound
    C_AddOns.IsAddOnLoaded, C_AddOns.IsAddOnLoadable, C_AddOns.DoesAddOnExist, C_AddOns.LoadAddOn = loading, loadable, exists, load
end
do -- the updates
    local keptUpdate, keptArrive = db.update, db.options.arrive
    local keptPlay, keptSound, keptPhoto = PlaySoundFile, C_Sound, ns.TakePhoto
    local loading, loadable, exists, load = C_AddOns.IsAddOnLoaded, C_AddOns.IsAddOnLoadable, C_AddOns.DoesAddOnExist, C_AddOns.LoadAddOn
    local on, texts, seen, sent = {}, {}, {}, nil
    db.options.arrive, db.update = true, nil
    PlaySoundFile = function(file) return true, file:match("([^\\]+)%.wav$") end
    C_Sound = { IsPlaying = function(handle) return on[handle] or false end }
    C_AddOns.DoesAddOnExist = function(name) return name:find("claude-in-wow_", 1, true) ~= nil end
    C_AddOns.IsAddOnLoaded = function(name) return seen[name] or false end
    C_AddOns.IsAddOnLoadable = function() return true end
    C_AddOns.LoadAddOn = function(name) seen[name] = true ClaudeInWoWInbox = texts[name] return true end
    ns.TakePhoto = function(question, done) sent = question sent.done = done return true end
    local function tick()
        local was = #timers
        for index = 1, #tickers do if not tickers[index].cancelled then tickers[index].fn() end end
        for index = was + 1, #timers do timers[index]() end
    end
    ok("told when there is one, the addon by CurseForge, at first", db.options.updates .. " " .. db.options.updateFrom, "notify curseforge")
    ok("nothing known: no line", tostring(ns.UpdateDue()) .. " " .. tostring(ns.UpdateBadge()), "nil nil")
    ok("another text is none", tostring(ns.TakeUpdate("Bonjour")), "nil")
    db.settingsTab = "updates"
    ns.OpenClaude("settings")
    ok("the tab: what is new in this version, and before", tostring(findText("Pas encore regardé.") ~= nil) .. " " .. tostring(bare(findText("|cff") or "") ~= nil), "true true")
    -- told at the login
    texts["claude-in-wow_News"] = "[claude-in-wow update]\npluginNow=1.0.0\naddon=1.1.0\nplugin=1.0.0\nnotes.enUS=Something\nnotes.frFR=Du neuf = oui\nnotes.frFR=Et ceci"
    fire("PLAYER_LOGIN")
    ok("told at the login", ns.UpdateDue() .. " " .. #db.update.notes.frFR .. " " .. db.update.notes.frFR[1], "1.1.0 2 Du neuf = oui")
    ns.OpenClaude()
    local badge
    for _, f in ipairs(frames) do if f.label and f.label.text == "Mise à jour" then badge = f end end
    ok("a badge on the title's line", tostring(badge.shown) .. " " .. select(2, ns.UpdateBadge()):gsub("\n", " / "), "true Addon : 1.0.0, la 1.1.0 est sortie / Clic : les nouveautés")
    badge.scripts.OnClick(badge)
    local page = findText("Addon : ")
    ok("a click on it opens what is new", db.settingsTab .. " " .. page, "updates Addon : 1.0.0, la 1.1.0 est sortie")
    ok("always told: two choices, tell me or by itself", #ns.ChoiceEntries("updates"), 2)
    -- asked
    ok("on the settings' page too", tostring(badge.shown), "true")
    local button
    for _, f in ipairs(frames) do if f.label and f.label.text == "Mettre à jour" then button = f end end
    button.scripts.OnClick(button)
    ok("asked of the plugin in a photo, not of Claude", sent.kind .. " " .. sent.update.from .. " " .. tostring(sent.update.check) .. " " .. tostring(sent.signal ~= nil and sent.slot ~= nil) .. " " .. #ns.WaitingQuestions(), "update curseforge nil true " .. #ns.WaitingQuestions())
    local first = sent
    sent.done(true)
    ns.AskUpdate()
    ok("not twice", tostring(sent == first), "true")
    ok("said while it is", findText("Demandé au plugin...\n"), "Demandé au plugin...\nAddon : 1.0.0, la 1.1.0 est sortie")
    first.sentAt = first.sentAt - 10
    on[("a%03d"):format(first.signal)] = true
    tick()
    tick()
    ok("received: it waits", tostring(first.received), "true")
    texts[("claude-in-wow_S%03d"):format(first.slot)] = "[claude-in-wow update]\npluginNow=1.0.0\naddon=1.1.0\nplugin=1.1.0\nwaits=1.1.0\naddonState=ready\npluginState=done\nchecked=ok"
    on[("%03d"):format(first.signal)] = true
    tick()
    ok("the plugin's answer: the addon waits for the game to be closed, the plugin is done", tostring(ns.UpdateDue()) .. " " .. findText("Addon : "):gsub("\n", " / "), "nil Addon : 1.0.0, la 1.1.0 est sortie / L'addon est téléchargé : il s'installe quand vous quittez le jeu. / Le plugin est à jour.")
    on = {}
    for state, said in pairs({ curseforge = "dans l'application CurseForge", dev = "installé à la main", failed = "rien n'a changé" }) do
        ns.TakeUpdate("[claude-in-wow update]\npluginNow=1.0.0\naddon=1.1.0\naddonState=" .. state)
        ns.OpenClaude("settings")
        ok("what was done of the addon: " .. state, tostring(findText("Addon : "):find(said, 1, true) ~= nil), "true")
    end
    ns.TakeUpdate("[claude-in-wow update]\npluginNow=1.0.0\naddon=1.1.0\naddonState=whatever\npluginState=addonFirst")
    ns.OpenClaude("settings")
    ok("one it does not know is left out", findText("Addon : "):gsub("\n", " / "), "Addon : 1.0.0, la 1.1.0 est sortie / Le plugin attend que l'addon soit mis à jour d'abord.")
    ns.TakeUpdate("[claude-in-wow update]\npluginNow=1.0.0\nchecked=none")
    ns.OpenClaude("settings")
    ok("nothing published: said", findText("Aucune version"), "Aucune version publiée pour l'instant.")
    -- nobody there
    ns.SetOption("updateFrom", "github")
    ns.AskUpdate()
    ok("from GitHub, as the player chose", sent.update.from, "github")
    sent.done(true)
    sent.sentAt = sent.sentAt - 60
    tick()
    ns.TakeUpdate("[claude-in-wow update]\npluginNow=1.0.0\naddon=1.0.0\nplugin=1.1.0")
    ns.OpenClaude()
    ok("for the plugin alone too", tostring(badge.shown) .. " " .. select(2, ns.UpdateBadge()):match("^[^\n]*"), "true Plugin : 1.0.0, la 1.1.0 est sortie")
    ns.TakeUpdate("[claude-in-wow update]\npluginNow=1.0.0\nchecked=none")
    ns.OpenClaude("settings")
    ok("nobody received it: said", findText("Le plugin ne répond pas"):match("^[^\n]*"), "Le plugin ne répond pas : le mode silencieux est-il arrêté ? (Aide)")
    ns.AskUpdate(true)
    ok("asked again, to look only", tostring(sent.update.check), "true")
    sent.done(nil)
    ns.TakeUpdate("[claude-in-wow update]\npluginNow=1.0.0\naddon=0.9.0\nplugin=1.0.0\nchecked=ok")
    ns.OpenClaude("settings")
    ok("older is not newer", tostring(ns.UpdateDue()) .. " " .. findText("Tout est à jour"), "nil Tout est à jour.")
    ns.SetOption("updateFrom", "curseforge")
    db.update, db.options.arrive = keptUpdate, keptArrive
    PlaySoundFile, C_Sound, ns.TakePhoto = keptPlay, keptSound, keptPhoto
    C_AddOns.IsAddOnLoaded, C_AddOns.IsAddOnLoadable, C_AddOns.DoesAddOnExist, C_AddOns.LoadAddOn = loading, loadable, exists, load
end
do -- how to speak instead of writing
    db.settingsTab = "questions"
    ns.OpenClaude("settings")
    ok("speaking: explained with the questions", tostring(findText("Parler au lieu d'écrire") ~= nil) .. " " .. tostring(findText("Windows + H, puis parlez") ~= nil) .. " " .. tostring(findText("Paramètres de Windows > Confidentialité") ~= nil), "true true true")
end
do -- a new session each time one logs in
    db.claudeNewSession = nil
    fire("PLAYER_ENTERING_WORLD", true, false)
    ok("the session goes on from a login to the next", tostring(db.options.freshSession) .. " " .. tostring(db.claudeNewSession), "false nil")
    ns.SetOption("freshSession", true)
    fire("PLAYER_ENTERING_WORLD", false, true)
    fire("PLAYER_ENTERING_WORLD", false, false)
    ok("neither a reload nor a loading screen starts another", tostring(db.claudeNewSession), "nil")
    fire("PLAYER_ENTERING_WORLD", true, false)
    ns.OpenClaude()
    ok("a login does, the bar says so", tostring(db.claudeNewSession) .. " " .. tostring(findBar("barSession").left.text:find("Nouvelle session à la prochaine question", 1, true) ~= nil), "true true")
    db.claudeNewSession = nil
    ns.SetOption("freshSession", false)
    ns.OpenClaude("settings")
end
do -- the session: how much it remembers, how large it gets
    local _, _, choices = ns.QuestionChoices()
    ok("what is usual of the session", choices.remember .. " " .. choices.renewAt .. " " .. ns.ChoiceLabel("remember") .. " | " .. ns.ChoiceLabel("renewAt"), "6 250000 Les 6 dernières | 250 000 jetons")
    ns.SetOption("remember", 0)
    ns.SetOption("renewAt", 60)
    _, _, choices = ns.QuestionChoices()
    ok("what the player picked goes with each question", choices.remember .. " " .. choices.renewAt .. " " .. ns.ChoiceLabel("remember"), "0 60000 Aucune")
    ns.SetOption("remember", -1)
    ns.SetOption("renewAt", 0)
    _, _, choices = ns.QuestionChoices()
    ok("all of them, whatever the size", choices.remember .. " " .. choices.renewAt .. " " .. ns.ChoiceLabel("remember") .. " | " .. ns.ChoiceLabel("renewAt"), "-1 0 Toutes | Jamais (toute taille)")
    tabsByKey.claude.scripts.OnClick(tabsByKey.claude)
    ns.SetOption("renew", false)
    ok("never renewed: the size says it is not used", settingRows.renewAt.tip.text, "Sans effet : la session n'est pas renouvelée toute seule.")
    ns.SetOption("renew", true)
    ok("after a pause: an hour, past a size", choices.renewPause .. " " .. choices.renewPauseAt .. " " .. ns.ChoiceLabel("renewPause") .. " | " .. ns.ChoiceLabel("renewPauseAt"), "3600 60000 1 h | 60 000 jetons")
    ns.SetOption("renewPause", 120)
    ns.SetOption("renewPauseAt", 0)
    _, _, choices = ns.QuestionChoices()
    ok("another pause, whatever the size", choices.renewPause .. " " .. choices.renewPauseAt .. " " .. ns.ChoiceLabel("renewPause") .. " | " .. ns.ChoiceLabel("renewPauseAt"), "7200 0 2 h | Toute taille")
    ok("an hour at least", ns.ChoiceEntries("renewPause")[1].label .. " " .. ns.ChoiceEntries("renewPause")[2].label, "Jamais 1 h")
    ns.SetOption("renewPause", 0)
    ok("never: the size says it is not used", settingRows.renewPauseAt.tip.text .. " " .. ns.ChoiceLabel("renewPause"), "Sans effet : aucune pause ne remplace la session. Jamais")
    ns.SetOption("renewPause", 60)
    ns.SetOption("renewPauseAt", 60)
    ns.SetOption("remember", 6)
    ns.SetOption("renewAt", 250)
end
do -- the language
    local list = {}
    for index, entry in ipairs(ns.ChoiceEntries("language")) do list[index] = entry.label end
    ok("the languages to choose from", table.concat(list, " | "), "La même que Claude | La même que le jeu | Deutsch | English | Español | Français | Italiano")
    ok("Claude's at first, with nothing under the choices", db.options.language .. " " .. ns.Language() .. " " .. select(3, ns.QuestionChoices()).language .. " " .. tostring(ns.ChoiceEntries("language")[1].detail), "claude frFR frFR nil")
    tabsByKey.window.scripts.OnClick(tabsByKey.window)
    ns.SetOption("language", "deDE")
    ok("another one: waits for the next loading", settingRows.language.tip.text .. " " .. ns.Language(), "Appliqué au prochain chargement de l'interface. frFR")
    ns.UseLanguage("deDE")
    ok("then shown, English where it has none", ns.L.LANGUAGE .. " " .. ns.L.TAB_CLAUDE .. " " .. ns.Language() .. " " .. tostring(ns.L.ABOUT:find("1.0.0") ~= nil or ns.L.ABOUT:find("%%s") == nil), "Sprache Claude deDE true")
    db.claudeLanguage = "es"
    ok("the same as Claude, as the game", ns.LanguageOf("claude") .. " " .. ns.LanguageOf("game"), "esES frFR")
    local keptLocale = GetLocale
    GetLocale = function() return "koKR" end
    ok("a game that is not translated: English", ns.LanguageOf("claude") .. " " .. ns.LanguageOf("game") .. " " .. ns.LanguageOf("gone"), "esES enUS esES")
    db.claudeLanguage = nil
    ok("nothing known: English", ns.LanguageOf("claude"), "enUS")
    GetLocale = keptLocale
    ok("Claude has not answered yet: the game's", ns.LanguageOf("claude"), "frFR")
    GetLocale = function() return "esMX" end
    ok("a language shared", ns.LanguageOf("game"), "esES")
    GetLocale = keptLocale
    ns.UseLanguage("claude")
    ok("back, with nothing of the other left", ns.L.LANGUAGE .. " " .. ns.L.TOPICS.guild .. " " .. ns.ChoiceLabel("answerFont"), "Langue guilde Celle du skin")
    ns.SetOption("language", "claude")
end
do -- the skins
    local Theme, at = ns.Theme, nil
    for index = 1, 10 do if debug.getupvalue(Theme.Skin, index) == "active" then at = index end end
    ok("Claude's skin at first", Theme.Skin().key .. " " .. ns.ChoiceLabel("skin"), "claude Claude")
    local names = {}
    for index, skin in ipairs(Theme.Skins()) do names[index] = ns.L[skin.label] or skin.label end
    ok("the skins to pick from", table.concat(names, " "), "Claude Legacy Moderne")
    local keptTemplate = CreateFrame
    for _, skin in ipairs(Theme.Skins()) do
        for _, templates in ipairs({ true, false }) do -- with the game's templates, and where they are missing
            CreateFrame = function(kind, name, parent, template)
                if template and not templates then error("no such template") end
                return keptTemplate(kind, name, parent, template)
            end
            debug.setupvalue(Theme.Skin, at, skin)
            local made, problem = pcall(function()
                local parent = CreateFrame("Frame")
                parent.GetEffectiveScale = function() return 1 end
                Theme.Box(parent, 14, "page", "border", "window")
                Theme.PaintBox(parent, Theme.Faded("page", 0.5))
                for _, one in ipairs({ { "field", "border" }, { "none" }, { "send", nil, "send" } }) do
                    local box = CreateFrame("Frame", nil, parent)
                    Theme.Box(box, 8, one[1], one[2], one[3])
                    for _, fill in ipairs({ "hover", "field", "none" }) do Theme.PaintBox(box, fill, one[2] and "borderHover" or nil) end
                end
                local pressed
                local widgets = {
                    Theme.Chip(parent, "Check", "Oui", noop), Theme.Chip(parent, "Check", "Oui", noop, true), Theme.Picker(parent, noop, true),
                    Theme.IconButton(parent, "Close", 16, "Fermer", noop), Theme.IconButton(parent, "Gear", 16, "Réglages", noop, true),
                    Theme.Switch(parent, function(on) pressed = on end),
                }
                for _, widget in ipairs(widgets) do
                    for _, script in ipairs({ "OnEnter", "OnLeave", "OnClick" }) do if widget.scripts[script] then widget.scripts[script](widget) end end
                end
                if pressed ~= true then error("the switch") end
                local value
                local slider = Theme.Slider(parent, 0, 10, 1, function(v) value = v end, " px")
                slider:SetAmount(3)
                slider.scripts.OnValueChanged(slider, 5, true)
                if value ~= 5 then error("the slider") end
                Theme.Scroll(parent):To(0)
                local menu = Theme.Menu(parent)
                menu:Toggle(widgets[1], { { label = "Un", detail = "Deux", icon = "Check", run = noop } })
                local colors = Theme.Skins()[1].colors
                for name in pairs(colors) do
                    local r, g, b = Theme.Color(name)
                    if not (r and g and b) then error(name) end
                end
            end)
            ok("skin " .. skin.key .. (templates and "" or ", without the game's templates"), tostring(made) .. " " .. tostring(problem), "true nil")
        end
    end
    CreateFrame = keptTemplate
    debug.setupvalue(Theme.Skin, at, Theme.Skins()[1])
    debug.setupvalue(Theme.Skin, at, nil)
    db.options.skin = "gone"
    ok("a skin no longer there: Claude's", Theme.Skin().key, "claude")
    debug.setupvalue(Theme.Skin, at, Theme.Skins()[1])
    db.options.skin = "claude"
    tabsByKey.window.scripts.OnClick(tabsByKey.window)
    ns.SetOption("skin", "legacy")
    ok("another one picked waits for the next loading", settingRows.skin.tip.text .. " " .. Theme.Skin().key .. " " .. tostring(findText("Recharger l'interface") ~= nil), "Appliqué au prochain chargement de l'interface. claude true")
    ns.SetOption("skin", "claude")
    ok("back to it: nothing to wait for", settingRows.skin.tip.text:sub(1, 6), "Claude")
end
do -- how the conversation reads
    local sizes = {}
    tabsByKey.window.scripts.OnClick(tabsByKey.window)
    ns.SetOption("marginSides", 40)
    ok("a margin in pixels, in its slider", settingRows.marginSides.slider.label.text .. " " .. settingRows.answerSize.slider.label.text, "40 px 14 pt")
    ok("the fonts to choose from", #ns.ChoiceEntries("answerFont") .. " " .. ns.ChoiceLabel("answerFont"), "9 Celle du skin")
    ns.SetOption("answerFont", "serif")
    ns.SetOption("answerSize", 20)
    ns.SetOption("questionFont", "narrow")
    ns.SetOption("questionSize", 11)
    local keptFill, faces = ns.Theme.SetFont, {}
    ns.Theme.SetFont = function(text, face, size) faces[face .. " " .. size] = true return keptFill(text, face, size) end
    ok("what answers and questions are written in", table.concat({ ns.AnswerLook() }, " ") .. " | " .. table.concat({ ns.QuestionLook() }, " "), "serif serifBold 20 | narrow narrow 11")
    ns.OpenClaude()
    ns.RenderClaude()
    ok("the conversation is drawn with them", tostring(faces["serif 20"]) .. " " .. tostring(faces["narrow 11"]) .. " " .. tostring(faces["sans 14"]), "true true nil")
    ns.Theme.SetFont = keptFill
    ns.SetOption("answerFont", "gone")
    ok("a font no longer there: the usual one", (ns.AnswerLook()), "sans")
    for key, value in pairs({ marginSides = 18, marginEnds = 8, answerFont = "skin", answerSize = 14, questionFont = "skin", questionSize = 14 }) do ns.SetOption(key, value) end
    ns.OpenClaude("settings")
end
-- the window's opacity: a slider, its background only
tab("window")
local opacity = settingRows.opacity.slider
ok("the opacity's slider shows it", opacity.amount .. " " .. opacity.label.text, "100 100 %")
opacity.scripts.OnValueChanged(opacity, 63.4, true)
ok("moved: kept by steps of five, shown", db.options.opacity .. " " .. opacity.label.text, "65 65 %")
local faded = ns.Theme.Faded("page", db.options.opacity / 100)
ok("the window's background is as see-through", select(4, ns.Theme.Color(faded)), 0.65)
opacity.scripts.OnValueChanged(opacity, 30, false)
ok("only the player moves it", db.options.opacity, 65)
opacity.scripts.OnValueChanged(opacity, 100, true)
settingRows.soundReady.switch.scripts.OnClick(settingRows.soundReady.switch)
ok("a sound turned off", db.options.soundReady, false)
settingRows.soundReady.switch.scripts.OnClick(settingRows.soundReady.switch)
tab("claude")
settingRows.model.picker.scripts.OnClick(settingRows.model.picker)
for _, f in ipairs(frames) do if f.detail and f.label and f.label.text == "Haiku 5.5" then pickedItem = f end end
pickedItem.scripts.OnClick(pickedItem)
ok("the model, in the settings too", db.options.model .. " " .. settingRows.model.picker.label.text .. " " .. picker.label.text, "haiku Haiku 5.5 Haiku 5.5")
db.options.model = "default"
ns.RenderClaude()
minimapSwitch.scripts.OnClick(minimapSwitch)
ok("turned off: the setting and the minimap button", tostring(db.options.minimapButton) .. " " .. tostring(db.minimap.hide), "false true")
minimapSwitch.scripts.OnClick(minimapSwitch)
ok("on again", tostring(db.options.minimapButton) .. " " .. tostring(db.minimap.hide), "true nil")
findButton("Réglages").scripts.OnClick(findButton("Réglages"))
minimapButton.scripts.OnClick(minimapButton, "RightButton")
ok("a right-click on the minimap button: the settings", tostring(findText("Réglages")), "Réglages")
ok("the settings open on the tab left", db.settingsTab, "claude")
ok("the session, and its last answer", (findText("Session abcd1234") or ""):match("^Session abcd1234 : 7 questions, environ 30 000 jetons%. Dernière réponse à %d%d:%d%d, en 5 s, par Haiku 5%.5%.$") ~= nil, true)
local newSession
for _, f in ipairs(frames) do if f.label and f.label.text == "Repartir d'une nouvelle session" then newSession = f end end
newSession.scripts.OnClick(newSession)
ok("a new session is due at the next question", tostring(db.claudeNewSession) .. " " .. tostring(newSession.label.text), "true Nouvelle session à la prochaine question (annuler)")
newSession.scripts.OnClick(newSession)
ok("or not, after all", tostring(db.claudeNewSession), "nil")
findButton("Réglages").scripts.OnClick(findButton("Réglages"))

-- the last 40 messages kept; a new conversation starts empty
for index = 1, 45 do
    ns.OpenClaude("paste")
    input.text = string.rep("réponse " .. index .. " ", 6)
    input.scripts.OnTextChanged(input, true)
end
ok("the last 40 messages kept", #messages() .. " " .. messages()[40].text:sub(1, 11), "40 réponse 45")
findButton("Nouvelle conversation").scripts.OnClick(findButton("Nouvelle conversation"))
ok("a new conversation starts empty", #messages(), 0)
minimapButton.scripts.OnClick(minimapButton, "LeftButton")
ok("a second click closes it", window.shown, false)
for index = #frames, windowStart, -1 do frames[index] = nil end
char.marks = earlierMarks

-- Write the saved data the way the game does
local function serialize(value, out, indent)
    local t = type(value)
    if t == "string" then
        out[#out + 1] = string.format("%q", value):gsub("\\\n", "\\n")
    elseif t == "number" or t == "boolean" then
        out[#out + 1] = tostring(value)
    elseif t == "table" then
        out[#out + 1] = "{\n"
        local n = #value
        for i = 1, n do
            serialize(value[i], out)
            out[#out + 1] = ", -- [" .. i .. "]\n"
        end
        local keys = {}
        for k in pairs(value) do
            if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then keys[#keys + 1] = k end
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            out[#out + 1] = type(k) == "string" and ("[" .. string.format("%q", k) .. "] = ") or ("[" .. k .. "] = ")
            serialize(value[k], out)
            out[#out + 1] = ",\n"
        end
        out[#out + 1] = "}"
    end
end

if output then
    local out = { "\nClaudeInWoWDB = " }
    serialize(db, out)
    out[#out + 1] = "\n"
    local file = io.open(output, "w")
    file:write(table.concat(out))
    file:close()
end

-- A photo two minutes later, with more money: the game state drawn over the
-- screen and taken as a PNG screenshot, a page a screen. Not compact first:
-- the JSON as it is, two pages, the whole screen black.
local realTime = time
time = function() return realTime() + 120 end
GetMoney = function() return 2000000 end

inCombat = true
SlashCmdList.CLAUDEINWOW("")
ok("no photo in combat", screenshots .. " " .. tostring(printed[#printed]:find("Pas de photo en combat", 1, true) ~= nil), "0 true")
inCombat = false
fontMissing = true
SlashCmdList.CLAUDEINWOW("")
ok("no font, no photo", screenshots .. " " .. tostring(printed[#printed]:find("police de la photo manque", 1, true) ~= nil), "0 true")
fontMissing = false

local photoFrame
for _, f in ipairs(frames) do if #f.strings > 0 then photoFrame = f end end
local pages = {}
local function shoot() -- two frames drawn, then the screenshot
    photoFrame.scripts.OnUpdate(photoFrame)
    photoFrame.scripts.OnUpdate(photoFrame)
    local page = {}
    for _, fs in ipairs(photoFrame.strings) do
        if fs.shown then page[#page + 1] = { x = fs.x, y = -fs.y, text = fs.text } end
    end
    pages[#pages + 1] = page
end
-- the header's text, from its base64 glyphs
local function header(page)
    local alphabet, bytes = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/", {}
    local text = page[1].text
    for i = 1, #text, 4 do
        local n = 0
        for j = 0, 3 do n = n * 64 + (alphabet:find(text:sub(i + j, i + j), 1, true) - 1) end
        bytes[#bytes + 1] = string.char(math.floor(n / 65536), math.floor(n / 256) % 256, n % 256)
    end
    return (table.concat(bytes):gsub(" +$", ""))
end
local function writePages(file)
    if not output then return end
    local out = {}
    for _, page in ipairs(pages) do
        local rows = {}
        for _, l in ipairs(page) do rows[#rows + 1] = string.format('{"x":%d,"y":%d,"text":"%s"}', l.x, l.y, l.text) end
        out[#out + 1] = "[" .. table.concat(rows, ",") .. "]"
    end
    local handle = io.open(file, "w")
    handle:write(string.format('{"width":%d,"height":%d,"pages":[%s]}', screenWidth, screenHeight, table.concat(out, ",")))
    handle:close()
end

db.options.compactPhoto = false
SlashCmdList.CLAUDEINWOW("")
ok("black on the whole screen", tostring(rawget(photoFrame.black.points, "BOTTOM")) .. " " .. tostring(rawget(photoFrame.black, "height")), "true nil")
ok("the photo covers the screen", photoFrame.shown, true)
ok("screenshots in PNG for the photo", cvars.screenshotFormat, "png")
shoot()
ok("one screenshot a page", screenshots, 1)
fire("SCREENSHOT_STARTED") -- the game grabs the screen
photoFrame.scripts.OnUpdate(photoFrame)
ok("still shown a frame after the grab starts", photoFrame.shown, true)
photoFrame.scripts.OnUpdate(photoFrame)
ok("gone two frames after, before the file is written", photoFrame.shown, false)
fire("SCREENSHOT_SUCCEEDED")
ok("hidden between pages", photoFrame.shown, false)
timers[#timers]() -- the next page, a second later
shoot()
ok("the second page", screenshots, 2)
ok("shown again for it", photoFrame.shown, true)
fire("SCREENSHOT_SUCCEEDED") -- a game without SCREENSHOT_STARTED: shown until the file is written
ok("done: hidden", photoFrame.shown, false)
ok("the player's screenshot format back", cvars.screenshotFormat, "jpeg")
ok("says to ask the assistant", printed[#printed]:find("Photo prise en 2 images", 1, true) ~= nil, true)
ok("the header first", pages[1][1].text:sub(1, 4) .. " " .. #pages[1][1].text, "Q0lX 96") -- "FCP"
ok("the JSON as it is", header(pages[1]):match("^CIW1 %d+ 1 2 100 28 %d+ %d+ 8 json 1040 240$") ~= nil, true)
ok("rows a glyph apart, from the corner", pages[1][1].x .. " " .. pages[1][1].y .. " " .. pages[1][2].y, "4 4 12")
fire("SCREENSHOT_SUCCEEDED") -- the player's own screenshot afterwards
ok("the player's own screenshots left alone", cvars.screenshotFormat .. " " .. screenshots, "jpeg 2")
writePages(output and output .. ".pages.json")

-- Compact, the default, a second later: deflated, one page, black only
-- behind the rows
time = function() return realTime() + 121 end
db.options.compactPhoto = true
pages = {}
-- this one carries a question from the Claude window
local questionPhotoDone
local started = ns.TakePhoto({ id = time(), kind = "bags", text = "Que faire de mes sacs ?", at = time() },
    function(done) questionPhotoDone = done end)
ok("a photo with a question starts", started, true)
ok("one photo at a time", ns.TakePhoto(), false)
shoot()
fire("SCREENSHOT_STARTED")
photoFrame.scripts.OnUpdate(photoFrame)
photoFrame.scripts.OnUpdate(photoFrame)
fire("SCREENSHOT_SUCCEEDED")
local compactRows = #pages[1] - 1
ok("compact: deflated, one page", header(pages[1]):match("^CIW1 %d+ 1 1 100 (%d+) %d+ %d+ 8 deflate 1040 240$"), tostring(compactRows))
ok("compact: fewer rows than the JSON as it is", compactRows < 28, true)
ok("compact: black on a band only", tostring(rawget(photoFrame.black.points, "BOTTOM")) .. " " .. tostring(rawget(photoFrame.black, "height")), "nil " .. (8 + (compactRows + 1) * 8))
ok("a question photo: says the question went to Claude, and tells the window", tostring(printed[#printed]:find("Question envoyée à Claude", 1, true) ~= nil) .. " " .. tostring(questionPhotoDone), "true true")
writePages(output and output .. ".photo.json")
time = realTime

-- Next session: the same saved data, the addon loaded anew
frames = {}
ClaudeInWoWDB = db
local ns2 = load()
fire("ADDON_LOADED", "claude-in-wow")
fire("PLAYER_LOGIN")
ok("characters kept", ClaudeInWoWDB.characters["Arden Valcourt"].character.money, 1234567)
fire("PLAYER_ENTERING_WORLD")
fire("QUEST_TURNED_IN", 4242)
C_QuestLog.GetAllCompletedQuestIDs = function() return {} end -- as you leave
GetMoney = function() return 999 end
fire("PLAYER_LOGOUT")
ok("the quests handed in: read on entering, kept as you leave", ClaudeInWoWDB.characters["Arden Valcourt"].questsDone, "7 4242 5382")
ok("the next logout snapshots again", ClaudeInWoWDB.characters["Arden Valcourt"].character.money, 999)
ok("what was shown goes with a reload", tostring(ClaudeInWoWDB.characters["Arden Valcourt"].marks), "nil")

print(("%d passed, %d failed"):format(passed, failed))
