-- claude-in-wow: the buttons of an answer. Claude proposes actions in a
-- block of its answer, the player clicks (or not): one click, one action, never
-- anything by itself. A closed list of actions, none that loses anything; what
-- a button says is written here from what it does, and its tooltip shows all of
-- it (a message's text, a macro's body), what kind of action it is (its badge: something
-- shown, the chat box, the game) and how it is undone: by the same button, for all that
-- can be. A message is only put in the chat box: the player sends it. The block, left out of the answer shown:
--   [claude-in-wow] boutons
--   chuchoter Torvald Grimm | Salut, tu viens à Uldaman ?
--   écrire /g | Quelqu'un pour Uldaman ?
--   inviter Torvald Grimm
--   équiper 10465
--   suivre 7840
--   quête 7840
--   carte 1425:84.5:41.2 | Lard
--   ouvrir sacs
--   macro Bandage | /use Bandage épais en soie
--   qui mage 60
-- It also proposes questions to ask next, and what to read in the game for them
-- (Topics.lua, Reads.lua): the click asks, in one photo with what was read.
--   [claude-in-wow] questions
--   Que font les gens de ma guilde ? | topics guild
--   Où est ma pierre de foyer ? | read GetBindLocation()

local addonName, ns = ...

local L = ns.L
local concat, find, format, gmatch, gsub, ipairs, lower, match, pairs, pcall, strtrim, sub, tonumber, type =
    table.concat, string.find, string.format, string.gmatch, string.gsub, ipairs, string.lower, string.match, pairs, pcall, strtrim, string.sub, tonumber, type

local MAX_BUTTONS = 8
ns.startedAt = time() -- what was shown before is no longer
local CHANNELS = { ["/g"] = true, ["/p"] = true, ["/s"] = true, ["/ra"] = true, ["/i"] = true, ["/o"] = true }

-- The words for each action, in French and English.
local WORDS = {
    chuchoter = "whisper", whisper = "whisper", ["écrire"] = "say", ecrire = "say", say = "say", inviter = "invite", invite = "invite",
    ["équiper"] = "equip", equiper = "equip", equip = "equip", suivre = "track", track = "track", macro = "macro", qui = "who", who = "who",
    ["quête"] = "quest", quete = "quest", quest = "quest", carte = "map", map = "map", ouvrir = "open", open = "open",
}

-- The windows of the game a button may open, and their names.
local OPENED = {
    sacs = "bags", sac = "bags", bags = "bags", personnage = "character", character = "character", ["réputations"] = "reputations", ["réputation"] = "reputations",
    reputations = "reputations", amis = "friends", friends = "friends", carte = "map", map = "map", ["quêtes"] = "quests", journal = "quests", quests = "quests",
}
local OPENERS = {
    bags = function() return OpenAllBags and (OpenAllBags() or true) end,
    character = function() return ToggleCharacter and (ToggleCharacter("PaperDollFrame", true) or true) end,
    reputations = function() return ToggleCharacter and (ToggleCharacter("ReputationFrame", true) or true) end,
    friends = function() return ToggleFriendsFrame and (ToggleFriendsFrame(1) or true) end,
    map = function()
        local here = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        return here and (ns.Game.OpenMap(here) or true)
    end,
    quests = function()
        local open = OpenQuestLog or ToggleQuestLog
        return open and (open() or true)
    end,
}

