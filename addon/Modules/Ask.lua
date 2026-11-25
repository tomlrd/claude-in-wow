-- claude-in-wow: questions prepared in the game, to copy into the
-- assistant from the Claude window (ClaudeWindow.lua). Each carries what it
-- needs, read from the game when it is asked (no /reload needed), after a
-- first line the assistant recognises: "[claude-in-wow <version>] <kind>".
--   /claude              opens or closes the window
--   /claude photo        a photo of the game (Photo.lua)
--   /claude <question>   a free question, with the character and the quests (also
--                    what is written in the Claude window)
--   /claude bags         the question about the bags
--   /claude marks        the Claude window, waiting for the assistant's answer to
--                    paste (Marks.lua)
--   /claude help         how to use it

local addonName, ns = ...

local concat, floor, format, ipairs, pairs, sort = table.concat, math.floor, string.format, ipairs, pairs, table.sort
local gsub, lower, match, tonumber, tostring = string.gsub, string.lower, string.match, tonumber, tostring
local L = ns.L

local function Money(copper)
    copper = floor(copper or 0)
    local gold, silver = floor(copper / 10000), floor(copper / 100) % 100
    if gold > 0 then return format("%dg %ds %dc", gold, silver, copper % 100) end
    if silver > 0 then return format("%ds %dc", silver, copper % 100) end
    return format("%dc", copper % 100)
end

local function Quality(quality)
    return quality and _G["ITEM_QUALITY" .. quality .. "_DESC"] or nil
end

