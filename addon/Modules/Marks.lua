-- claude-in-wow: the assistant's marks on the bags. After its answer
-- about the bags, the assistant gives a block that comes back with the answer
-- pasted in the Claude window (also opened by /claude marks or a Ctrl+click on
-- the bags' button), where a button applies it:
--   [claude-in-wow] marks
--   sell 11988 Agility and Stamina, of no use to a mage
--   destroy 17781 quest already handed in
-- Each line: an action word (English or French), an item ID, a reason. The
-- pasted marks replace the earlier ones. Each shows as a small icon on the
-- item in the bags, whoever draws them (BagSlots.lua), and as a line in its tooltip, and
-- goes once its item has left the bags.
-- ns.char.marks = { [itemID] = { action, reason, at } }; ns.char.marksOf: the answer
-- they came with (its time)

local addonName, ns = ...

local find, format, gsub, lower, match, gmatch, sub = string.find, string.format, string.gsub, string.lower, string.match, string.gmatch, string.sub
local concat, ipairs, next, pairs, pcall, time, tonumber, type = table.concat, ipairs, next, pairs, pcall, time, tonumber, type
local L = ns.L

local ICON_SIZE = 14

local ACTIONS = {
    quest = { icon = "Interface\\GossipFrame\\ActiveQuestIcon", r = 1, g = 0.82, b = 0 },
    use = { icon = "Interface\\Buttons\\UI-MicroStream-Green", r = 0.3, g = 1, b = 0.3 },
    keep = { icon = "Interface\\RaidFrame\\ReadyCheck-Ready", r = 0.3, g = 1, b = 0.3 },
    bank = { icon = "Interface\\Minimap\\Tracking\\Banker", r = 0.4, g = 0.75, b = 1 },
    auction = { icon = "Interface\\Minimap\\Tracking\\Auctioneer", r = 1, g = 0.82, b = 0 },
    sell = { icon = "Interface\\MoneyFrame\\UI-GoldIcon", r = 1, g = 0.82, b = 0 },
    destroy = { icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up", r = 1, g = 0.3, b = 0.3 },
}
local ORDER = { "quest", "use", "keep", "bank", "auction", "sell", "destroy" }

-- The words the assistant may write, accents left out, in English or French.
local WORDS = {
    quest = "quest", rendre = "quest", quete = "quest",
    use = "use", equip = "use", utiliser = "use", equiper = "use", manger = "use",
    keep = "keep", garder = "keep",
    bank = "bank", banque = "bank",
    ah = "auction", auction = "auction", hv = "auction", encheres = "auction",
    sell = "sell", vendor = "sell", vendre = "sell", marchand = "sell",
    destroy = "destroy", detruire = "destroy",
}

local ACCENTS = { ["\195\169"] = "e", ["\195\168"] = "e", ["\195\170"] = "e", ["\195\137"] = "e" } -- é è ê É

local function Word(text)
    text = lower(text)
    for accented, plain in pairs(ACCENTS) do text = gsub(text, accented, plain) end
    return WORDS[text]
end

----------------------------------------------------------------------
-- Reading the pasted block
----------------------------------------------------------------------

-- { [itemID] = mark }, how many, and the lines not understood.
function ns.ParseMarks(text)
    local marks, count, skipped = {}, 0, {}
    for line in gmatch((text or "") .. "\n", "([^\r\n]*)\r?\n") do
        line = match(line, "^%s*(.-)%s*$")
        line = gsub(line, "^[%-%*]%s+", "") -- a list's dash
        local word, id, reason = match(line, "^(%S+)%s+(%d+)(.*)$")
        local action = word and Word(word)
        id = tonumber(id)
        if action and id then
            reason = gsub(reason, "^[%s:%-]+", "")
            reason = gsub(reason, "^\226\128[\147\148]%s*", "") -- – or —
            if not marks[id] then count = count + 1 end
            marks[id] = { action = action, reason = reason ~= "" and reason or nil, at = time() }
        elseif line ~= "" and not match(line, "^%[") then -- the block's first line starts with [
            skipped[#skipped + 1] = line
        end
    end
    return marks, count, skipped
end

-- The marks block of an answer, from its "[claude-in-wow]" line to the
-- end of its code block, and how many marks it holds; nil without marks.
function ns.MarksBlock(text)
    local start = find(text or "", "%[claude%-in%-wow%]")
    if not start then return nil end
    local block = sub(text, start)
    local fence = find(block, "\n%s*```")
    if fence then block = sub(block, 1, fence - 1) end
    local _, count = ns.ParseMarks(block)
    if count == 0 then return nil end
    return block, count
end

----------------------------------------------------------------------
-- Drawing them
----------------------------------------------------------------------

-- The item's mark, if it has one of a known action.
local function MarkOf(itemID)
    local marks = ns.On("marks") and ns.char and ns.char.marks
    local mark = itemID and marks and marks[itemID]
    return type(mark) == "table" and ACTIONS[mark.action] and mark or nil
end

-- A bag slot's icon, shown for a marked item, hidden otherwise.
local function Paint(button, itemID)
    local mark = MarkOf(itemID)
    local icon = button.claudeInWoWMark
    if not mark then
        if icon then icon:Hide() end
        return
    end
    if not icon then
        icon = button:CreateTexture(nil, "OVERLAY", nil, 7)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        button.claudeInWoWMark = icon
    end
    icon:SetTexture(ACTIONS[mark.action].icon)
    icon:Show()
end

-- Each bag frame known, redrawn when the marks change.
local redraws = {}

local function Redraw()
    for _, redraw in ipairs(redraws) do pcall(redraw) end
    ns.EachBagSlot(Paint)
end

local function Any()
    local marks = ns.On("marks") and ns.char and ns.char.marks
    return marks and next(marks) ~= nil
end

-- The game's own bags, after each time it draws them.
local function HookGameBags()
    for _, redraw in ipairs(ns.Game.OnGameBags(function(button, bag, slot) Paint(button, C_Container.GetContainerItemID(bag, slot)) end)) do
        redraws[#redraws + 1] = redraw
    end
end

-- A line in the item's tooltip, wherever the item shows.
local function HookTooltips()
    ns.Game.OnItemTooltip(function(tooltip, itemID)
        local mark = MarkOf(itemID)
        if not mark or not tooltip.AddLine then return end
        local action = ACTIONS[mark.action]
        tooltip:AddLine(format("|T%s:%d|t %s%s", action.icon, ICON_SIZE, L.MARK[mark.action],
            mark.reason and (L.COLON .. mark.reason) or ""), action.r, action.g, action.b, true)
    end)
end

----------------------------------------------------------------------
-- The marks' life
----------------------------------------------------------------------

local function Say(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ec9b0claude-in-wow|r " .. text)
end

-- Items marked and seen in the bags this session: one gone from the bags
-- since (sold, banked, destroyed, used) loses its mark. Marks of items not
-- seen yet stay (the bags may not be read at login yet).
local seen = {}

local function Prune()
    local marks = ns.char and ns.char.marks
    if not marks or not next(marks) then return end

    local present = {}
    for _, bag in ipairs(ns.BAGS) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local id = C_Container.GetContainerItemID(bag, slot)
            if id then present[id] = true end
        end
    end

    local changed = false
    for id in pairs(marks) do
        if present[id] then
            seen[id] = true
        elseif seen[id] then
            marks[id], seen[id] = nil, nil
            changed = true
        end
    end
    if changed then Redraw() end
    return changed
end

-- "8 to sell, 2 to destroy" in the actions' order.
local function Counts(marks)
    local counts = {}
    for _, mark in pairs(marks) do counts[mark.action] = (counts[mark.action] or 0) + 1 end -- parsed: known actions
    local parts = {}
    for _, action in ipairs(ORDER) do
        if counts[action] then parts[#parts + 1] = format("%d %s", counts[action], L.MARK_COUNT[action]) end
    end
    return concat(parts, ", ")
end

-- The pasted text taken: its marks replace the earlier ones.
function ns.ApplyMarks(text)
    if not ns.char then return end
    local marks, count, skipped = ns.ParseMarks(text)
    if count == 0 then
        Say(L.MARKS_NONE)
        return
    end
    ns.char.marks = marks
    seen = {}
    Prune()
    ns.FindBagSlots()
    Redraw()
    Say(format(L.MARKS_SET, count, Counts(marks)))
    if #skipped > 0 then Say(format(L.MARKS_SKIPPED, #skipped, skipped[1])) end
end

-- Whether an answer's marks are those on the bags.
function ns.MarksShown(message)
    return ns.char and ns.char.marksOf == message.at and ns.char.marks and next(ns.char.marks) ~= nil or false
end

-- An answer's button: its marks shown on the bags, or taken off.
function ns.ToggleMarks(message, block)
    if ns.MarksShown(message) then
        ns.ClearMarks()
    else
        ns.ApplyMarks(block)
        ns.char.marksOf = message.at
    end
    message.applied = true
    ns.RenderClaude()
end

function ns.ClearMarks()
    if ns.char then ns.char.marks, ns.char.marksOf = nil, nil end
    seen = {}
    Redraw()
    Say(L.MARKS_CLEARED)
end

-- The Claude window, its box waiting for the answer to paste ("+" menu:
-- clear the marks).
function ns.PasteMarks()
    ns.OpenClaude("paste")
end

-- The marks go in the snapshot (they are the character's own) and the photo.
ns.AddCollector("marks", function(char)
    if char ~= ns.char then char.marks = ns.char and ns.char.marks end
end)

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if ns.char then ns.char.marks, ns.char.marksOf = nil, nil end -- a /reload takes them off
        HookGameBags()
        HookTooltips()
        ns.WatchBagSlots(Any, Redraw)
    end
    if not Prune() and Any() then ns.EachBagSlot(Paint) end -- items moved
end)

----------------------------------------------------------------------
-- The module
----------------------------------------------------------------------

-- Clearing the marks, when there are some.
local function Clear(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder.chip = ns.Theme.Chip(holder, "Trash", L.CLEAR_MARKS, function()
        ns.ClearMarks()
        ns.RenderClaude()
    end)
    holder.chip:SetPoint("TOPLEFT")
    function holder:Refresh(width)
        local some = ns.char and ns.char.marks and next(ns.char.marks) ~= nil
        self.chip:SetShown(some and true or false)
        self:SetSize(width, some and 28 or 1)
        return some and 28 or 0
    end
    return holder
end

ns.Module({ key = "marks", category = "bags", order = 10, title = "MARKS_MODULE", tip = "MARKS_MODULE_TIP", changed = function() Redraw() end, custom = Clear })