local function Say(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ec9b0claude-in-wow|r " .. text)
end

-- A text without the game's own codes: what Claude writes never becomes a link.
local function Bare(text)
    return strtrim((gsub(text or "", "[|%c]", "")))
end

-- The chat box opened with a text, for the player to send or not.
local function OpenChat(text)
    local open = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
    if open then open(text) end
end

-- A whisper begun to a player, for the player to finish and send.
function ns.Tell(name, text)
    local tell = ChatFrameUtil and ChatFrameUtil.SendTell or ChatFrame_SendTell
    if not tell then return OpenChat("/w " .. name .. " " .. text) end
    tell(name)
    local active = ChatFrameUtil and ChatFrameUtil.GetActiveWindow or ChatEdit_GetActiveWindow
    local box = active and active()
    if box and text ~= "" then box:Insert(text) end
end

----------------------------------------------------------------------
-- The actions: each gives a button { icon, label, tip, run } from what
-- follows its word, nil when it makes no sense. run() returns true once done, or what
-- undo(that) needs, then kept with the message: the button undoes it.
--   effect: "show" (only shows something), "chat" (the chat box), "game" (the game)
--   back: what undoes it: "button", "both" (the button or a /reload), "close", "chat", "none"
----------------------------------------------------------------------

local ACTIONS = {}

function ACTIONS.whisper(name, text)
    if name == "" then return nil end
    return { icon = "ArrowUp", label = format(L.BUTTON_WHISPER, name), tip = text, effect = "chat", back = "chat", run = function() ns.Tell(name, text) return true end }
end

function ACTIONS.say(channel, text)
    if not CHANNELS[channel] or text == "" then return nil end
    return { icon = "ArrowUp", label = format(L.BUTTON_SAY, channel), tip = text, effect = "chat", back = "chat", run = function() OpenChat(channel .. " " .. text) return true end }
end

function ACTIONS.invite(name)
    if name == "" then return nil end
    return { icon = "Plus", label = format(L.BUTTON_INVITE, name), tip = L.BUTTON_INVITE_TIP, effect = "game", back = "none", run = function()
        C_PartyInfo.InviteUnit(name)
        return true
    end }
end

function ACTIONS.equip(id)
    id = tonumber(id)
    if not id then return nil end
    local name = C_Item.GetItemNameByID(id)
    return { icon = "Check", label = format(L.BUTTON_EQUIP, name or ("item " .. id)), tip = L.BUTTON_EQUIP_TIP, item = id, effect = "game", back = "button", run = function()
        if InCombatLockdown() then return Say(L.BUTTON_COMBAT) end
        if (C_Item.GetItemCount(id) or 0) == 0 then return Say(L.BUTTON_NO_ITEM) end
        local worn = {} -- what may be replaced
        for slot = 1, 19 do worn[slot] = GetInventoryItemID("player", slot) or false end
        C_Item.EquipItemByName(id)
        return { worn = worn }
    end, undo = function(done)
        if InCombatLockdown() then return Say(L.BUTTON_COMBAT) end
        for slot, before in pairs(done.worn or {}) do
            if before and GetInventoryItemID("player", slot) == id and before ~= id then C_Item.EquipItemByName(before, slot) end
        end
        return true
    end }
end

function ACTIONS.track(id)
    id = tonumber(id)
    if not id then return nil end
    local name = ns.Game.QuestTitle(id)
    return { icon = "MapPin", label = format(L.BUTTON_TRACK, name or ("quest " .. id)), tip = L.BUTTON_TRACK_TIP, effect = "show", back = "button", run = function()
        if ns.Game.QuestWatched(id) then return true end
        ns.Game.WatchQuest(id)
        return { watched = true }
    end, undo = function()
        ns.Game.UnwatchQuest(id)
        return true
    end }
end

-- A quest of the log, opened in it.
function ACTIONS.quest(id)
    id = tonumber(id)
    if not id then return nil end
    local name = ns.Game.QuestTitle(id)
    return { icon = "Clipboard", label = format(L.BUTTON_QUEST, name or id), tip = L.BUTTON_QUEST_TIP, effect = "show", back = "close", run = function() return ns.ShowQuest(id) end }
end

-- A place: "map:x:y | its name", or a map alone.
function ACTIONS.map(place, name)
    local map, x, y = match(place, "^(%d+):([%d%.]+):([%d%.]+)$")
    map = tonumber(map or match(place, "^(%d+)$"))
    local zone = map and ns.MapName(map)
    if not zone then return nil end
    return { icon = "MapPin", label = format(L.BUTTON_MAP, name ~= "" and name or zone), tip = L.BUTTON_MAP_TIP, effect = "show", back = x and ns.Game.HasPins() and "both" or "close", session = true, run = function()
        local before = ns.Game.CurrentPin()
        if not ns.ShowOnMap(map, tonumber(x), tonumber(y)) then return true end
        ns.char.pinned = true -- a /reload takes it away
        return { before = before }
    end, undo = function(done)
        if done.before then ns.Game.Pin(done.before.map, done.before.x, done.before.y) else ns.Game.ClearPin() end
        return true
    end }
end

function ACTIONS.open(name)
    local window = OPENED[lower(name)] or OPENED[name]
    if not window then return nil end
    return { icon = window == "bags" and "Bag" or window == "map" and "MapPin" or "Clipboard", label = L.WINDOWS[window], tip = L.BUTTON_OPEN_TIP, effect = "show", back = "close", run = function()
        if InCombatLockdown() then return Say(L.BUTTON_COMBAT) end
        local ok, opened = pcall(OPENERS[window])
        if not ok or not opened then return Say(L.BUTTON_OPEN_NOT) end
        return true
    end }
end

-- A macro is added, never one of the player's changed.
function ACTIONS.macro(name, body)
    name, body = sub(name, 1, 16), gsub(body, "\\n", "\n")
    if name == "" or body == "" or #body > 255 then return nil end
    return { icon = "NewChat", label = format(L.BUTTON_MACRO, name), tip = body, effect = "game", back = "button", run = function()
        if InCombatLockdown() then return Say(L.BUTTON_COMBAT) end
        if (GetMacroIndexByName(name) or 0) > 0 then return Say(format(L.BUTTON_MACRO_THERE, name)) end
        local ok, index = pcall(CreateMacro, name, "INV_MISC_QUESTIONMARK", body)
        if not ok or not index then return Say(L.BUTTON_MACRO_FULL) end
        Say(format(L.BUTTON_MACRO_DONE, name))
        return { macro = name }
    end, undo = function() -- that one only, while it is as it was added
        if InCombatLockdown() then return Say(L.BUTTON_COMBAT) end
        local there = GetMacroBody and GetMacroBody(name)
        if there and strtrim(there) ~= strtrim(body) then return Say(format(L.BUTTON_MACRO_CHANGED, name)) end
        if there then DeleteMacro(name) end
        return true
    end }
end

function ACTIONS.who(text)
    if text == "" then return nil end
    return { icon = "MapPin", label = format(L.BUTTON_WHO, text), tip = L.BUTTON_WHO_TIP, effect = "show", back = "close", run = function()
        C_FriendList.SendWho(text)
        return true
    end }
end

----------------------------------------------------------------------
-- The block
----------------------------------------------------------------------

local function Button(line)
    local word, rest = match(line, "^%s*%-?%s*(%S+)%s*(.-)%s*$")
    local action = word and ACTIONS[WORDS[lower(word)] or WORDS[word] or ""]
    if not action then return nil end
    local first, second = match(rest, "^(.-)%s*|%s*(.*)$")
    return action(Bare(first or rest), Bare(second))
end

-- A question the player may ask with a click, and what is read in the game for
-- it: "Que fait ma guilde ? | topics guild | read GetBindLocation()".
local function Question(line)
    local text = strtrim(gsub(line, "^%s*%-?%s*", "", 1))
    local question, after = match(text, "^(.-)%s*|%s*(.*)$")
    question = Bare(question or text)
    if question == "" then return nil end
    local wanted, said = { topics = {}, reads = {} }, {}
    for part in gmatch((after or "") .. " | ", "(.-)%s+|%s") do
        local names, expression = match(part, "^%s*topics%s+([%l%s]+)$"), match(part, "^%s*read%s+(.+)$")
        for name in gmatch(names or "", "%l+") do
            wanted.topics[#wanted.topics + 1] = name
            said[#said + 1] = L.TOPICS[name] or name
        end
        if expression then
            wanted.reads[#wanted.reads + 1] = strtrim(expression)
            said[#said + 1] = strtrim(expression)
        end
    end
    local tip = #said > 0 and format(L.BUTTON_ASK_READS, concat(said, ", ")) or L.BUTTON_ASK_TIP
    return { icon = "ArrowUp", label = question, tip = tip, run = function()
        if InCombatLockdown() then return Say(L.BUTTON_COMBAT) end
        ns.Ask("free", question, wanted)
        return true
    end }
end

-- The lines of a block of an answer, each made a button, added to a list; and
-- the answer without the block (its code block goes with it).
local function TakeBlock(text, titles, make, list)
    local start, stop
    for _, title in ipairs(titles) do
        start, stop = find(text, "%[claude%-in%-wow%] *" .. title .. "[^\n]*")
        if start then break end
    end
    if not start then return text end
    local finish, found = stop, false
    for line, after in gmatch(sub(text, stop + 1), "\n([^\n]*)()") do
        if match(line, "^%s*```") or match(line, "^%s*$") and found then break end
        local button = make(line)
        if button then
            found = true
            if #list < MAX_BUTTONS then list[#list + 1] = button end
        end
        finish = stop + after - 1
    end
    local before, rest = sub(text, 1, start - 1), sub(text, finish + 1)
    if match(before, "```[^\n]*\n%s*$") then
        before, rest = gsub(before, "```[^\n]*\n%s*$", ""), gsub(rest, "^%s*```", "", 1)
    end
    return strtrim(concat({ strtrim(before), strtrim(rest) }, "\n\n"))
end

-- The strings of an answer (import strings for other addons), each made a button
-- that shows it to copy; and the answer without them:
--   [claude-in-wow] string Foire de Sombrelune
--   !TA1cVTTnq4...
local function TakeStrings(text, list)
    while true do
        local start, finish, name, body = find(text, "```[^\n]*\n%s*%[claude%-in%-wow%] *[sS]tring *([^\n]*)\n%s*([^%s`]+)%s*\n```")
        if not start then return text end
        if #list < MAX_BUTTONS and body:sub(1, 2) ~= "{{" then
            name = strtrim(Bare(name))
            list[#list + 1] = {
                effect = "show", back = "close", icon = "Copy", label = format(L.BUTTON_STRING, name ~= "" and name or "?"), tip = format(L.BUTTON_STRING_TIP, #body),
                run = function() ns.CopyText(body) end,
            }
        end
        text = strtrim(strtrim(sub(text, 1, start - 1)) .. "\n\n" .. strtrim(sub(text, finish + 1)))
    end
end

-- A way to follow, made a button (Route.lua); and the answer without it.
local function TakeRoute(text, list)
    local start, finish, name, body = find(text, "```[^\n]*\n%s*%[claude%-in%-wow%] *[rR]oute *([^\n]*)\n(.-)\n?%s*```")
    if not start then return text end
    local steps = ns.ParseRoute(body)
    if ns.On("route") and #steps > 0 then
        name = Bare(name)
        local key = name .. "\n" .. body
        list[#list + 1] = {
            icon = "MapPin", label = format(L.ROUTE_START, #steps), tip = ns.RouteText(steps), effect = "show", back = "both", undoLabel = L.ROUTE_STOP,
            on = function() return ns.RouteIs(key) end,
            run = function() return ns.StartRoute(key, name, steps) end,
            undo = function() ns.StopRoute() return true end,
        }
    end
    return strtrim(strtrim(sub(text, 1, start - 1)) .. "\n\n" .. strtrim(sub(text, finish + 1)))
end

-- How Claude came to its answer, in short; and the answer without it.
local function TakeWhy(text)
    local start, finish, body = find(text, "```[^\n]*\n%s*%[claude%-in%-wow%] *[wW]hy[^\n]*\n(.-)\n?%s*```")
    if not start then return text end
    return strtrim(strtrim(sub(text, 1, start - 1)) .. "\n\n" .. strtrim(sub(text, finish + 1))), ns.On("why") and strtrim(body) ~= "" and strtrim(body) or nil
end

-- Whether a button's action is done and may be undone: it then undoes it. done: what its
-- run gave, kept with the message.
function ns.ButtonUndoes(button, done)
    if button.on then return button.on() end
    if not button.undo or type(done) ~= "table" then return false end
    return not button.session or done.started == ns.startedAt
end

-- The button clicked: does it, or undoes it; kept with its message.
function ns.ClickButton(message, index, button)
    message.done = message.done or {}
    if ns.ButtonUndoes(button, message.done[index]) then
        if button.undo(message.done[index]) then message.done[index] = nil end
    else
        local done = button.run()
        if not done then return end
        if type(done) == "table" then done.started = ns.startedAt end
        message.done[index] = done
    end
    ns.RenderClaude()
end

-- The badges: what kind of action a button is.
local EFFECTS = { show = "accent", chat = "gold", game = "clay" }

function ns.ButtonBadge(button)
    if not button.effect then return nil end
    return L.EFFECT[button.effect], EFFECTS[button.effect]
end

-- What it says under the mouse: what it does, its kind, how it is undone.
function ns.ButtonTip(button)
    GameTooltip:SetText(button.label, 1, 1, 1)
    if button.tip and button.tip ~= "" then GameTooltip:AddLine(button.tip, 0.76, 0.75, 0.71, true) end
    if not button.effect then return end
    local r, g, b = ns.Theme.Color(EFFECTS[button.effect])
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L.EFFECT_TIP[button.effect], r, g, b, true)
    if button.back then GameTooltip:AddLine(L.UNDO_TIP[button.back], 0.6, 0.6, 0.6, true) end
end

-- The buttons of an answer, nil without any: strings, a route, actions, then questions;
-- its text without their blocks; and how Claude came to it, nil when it does not say.
function ns.ButtonsBlock(text)
    local list = {}
    local function None() end
    local why
    text = text or ""
    text, why = TakeWhy(text)
    text = TakeRoute(text, list)
    text = TakeStrings(text, list)
    text = TakeBlock(text, { "[bB]outons", "[bB]uttons" }, ns.On("actions") and Button or None, list)
    text = TakeBlock(text, { "[qQ]uestions" }, ns.On("chips") and Question or None, list)
    return #list > 0 and list or nil, text, why
end

ns.Module({ key = "chips", category = "conversation", order = 40, title = "CHIPS", tip = "CHIPS_TIP" })
ns.Module({ key = "actions", category = "limits", limit = true, order = 60, title = "ACTIONS", tip = "ACTIONS_TIP" })
ns.Module({ key = "why", category = "answers", order = 35, title = "WHY_MODULE", tip = "WHY_MODULE_TIP" })
