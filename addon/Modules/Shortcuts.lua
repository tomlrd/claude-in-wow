-- claude-in-wow module: the player's questions written beforehand, on the buttons of a
-- new, empty conversation and in the "+" menu; the player changes them, adds some, takes
-- some away, puts them in order, and gets the first ones back (the settings' tab on the
-- questions).
--   ns.db.shortcuts = { { kind, label, text, menu (false: not in the menu) } }, nil while they are the first ones.
--   kind: "bags", "quests", "level", "gear" (the first ones: their own name and question in the player's
--   language, until they are written over), "question" (the player's)

local addonName, ns = ...

local gsub, ipairs, max, strtrim, tremove = string.gsub, ipairs, math.max, strtrim, table.remove
local L, T = ns.L, ns.Theme

local MOST = 12
local LABEL = 40        -- characters of a button
local LINE, TEXT, MENU = 28, 58, 26 -- heights: a name, a question, whether it is in the menu

local KINDS = {
    bags = { icon = "Bag", label = "SUGGEST_BAGS", text = "ASK_BAGS", run = function(item) ns.Ask("bags", item.text) end },
    quests = { icon = "MapPin", label = "SUGGEST_QUESTS", text = "ASK_QUESTS" },
    level = { icon = "Clipboard", label = "SUGGEST_LEVEL", text = "ASK_LEVEL" },
    gear = { icon = "Check", label = "SUGGEST_GEAR", text = "ASK_GEAR" },
    question = { icon = "ArrowUp" },
}
local FIRST = { "bags", "quests", "level", "gear" }

local function Kind(item)
    return KINDS[item.kind] or KINDS.question
end

-- A text cut at a length, never in the middle of a letter.
local function Cut(text, length)
    if #text <= length then return text end
    return (gsub(text:sub(1, length), "[\128-\255]*$", "")) .. "\226\128\166"
end

local function Label(item)
    local kind = Kind(item)
    return item.label or kind.label and L[kind.label] or ""
end

local function Text(item)
    local kind = Kind(item)
    return item.text or kind.text and L[kind.text] or ""
end

-- The shortcuts, the first ones while none was changed.
local function List()
    if ns.db.shortcuts then return ns.db.shortcuts end
    local list = {}
    for index, kind in ipairs(FIRST) do list[index] = { kind = kind } end
    return list
end

-- The player's own, to change.
local function Own()
    ns.db.shortcuts = List()
    return ns.db.shortcuts
end

-- Those that ask something, { icon, label, tip, run }: for the empty conversation, or for
-- the "+" menu.
function ns.Shortcuts(inMenu)
    local shown = {}
    for _, item in ipairs(List()) do
        local kind, text = Kind(item), Text(item)
        local label = Label(item) ~= "" and Label(item) or text
        if text ~= "" and not (inMenu and item.menu == false) then
            shown[#shown + 1] = {
                icon = kind.icon, label = Cut(label, LABEL), tip = text,
                run = function()
                    if kind.run then return kind.run(item) end
                    ns.Ask("free", text)
                end,
            }
        end
    end
    return shown
end

function ns.EditShortcuts()
    ns.db.settingsTab = "questions"
    ns.OpenClaude("settings")
end

----------------------------------------------------------------------
-- The settings
----------------------------------------------------------------------

-- A shortcut: its name, its question, up, down, away.
local function Row(parent, editor)
    local row = CreateFrame("Frame", nil, parent)
    T.Box(row, 10, "none", "border")
    row.away = T.IconButton(row, "Trash", 12, L.SHORTCUT_REMOVE, function() editor:Change(function(list) tremove(list, row.index) end) end)
    row.away:SetPoint("TOPRIGHT", -6, -8)
    row.down = T.IconButton(row, "ArrowUp", 12, L.SHORTCUT_DOWN, function() editor:Move(row.index, 1) end)
    row.down.icon:SetTexCoord(0, 1, 1, 0)
    row.down:SetPoint("RIGHT", row.away, "LEFT", -2, 0)
    row.up = T.IconButton(row, "ArrowUp", 12, L.SHORTCUT_UP, function() editor:Move(row.index, -1) end)
    row.up:SetPoint("RIGHT", row.down, "LEFT", -2, 0)
    row.label = T.Edit(row, false, L.SHORTCUT_LABEL, function(text) editor:Write(row.index, "label", text) end)
    row.label:SetPoint("TOPLEFT", 8, -8)
    row.text = T.Edit(row, true, L.SHORTCUT_TEXT, function(text) editor:Write(row.index, "text", text) end)
    row.text:SetPoint("TOPLEFT", 8, -8 - LINE - 6)
    row.menu = T.Switch(row, function(on) editor:SetMenu(row.index, on) end)
    row.menu:SetPoint("BOTTOMRIGHT", -8, 7)
    row.menuLabel = T.Text(row, "sans", 12, "secondary")
    row.menuLabel:SetWordWrap(false)
    row.menuLabel:SetText(L.SHORTCUT_MENU)
    row.menuLabel:SetPoint("RIGHT", row.menu, "LEFT", -8, 0)
    function row:Fill(index, item, count, width)
        self.index = index
        self:SetWidth(width)
        self.label:SetSize(max(60, width - 16 - 3 * 26 - 8), LINE)
        self.label:SetValue(Label(item))
        self.up:SetAlpha(index > 1 and 1 or 0.3)
        self.down:SetAlpha(index < count and 1 or 0.3)
        self.text:SetSize(width - 16, TEXT)
        self.text:SetValue(Text(item))
        self.menu:SetChecked(item.menu ~= false)
        local height = 8 + LINE + 6 + TEXT + 6 + MENU + 4
        self:SetHeight(height)
        return height
    end
    return row
end

local function Editor(parent)
    local frame, rows, sure = CreateFrame("Frame", nil, parent), {}, false

    function frame:Change(fn)
        fn(Own())
        sure = false
        ns.RenderClaude()
    end

    function frame:Move(index, by)
        self:Change(function(list)
            local other = index + by
            if list[index] and list[other] then list[index], list[other] = list[other], list[index] end
        end)
    end

    -- What is typed is kept at once; nothing, or the first words, is the first ones.
    function frame:Write(index, part, text)
        local item = Own()[index]
        if not item then return end
        local kind = Kind(item)
        local first = kind[part] and L[kind[part]]
        item[part] = text ~= "" and text ~= first and text or nil
    end

    function frame:SetMenu(index, on)
        local item = Own()[index]
        if not item then return end
        item.menu = nil -- in it, when not said
        if not on then item.menu = false end
        ns.RenderClaude()
    end

    local add = T.Chip(frame, "Plus", L.SHORTCUT_ADD, function()
        frame:Change(function(list)
            if #list < MOST then list[#list + 1] = { kind = "question", label = L.SHORTCUT_NEW } end
        end)
        local row = rows[#List()]
        if row then row.text:Focus() end
    end)
    local reset = T.Chip(frame, "Trash", L.SHORTCUT_RESET, function()
        if sure then ns.db.shortcuts = nil end
        sure = not sure
        ns.RenderClaude()
    end)
    frame:SetScript("OnHide", function() sure = false end)

    function frame:Refresh(width)
        local list, y = List(), 0
        for index, item in ipairs(list) do
            rows[index] = rows[index] or Row(self, self)
            local row = rows[index]
            local height = row:Fill(index, item, #list, width)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, -y)
            row:Show()
            y = y + height + 8
        end
        for index = #list + 1, #rows do rows[index]:Hide() end
        add:SetAlpha(#list < MOST and 1 or 0.4)
        add:ClearAllPoints()
        add:SetPoint("TOPLEFT", 0, -y - 2)
        reset:SetShown(ns.db.shortcuts ~= nil)
        reset:SetLabel(sure and L.SHORTCUT_RESET_SURE or L.SHORTCUT_RESET)
        reset:ClearAllPoints()
        if add:GetWidth() + 8 + reset:GetWidth() > width then
            reset:SetPoint("TOPLEFT", 0, -y - 36)
            y = y + 34
        else
            reset:SetPoint("LEFT", add, "RIGHT", 8, 0)
        end
        y = y + 32
        self:SetSize(width, y)
        return y
    end
    return frame
end

ns.Module({
    key = "shortcuts", category = "questions", order = 20, fixed = true, title = "SHORTCUTS", tip = "SHORTCUTS_TIP", custom = Editor,
    settings = { { key = "shortcutsEdit", label = "SHORTCUTS_EDIT_MENU", default = true } },
})