-- "a<sep>b<sep>c" from the parts given, the empty ones left out.
local function JoinWith(separator, ...)
    local parts = {}
    for index = 1, select("#", ...) do
        local part = select(index, ...)
        if part and part ~= "" then parts[#parts + 1] = tostring(part) end
    end
    return concat(parts, separator)
end

local function Join(...)
    return JoinWith(", ", ...)
end

-- What an item's tooltip says, after its other facts: "; Agilité +5;
-- Utiliser : ...; "description"", or "".
local function Effects(item)
    local text = JoinWith("; ", item.stats,
        item.equip and format("%s %s", ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:", item.equip) or nil,
        item.use and format("%s %s", ITEM_SPELL_TRIGGER_ONUSE or "Use:", item.use) or nil,
        item.text)
    return text ~= "" and "; " .. text or ""
end

----------------------------------------------------------------------
-- The parts of a question
----------------------------------------------------------------------

local function CharacterPart(data, out)
    local c = data.character
    if c then
        local name = c.surname and (c.name .. " " .. c.surname) or c.name
        local xp = c.xp and c.xpMax and c.xpMax > 0 and format("%s %d%%", L.XP, floor(c.xp / c.xpMax * 100)) or nil
        out[#out + 1] = format("%s: %s", L.CHARACTER, Join(name, format("%s %d %s", L.LEVEL, c.level or 0, c.class or ""),
            c.race, c.faction, Money(c.money), xp))
    end

    local where = data.location
    if where then
        local position = where.x and where.y and format("(%.1f, %.1f)", where.x, where.y) or nil
        local instance = where.instance and format("%s %s", L.INSTANCE, where.instance.name) or nil
        out[#out + 1] = format("%s: %s", L.WHERE, Join(where.zone, where.subZone ~= where.zone and where.subZone or nil,
            position, instance, where.resting and L.RESTING or nil))
    end

    local professions = {}
    for _, profession in ipairs(data.professions or {}) do
        professions[#professions + 1] = format("%s %s/%s", profession.name, tostring(profession.rank), tostring(profession.max))
    end
    if #professions > 0 then out[#out + 1] = format("%s: %s", L.PROFESSIONS, concat(professions, ", ")) end
end

local function QuestsPart(data, out)
    local quests = data.quests or {}
    out[#out + 1] = format("%s (%d):", L.QUESTS, #quests)
    for _, quest in ipairs(quests) do
        local objectives = {}
        for _, objective in ipairs(quest.objectives or {}) do
            if objective.text and objective.text ~= "" then objectives[#objectives + 1] = objective.text end
        end
        out[#out + 1] = format("- %d [%s] %s (%s)%s%s", quest.id or 0, tostring(quest.level), quest.title or "?", quest.zone or "?",
            (quest.ready or quest.complete) and ", " .. L.READY or "",
            #objectives > 0 and ": " .. concat(objectives, "; ") or "")
    end
end

local SLOT_ORDER = {
    "head", "neck", "shoulder", "back", "chest", "shirt", "tabard", "wrist", "hands", "waist", "legs", "feet",
    "finger1", "finger2", "trinket1", "trinket2", "mainHand", "offHand", "ranged",
}

local function EquipmentPart(data, out)
    local equipment = data.equipment
    if not equipment then return end
    out[#out + 1] = L.EQUIPPED .. ":"
    for _, slot in ipairs(SLOT_ORDER) do
        local item = equipment[slot]
        if item then out[#out + 1] = format("- %s: %d %s%s", slot, item.id or 0, item.name or "?", Effects(item)) end
    end
end

-- One line per item: ID, name, count, then what helps to decide.
local function ItemLine(id, item)
    local level = item.itemLevel and format(L.ITEM_LEVEL, item.itemLevel) or nil
    return format("- %d %s x%d: %s%s", id, item.name or "?", item.count or 1, Join(Quality(item.quality),
        item.subType and (item.type .. "/" .. item.subType) or item.type, item.slot, level,
        item.questItem and L.QUEST_ITEM or nil, item.startsQuest and format(L.STARTS_QUEST, item.startsQuest) or nil,
        item.bound and L.BOUND or nil, item.sell and format(L.SELLS, Money(item.sell)) or nil), Effects(item))
end

local function BagsPart(data, out)
    local bags = data.bags
    if not bags then return end
    out[#out + 1] = format("%s (%s):", L.BAGS, format(L.SLOTS_FREE, bags.free or 0, bags.slots or 0))

    local ids = {}
    for id in pairs(bags.items or {}) do ids[#ids + 1] = id end
    sort(ids, function(a, b) return (bags.items[a].name or "") < (bags.items[b].name or "") end)
    for _, id in ipairs(ids) do out[#out + 1] = ItemLine(id, bags.items[id]) end

    -- the bank as last opened (it can only be read open)
    local bank = ns.char and ns.char.bank
    out[#out + 1] = format("%s: %s", L.BANK, bank and format(L.BANK_NOTED, date("%Y-%m-%d %H:%M", bank.savedAt or 0),
        bank.free or 0, bank.slots or 0) or L.BANK_UNKNOWN)
end

----------------------------------------------------------------------
-- The questions
----------------------------------------------------------------------

local KINDS = {
    free = {
        collect = { character = true, location = true, professions = true, quests = true },
        parts = { CharacterPart, QuestsPart },
    },
    bags = {
        question = function() return L.ASK_BAGS end,
        collect = { character = true, location = true, professions = true, quests = true, equipment = true, bags = true },
        parts = { CharacterPart, QuestsPart, EquipmentPart, BagsPart },
    },
}

-- The text of a question of this kind ("free", "bags"), the game read now.
function ns.Question(kind, question)
    local spec = KINDS[kind]
    local data = ns.Collect({}, spec.collect)
    local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"
    local out = {
        format("[claude-in-wow %s] %s", version, kind),
        format("%s: %s", L.QUESTION, question or spec.question()),
    }
    for _, part in ipairs(spec.parts) do part(data, out) end
    return concat(out, "\n")
end

-- The question in the Claude window, sent in a photo or ready to copy; its
-- bubble says the question itself. wanted: what to read for it (Topics.lua).
function ns.Ask(kind, question, wanted)
    ns.ShowCopy(ns.Question(kind, question), question or KINDS[kind].question(), kind, wanted)
end

SLASH_CLAUDEINWOW1, SLASH_CLAUDEINWOW2 = "/claude", "/ciw"
SlashCmdList.CLAUDEINWOW = function(text)
    text = match(text or "", "^%s*(.-)%s*$")
    if text == "" then
        ns.ToggleClaude()
    elseif L.PHOTO_WORDS[lower(text)] then
        ns.TakePhoto()
    elseif L.HELP_WORDS[lower(text)] then
        DEFAULT_CHAT_FRAME:AddMessage("|cff4ec9b0claude-in-wow|r " .. L.USAGE)
    elseif L.BAGS_WORDS[lower(text)] then
        ns.Ask("bags")
    elseif L.MARKS_WORDS[lower(text)] then
        ns.PasteMarks()
    else
        ns.Ask("free", text)
    end
end

----------------------------------------------------------------------
-- Links in a question
----------------------------------------------------------------------

-- While the conversation shows, a Shift+click on an item, a quest, a spell... puts it in
-- the question, as it does in the game's chat. The chat comes first, when one is being
-- written in. What the game does with the same click when no chat takes it (splitting a
-- stack, following a quest) is put back. In the question sent, a link is its name and its
-- number: "[Linen Cloth] (item:2589)".
local NUMBERED = { item = true, quest = true, spell = true, enchant = true, achievement = true, currency = true, talent = true }

-- A text with its links as words, for Claude.
function ns.PlainLinks(text)
    text = gsub(text, "|A.-|a", "")
    text = gsub(text, "|T.-|t", "")
    text = gsub(text, "|H(%a+):([^|]*)|h(.-)|h", function(kind, rest, name)
        local id = NUMBERED[kind] and match(rest, "^(%d+)")
        return id and name .. " (" .. kind .. ":" .. id .. ")" or name
    end)
    text = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = gsub(text, "|cn[^:|]*:", "")
    text = gsub(text, "|r", "")
    return text
end

local function ChatTakes()
    local active = ChatFrameUtil and ChatFrameUtil.GetActiveWindow or ChatEdit_GetActiveWindow
    return active and active() ~= nil
end

-- Whether a click means a link for the question.
local function Wanted()
    return ns.On("linkClick") and IsModifiedClick("CHATLINK") and not ChatTakes()
end

local clicked -- the quest of the click under way: not put in twice

-- Puts back, once the click is over, what the game did with it.
local function PutBack(quest, followed)
    C_Timer.After(0, function()
        if StackSplitFrame and StackSplitFrame:IsShown() then StackSplitFrame:Hide() end
        if quest and ns.Game.QuestWatched(quest) ~= followed then
            if followed then ns.Game.WatchQuest(quest) else ns.Game.UnwatchQuest(quest) end
        end
    end)
end

local function Linked(link)
    link = ns.Clean(link)
    if type(link) ~= "string" or not Wanted() then return end
    local quest = tonumber(match(link, "|Hquest:(%d+)"))
    if quest and quest == clicked then return end
    if ns.InsertInQuestion(link) then PutBack(quest, quest and ns.Game.QuestWatched(quest)) end
end

-- The quest a frame under the mouse stands for (a line of the quest log or of a tracker,
-- an icon of the map): they say it in one of a few ways. Not all of them give its link to
-- the game's chat when none is being written in.
local function QuestOf(frame)
    for _ = 1, 4 do
        if not frame or frame.IsForbidden and frame:IsForbidden() then return nil end
        local quest, module = frame.Quest, frame.parentModule
        local id = frame.questID or frame.questId or type(quest) == "table" and (quest.Id or quest.questID)
            or module and (module == QuestObjectiveTracker or module == CampaignQuestObjectiveTracker) and frame.id
        id = ns.Clean(id)
        if type(id) == "number" and id > 0 then return id end
        frame = frame.GetParent and frame:GetParent()
    end
end

local function UnderMouse()
    if GetMouseFoci then return GetMouseFoci()[1] end
    return GetMouseFocus and GetMouseFocus()
end

local mouse, followed = CreateFrame("Frame"), nil
for _, event in ipairs({ "GLOBAL_MOUSE_DOWN", "GLOBAL_MOUSE_UP" }) do pcall(mouse.RegisterEvent, mouse, event) end
mouse:SetScript("OnEvent", function(_, event, button)
    if event == "GLOBAL_MOUSE_UP" then
        if not clicked then return end
        PutBack(clicked, followed)
        C_Timer.After(0, function() clicked = nil end)
        return
    end
    clicked = nil
    if button ~= "LeftButton" or not Wanted() then return end
    local quest = QuestOf(UnderMouse())
    local title = quest and ns.Game.QuestTitle(quest)
    if not title then return end
    local link = GetQuestLink and ns.Clean(GetQuestLink(quest)) or "|cffffff00|Hquest:" .. quest .. ":-1|h[" .. title .. "]|h|r"
    if not ns.InsertInQuestion(link) then return end
    clicked, followed = quest, ns.Game.QuestWatched(quest)
end)

if ChatFrameUtil and ChatFrameUtil.InsertLink then
    hooksecurefunc(ChatFrameUtil, "InsertLink", Linked)
elseif ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", Linked)
end

ns.Module({ key = "linkClick", category = "conversation", group = "GROUP_QUESTION", order = 50, title = "LINK_CLICK", tip = "LINK_CLICK_TIP" })
