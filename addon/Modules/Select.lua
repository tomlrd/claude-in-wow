-- claude-in-wow module: the conversation's text selected with the mouse, as in any
-- window: drag over it (a double click takes the paragraph), then Ctrl+C. The game's
-- texts cannot be selected, but tell which letter is under a point and where letters
-- are (as the game's own chat does it, ScrollingMessageFrame.lua); the letters are
-- counted in the text as it is written, colour codes and links included. Only the
-- game may write the clipboard: while Ctrl is held, the selected text waits, selected,
-- in a box out of sight, and the game copies it.

local addonName, ns = ...

local concat, gsub, ipairs, max, min, pcall, sub = table.concat, string.gsub, ipairs, math.max, math.min, pcall, string.sub
local L, T = ns.L, ns.Theme

local MOVED = 3        -- a click that moves less is no selection
local DOUBLE = 0.35    -- seconds between the two clicks of a double one
local SCROLL = 10      -- each time, over or under the conversation

ns.Module({ key = "select", category = "conversation", order = 60, title = "SELECT_MODULE", tip = "SELECT_MODULE_TIP", changed = function() ns.ClearSelection() end })

-- A text as written without the game's codes: what one reads.
local function Plain(raw)
    raw = gsub(raw, "|T.-|t ?", "")
    raw = gsub(raw, "|A.-|a ?", "")
    raw = gsub(raw, "|H.-|h", "")
    raw = gsub(raw, "|h", "")
    raw = gsub(raw, "|cn.-:", "")
    raw = gsub(raw, "|c%x%x%x%x%x%x%x%x", "")
    raw = gsub(raw, "|r", "")
    raw = gsub(raw, "|n", "\n")
    raw = gsub(raw, "||", "|")
    return raw
end

----------------------------------------------------------------------
-- What is selected
----------------------------------------------------------------------

-- from and to: { text (a font string), raw (its text then), index }, from the press
-- to the cursor; in the conversation's order once Ends has put them so.
local from, to, dragging, pressX, pressY, lastPress
local layer, box, highlights, returnTo

local function Cursor(region)
    local scale = region:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

-- The letter of the conversation nearest to a point: { text, raw, index }, and its
-- place in the list (ns.ConversationTexts).
local function At(list, x, y)
    local best, place, distance
    for index, entry in ipairs(list) do
        local text = entry.text
        local top, bottom, left, right = text:GetTop(), text:GetBottom(), text:GetLeft(), text:GetRight()
        if top and bottom then
            local away = y > top and y - top or y < bottom and bottom - y or 0
            if not distance or away < distance then best, place, distance = entry, index, away end
            if away == 0 then
                best, place = entry, index
                break
            end
        end
    end
    if not best then return nil end
    local text, raw = best.text, best.text:GetText() or ""
    local top, bottom, left, right = text:GetTop(), text:GetBottom(), text:GetLeft(), text:GetRight()
    local index
    if y > top then
        index = 1
    elseif y < bottom then
        index = #raw + 1
    else
        local ok, found = pcall(text.FindCharacterIndexAtCoordinate, text, min(max(x, left + 0.5), right - 0.5), min(max(y, bottom + 0.5), top - 0.5))
        index = ok and found or nil
    end
    return index and { text = text, raw = raw, index = index } or nil, place
end

local function PlaceOf(list, point)
    for index, entry in ipairs(list) do
        if entry.text == point.text then return index end
    end
end

-- The selection's ends in the conversation's order, with their places in the list;
-- nil without one, or when a text of it has changed.
local function Ends(list)
    if not from or not to then return nil end
    local first, last = PlaceOf(list, from), PlaceOf(list, to)
    if not first or not last or from.text:GetText() ~= from.raw or to.text:GetText() ~= to.raw then return nil end
    if first > last or first == last and from.index > to.index then return to, from, last, first end
    return from, to, first, last
end

-- The part of a text selected: its first letter, and the one after its last.
local function Span(list, index, start, stop, first, last)
    local raw = list[index].text:GetText() or ""
    return index == first and start.index or 1, index == last and stop.index or #raw + 1, raw
end

-- The selected text, as it reads; nil without any.
local function Selected()
    local list = ns.ConversationTexts()
    local start, stop, first, last = Ends(list)
    if not start then return nil end
    local parts = {}
    for index = first, last do
        local low, high, raw = Span(list, index, start, stop, first, last)
        local entry = list[index]
        if index > first then parts[#parts + 1] = entry.gap end
        if low == 1 then parts[#parts + 1] = entry.before end
        parts[#parts + 1] = Plain(sub(raw, low, high - 1))
    end
    local text = concat(parts)
    return text ~= "" and text or nil
end

----------------------------------------------------------------------
-- Showing it
----------------------------------------------------------------------

local function Highlight(index)
    if not highlights[index] then
        local texture = T.Line(layer, "accent")
        texture:SetAlpha(0.4)
        highlights[index] = texture
    end
    return highlights[index]
end

local function Draw()
    if not layer then return end
    local used = 0
    local list = ns.ConversationTexts()
    local start, stop, first, last = Ends(list)
    if start then
        for index = first, last do
            local low, high = Span(list, index, start, stop, first, last)
            local text = list[index].text
            if high > low then
                local ok, areas = pcall(text.CalculateScreenAreaFromCharacterSpan, text, low, high)
                for _, area in ipairs(ok and areas or {}) do
                    used = used + 1
                    local texture = Highlight(used)
                    texture:ClearAllPoints()
                    texture:SetPoint("BOTTOMLEFT", text, "BOTTOMLEFT", area.left, area.bottom)
                    texture:SetPoint("TOPRIGHT", text, "BOTTOMLEFT", area.left + area.width, area.bottom + area.height)
                    texture:Show()
                end
            end
        end
    end
    for index = used + 1, #highlights do highlights[index]:Hide() end
end

local function Drop()
    if box and box:HasFocus() then box:ClearFocus() end
    if returnTo then
        local input = returnTo
        returnTo = nil
        if input:IsVisible() then input:SetFocus() end
    end
end

function ns.ClearSelection()
    from, to, dragging = nil, nil, nil
    if layer then layer:SetScript("OnUpdate", nil) end
    Drop()
    Draw()
end

-- The conversation laid out again: the selection stays while its texts are the same.
function ns.SelectionLaidOut()
    if not from then return end
    if not Ends(ns.ConversationTexts()) then return ns.ClearSelection() end
    Draw()
end

----------------------------------------------------------------------
-- The mouse
----------------------------------------------------------------------

local function Follow()
    if not dragging then return end
    local scroll = ns.ConversationScroll()
    local x, y = Cursor(layer)
    local top, bottom = scroll:GetTop(), scroll:GetBottom()
    if top and y > top then
        scroll:To((scroll:GetVerticalScroll() or 0) - SCROLL)
    elseif bottom and y < bottom then
        scroll:To((scroll:GetVerticalScroll() or 0) + SCROLL)
    end
    local point = At(ns.ConversationTexts(), x, y)
    if point and (point.text ~= to.text or point.index ~= to.index) then
        to = point
        Draw()
    end
end

local function Press(_, button)
    if button ~= "LeftButton" or not ns.On("select") then return end
    ns.ClearSelection()
    local x, y = Cursor(layer)
    local point = At(ns.ConversationTexts(), x, y)
    if not point then return end
    local now = GetTime()
    if lastPress and lastPress.text == point.text and now - lastPress.at < DOUBLE then -- the paragraph
        from = { text = point.text, raw = point.raw, index = 1 }
        to = { text = point.text, raw = point.raw, index = #point.raw + 1 }
        lastPress = nil
        return Draw()
    end
    lastPress = { text = point.text, at = now }
    from, to, dragging, pressX, pressY = point, point, true, x, y
    layer:SetScript("OnUpdate", Follow)
end

local function Release(_, button)
    if button ~= "LeftButton" or not dragging then return end
    Follow()
    dragging = nil
    layer:SetScript("OnUpdate", nil)
    local x, y = Cursor(layer)
    local near = max(x, pressX) - min(x, pressX) < MOVED and max(y, pressY) - min(y, pressY) < MOVED
    if near or from.text == to.text and from.index == to.index then ns.ClearSelection() end
end

-- A part of the conversation where a selection may start.
function ns.Selectable(frame)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", Press)
    frame:SetScript("OnMouseUp", Release)
end

----------------------------------------------------------------------
-- The keyboard: while Ctrl is held
----------------------------------------------------------------------

local function Offer()
    local text = Selected()
    if not text then return end
    local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focus == box then return end
    if focus and focus ~= ns.ConversationInput() then return end -- another box's own Ctrl+C
    returnTo = focus
    box.copyText = text
    box:SetText(text)
    box:SetFocus()
    box:HighlightText()
end

-- Over the conversation (content: what scrolls), once the window is built.
function ns.BuildSelection(content)
    highlights = {}
    layer = CreateFrame("Frame", nil, content)
    layer:SetAllPoints()
    layer:SetFrameLevel(content:GetFrameLevel() + 30)
    layer:EnableMouse(false)

    box = CreateFrame("EditBox", nil, UIParent)
    box:SetSize(2, 2)
    box:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", -20, -20) -- out of sight
    box:SetAutoFocus(false)
    box:SetMultiLine(true)
    box:SetMaxLetters(0)
    T.SetFont(box, "sans", 10)
    box:SetAlpha(0)
    box:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(self.copyText or "")
            self:HighlightText()
        end
    end)
    box:SetScript("OnEscapePressed", ns.ClearSelection)
    box:SetScript("OnKeyDown", function(_, key)
        if key == "C" and (IsControlKeyDown() or IsMetaKeyDown and IsMetaKeyDown()) then
            C_Timer.After(0.1, function() -- once the game has copied it
                Drop()
                ns.Notice(L.SELECT_COPIED)
            end)
        end
    end)

    layer:RegisterEvent("MODIFIER_STATE_CHANGED")
    pcall(layer.RegisterEvent, layer, "GLOBAL_MOUSE_DOWN")
    layer:SetScript("OnEvent", function(_, event, key, down)
        if not from then return end
        if event == "GLOBAL_MOUSE_DOWN" then -- a click out of the conversation
            if not ns.ConversationScroll():IsMouseOver() then ns.ClearSelection() end
        elseif key == "LCTRL" or key == "RCTRL" or key == "LMETA" or key == "RMETA" then
            if down == 1 and not dragging and layer:IsVisible() then Offer() elseif down ~= 1 then Drop() end
        end
    end)
    layer:SetScript("OnHide", ns.ClearSelection)
    ns.Selectable(content)
end

-- A whole message's text, as it reads (the copy button under it).
function ns.PlainOf(entries)
    local parts = {}
    for index, entry in ipairs(entries) do
        if index > 1 then parts[#parts + 1] = entry.gap end
        parts[#parts + 1] = entry.before
        parts[#parts + 1] = Plain(entry.whole or entry.text:GetText() or "")
    end
    return concat(parts)
end
