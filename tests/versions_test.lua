-- Offline test of claude-in-wow on one version of the game: the stand-in game of
-- addon_test.lua, with only the functions Blizzard documents for that version (the
-- list made by tools/versions.mjs), and the older ones of the Classic versions.
-- The addon is loaded, logged in, its window, settings and every reading used:
-- nothing may fail.
-- lua versions_test.lua <addon folder> <versions.lua> <version>

local folder, list, version = arg[1], arg[2], arg[3]
local source = io.open((arg[0]:match("^(.*[/\\])") or "") .. "addon_test.lua"):read("*a")
local stop = source:find("%-%- Load the addon in %.toc order")
local loadIt = source:match("(%-%- Load the addon in %.toc order.-\n)frames = {}")

local body = source:sub(1, stop - 1) .. [==[
local INTERFACE = { live = 120105, classic = 50504, classic_titan = 38002, classic_anniversary = 20506, classic_era = 11509, forever = 16001 }
local version = VERSION_TESTED
local interface = INTERFACE[version]
local old = interface < 100000 and version ~= "forever"
GetBuildInfo = function() return "x.y.z", "1", "Nov 25 2026", interface end

-- what addon_test.lua adds as it goes
C_AddOns.DoesAddOnExist = C_AddOns.DoesAddOnExist or function() return false end
C_AddOns.IsAddOnLoadable = C_AddOns.IsAddOnLoadable or function() return false end
C_AddOns.LoadAddOn = C_AddOns.LoadAddOn or function() return false end
C_Sound = C_Sound or { IsPlaying = function() return false end }
PlaySoundFile = PlaySoundFile or function() return true, 1 end
StopSound = StopSound or function() end

local plainFrame = CreateFrame
CreateFrame = function(...)
    local frame = plainFrame(...)
    frame.GetHighlightTexture = function() return setmetatable({}, stub) end
    return frame
end

-- only what that version has
local known = dofile(VERSIONS_LIST)[version]
for name, space in pairs(_G) do
    if type(name) == "string" and name:match("^C_") and type(space) == "table" then
        local any = false
        for fn in pairs(space) do
            if known[name .. "." .. fn] then any = true elseif type(space[fn]) == "function" then space[fn] = nil end
        end
        if not any and not known[name] then _G[name] = nil end
    end
end
if version ~= "forever" then
    RegionalUniqueNamesEnabled = nil
    realmName = "Sulfuron"
end
ContainerFrameCombinedBags = nil
local containers = {}
if old then
    C_TooltipInfo, TooltipDataProcessor = nil, nil
    for tab = 1, 9 do Enum.BagIndex["CharacterBankTab_" .. tab], Enum.BagIndex["AccountBankTab_" .. tab] = nil, nil end
    for bag = 1, 7 do Enum.BagIndex["BankBag_" .. bag] = 4 + bag end
    GetNumQuestLogEntries = function() return #QUESTS, 4 end
    GetQuestLogTitle = function(i)
        local q = QUESTS[i]
        return q.title, q.level, q.suggestedGroup, q.isHeader, nil, q.questID == 7029 and 1 or nil, 1, q.questID
    end
    GetQuestLogIndexByID = function(id) for i, q in ipairs(QUESTS) do if q.questID == id then return i end end return 0 end
    GetQuestTagInfo = function(id) if id == 7064 then return 81, "Donjon" end end
    GetQuestsCompleted = function() return { [5382] = true, [7] = true } end
    AddQuestWatch = function() end
    GetNumFactions = function() return 2 end
    GetFactionInfo = function(i) if i == 1 then return "Classic", nil, 4, 0, 3000, 0, false, true, true, false, false end return "Fossoyeuse", "", 6, 9000, 21000, 12000, false, true, false, false, false end
    GetNumTalentTabs = function() return 1 end
    GetTalentTabInfo = function() return "Givre", 1, 31 end
    GetNumTalents = function() return 1 end
    GetTalentInfo = function() return "Eclair de givre amélioré", 1, 1, 2, 5, 5 end
    GetNumSpellTabs = function() return 1 end
    GetSpellTabInfo = function() return "Givre", 1, 0, 1 end
    GetSpellBookItemName = function() return "Eclair de givre", "Rang 8" end
    GetTradeSkillLine = function() return "Ingénierie", 235, 300 end
    GetNumTradeSkills = function() return 2 end
    GetTradeSkillInfo = function(i) if i == 1 then return "Explosifs", "header" end return "Dynamite lourde", "medium", 3 end
    GetItemStats = function() return { ITEM_MOD_STAMINA_SHORT = 5 } end
    ContainerFrame_Update = function() end
    ContainerFrame1 = setmetatable({ GetFrameLevel = function() return 1 end, GetName = function() return "ContainerFrame1" end, size = 1, GetID = function() return 0 end, IsShown = function() return true end }, stub)
    ContainerFrame1Item1 = setmetatable({ GetID = function() return 1 end, CreateTexture = function() return setmetatable({}, stub) end }, stub)
    local hook = hooksecurefunc
    hooksecurefunc = function(target, name, fn)
        if type(target) == "string" then
            local before = _G[target]
            _G[target] = function(...) before(...) name(...) end
            return
        end
        return hook(target, name, fn)
    end
end
IsModifiedClick = IsModifiedClick or function() return false end
GameTooltip_Hide = GameTooltip_Hide or function() end
BNGetNumFriends = BNGetNumFriends or function() return 0 end
]==] .. loadIt .. [==[
frames = {}
local done, problem = pcall(function()
    local ns = load()
    fire("ADDON_LOADED", "claude-in-wow")
    fire("PLAYER_LOGIN")
    fire("PLAYER_ENTERING_WORLD")
    local function Drain() for _ = 1, 30 do local due = timers timers = {} if #due == 0 then break end for _, fn in ipairs(due) do fn() end end end
    Drain()
    local db = ClaudeInWoWDB
    ok(version .. ": the version told", db.game.flavor, ({ live = "retail", classic = "mop", classic_titan = "wrath", classic_anniversary = "tbc", classic_era = "era", forever = "forever" })[version])
    local key = version == "forever" and "Arden Valcourt" or "Arden - Sulfuron"
    ok(version .. ": the character's key", db.characters[key] ~= nil, true)
    fire("QUEST_TURNED_IN", 4242)
    fire("BANKFRAME_OPENED")
    Drain()
    fire("BANKFRAME_CLOSED")
    fire("PLAYER_LOGOUT")
    local char = db.characters[key]
    ok(version .. ": the quests", char.quests and #char.quests, old and 4 or 3)
    ok(version .. ": one complete", char.quests[2].complete, true)
    ok(version .. ": the handed in ones", char.questsDone, "7 4242 5382")
    ok(version .. ": the bags", char.bags and char.bags.items[2770].count, 20)

    -- the window, an answer with every kind of link, the settings
    ns.OpenClaude()
    local text = "[Lard](quest:7029) [x](quest:5382) [y](item:2770) [z](npc:14731) [w](zone:1425) [v](map:1425:10:20) **gras** Orgrimmar\n\n```\n[claude-in-wow] questions\nOù est Lard ? | topics guild\n```\n\n```\n[claude-in-wow] boutons\nsuivre 7029\n```"
    local before = #frames
    ns.ShowCopy("[claude-in-wow] free\n\nOù ?", "Où ?", "free")
    Drain()
    local question
    for _, tab in ipairs(char.chat.tabs) do question = tab.messages[#tab.messages] end
    question.state, question.answered = "sent", nil
    ns.TakeInbox("[claude-in-wow réponse " .. question.at .. " session=ab n=1 s=3 m=haiku-5.5 c=9 t=9000 r=500 d=8000,0,500,0,500,1]\n\n" .. text)
    ok(version .. ": an answer shown", char.chat.tabs[1].messages[2].role, "claude")
    ns.MarkdownInline(text)
    ns.ShowOnMap(1425, 10, 20)
    for _, button in ipairs((ns.ButtonsBlock(text)) or {}) do if button.icon == "MapPin" then button.run() end end
    for _, link in ipairs({ "ciwquest:7029", "ciwitem:2770", "ciwnpc:1", "ciwmap:1425:1:2", "ciwzone:1425" }) do
        for _, f in ipairs(frames) do if f.scripts.OnHyperlinkEnter then f.scripts.OnHyperlinkEnter(f, link, "x") f.scripts.OnHyperlinkClick(f, link, "x", "LeftButton") break end end
    end
    ns.OpenClaude("settings")
    for _, f in ipairs(frames) do if f.category and f.label and f.scripts.OnClick then f.scripts.OnClick(f) end end

    -- every reading
    local answered
    for _, topic in ipairs({ "guild", "friends", "groups", "reputations", "currencies", "talents", "spells", "stats", "recipes", "achievements", "lockouts", "calendar", "played", "chat" }) do
        answered = nil
        ns.Gather({ topic }, function(data) answered = data end)
        Drain()
        ok(version .. ": reading " .. topic, answered ~= nil and type(answered[topic]) == "table" and not answered[topic].error, true)
        if old and topic == "reputations" then ok(version .. ": a reputation", answered.reputations.factions[1] and answered.reputations.factions[1].name, "Fossoyeuse") end
        if old and topic == "talents" then ok(version .. ": a talent", answered.talents.trees[1].talents[1].rank, 5) end
        if old and topic == "spells" then ok(version .. ": a spell", answered.spells.spells[1].name, "Eclair de givre") end
        if old and topic == "recipes" then ok(version .. ": a recipe", answered.recipes.known[1].name, "Dynamite lourde") end
    end
    if old then ContainerFrame_Update(ContainerFrame1) end
    ns.TakePhoto()
    for _, entry in ipairs(db.errors) do
        ok(version .. ": no error of its own", entry.kind == "companion" and entry.message or nil, nil)
    end
end)
if not done then
    failed = failed + 1
    print("FAIL " .. version .. ": " .. tostring(problem))
end
print(("%-20s %d passed, %d failed"):format(version, passed, failed))
]==]

VERSION_TESTED, VERSIONS_LIST = version, list
arg = { [0] = arg[0], folder, "unused" }
assert((loadstring or load)(body, "@versions"))()
