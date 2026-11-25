-- claude-in-wow: the Claude window, in claude.ai's look (Theme.lua),
-- opened by the minimap button (MinimapButton.lua). An addon cannot reach
-- Claude, so the conversation goes this way:
--   Your question goes in a photo with the game state (Photo.lua): Claude,
--   listening in its app (the plugin's listen tool), reads it at once. When
--   no photo can be taken (in combat), or on a click on the question's note,
--   the window shows the question prepared with what Claude needs to know of
--   the game (Ask.lua), selected above the box you write in: Ctrl+C copies it
--   (the game keeps CopyToClipboard for itself), then you paste it in Claude.
--   Claude's answer comes by itself (Inbox.lua), or is pasted in the box
--   (Ctrl+V): much text arriving at once is a paste, taken as Claude's answer
--   and shown as Claude shows it (Markdown.lua). A marks block in it gets a button that
--   puts the marks on your bags (Marks.lua).
-- Several conversations, as tabs under the header, kept per character with
-- their last 40 messages. Whatever the tab, the silent mode answers in one
-- Claude session (silent.mjs in the plugin); the settings can start a new one.
-- Under each answer, the model that gave it, its effort and the tokens it
-- took; by the button that sends, the model and the effort to ask (one for all
-- the conversations, as their session is).
--   ns.char.chat = { tabs = { { messages = { { role = "you"|"claude", text, at, state, kind,
--     sentAt, received, lost, answered, applied, model, effort, tokens, cached, signal, slot, ready, done } }, unread } },
--     current = 1,
--     done = { question times } }: done, answered or closed, whatever became of their tab
--   ns.db.claudeStatus = { session, questions, seconds, tokens, model, at }: what the last answer said of the session
-- Its place and size: ns.db.claude = { left, top, width, height }.

local addonName, ns = ...

local ceil, date, floor, format, ipairs, max, min, next, pairs, pcall, select, time, tonumber =
    math.ceil, date, math.floor, string.format, ipairs, math.max, math.min, next, pairs, pcall, select, time, tonumber
local concat, gmatch, gsub, match, strtrim, tremove =
    table.concat, string.gmatch, string.gsub, string.match, strtrim, table.remove
local T, L = ns.Theme, ns.L

local WIDTH, HEIGHT = 460, 620
local PAD = 18            -- the window's margin
local HEADER = 48         -- the top bar, as the skin has it
local COMPOSER = 60         -- the box you write in, without its text
local LINE, MOST = 22, 120  -- its text: at least a line, at most this high
local BOTTOM = 8            -- under the bars at the bottom
local TABS = 36           -- the row of conversations under the header
local MAX_TABS = 8
local MAX_MESSAGES = 40
local PASTE_SIZE = 40     -- characters arriving at once: a paste
local UI_SIZE = 13
local FOLD_OVER, FOLD_TO = 5, 3 -- a code block longer than so many lines shows so few until it is clicked

local frame, title, scroll, content, empty, composer, input, placeholder, sendButton, plus, modelPicker, effortPicker, menu, strip, stripBox
local gear, settingsArea, settingsPage, nextButton, tabStrip, plusTab, thinking
local tabButtons = {}
local thinkTicker
local HideStrip, Notice -- below
local settingsShown = false
local widgets = {}
local prepared = setmetatable({}, { __mode = "k" }) -- message -> the text to copy, this session
local unfolded = setmetatable({}, { __mode = "k" }) -- message -> { [block] = true }, this session
local pasteMode = false
local notice, noticeToken = nil, 0   -- a paste refused: what to say
local refusedText                    -- the unmarked paste refused once

----------------------------------------------------------------------
-- The conversation
----------------------------------------------------------------------

-- The character's conversations.
local function Chat()
    if not ns.char then return nil end
    if type(ns.char.chat) ~= "table" then ns.char.chat = {} end
    local chat = ns.char.chat
    if not chat.tabs then
        chat.tabs = { { messages = {} } }
    end
    if not chat.current or not chat.tabs[chat.current] then chat.current = 1 end
    return chat
end

local function CurrentTab()
    local chat = Chat()
    return chat and chat.tabs[chat.current]
end

local function Messages()
    local tab = CurrentTab()
    return tab and tab.messages or {}
end

-- The question sent at a time, in any conversation: the message, its tab's number, its tab.
local function QuestionAt(at)
    local chat = Chat()
    for index, tab in ipairs(chat and chat.tabs or {}) do
        for _, message in ipairs(tab.messages) do
            if message.role == "you" and message.at == at then return message, index, tab end
        end
    end
end

-- A message added to a conversation (the current one by default). A question's
-- time names it to the plugin, so no two share one.
local function AddMessage(message, tab)
    tab = tab or CurrentTab()
    if not tab then return message end
    message.at = time()
    if message.role == "you" then
        while QuestionAt(message.at) do message.at = message.at + 1 end
    end
    local messages = tab.messages
    messages[#messages + 1] = message
    while #messages > MAX_MESSAGES do tremove(messages, 1) end
    return message
end

-- The question waiting for its answer in a conversation (the current one by
-- default), if its last one sent is.
local function Pending(tab)
    local messages = tab and tab.messages or Messages()
    for index = #messages, 1, -1 do
        local message = messages[index]
        if message.role == "you" then return message.state == "sent" and not message.answered and message or nil end
    end
end

-- The questions sent and not answered yet, in every conversation.
function ns.WaitingQuestions()
    local chat, waiting = Chat(), {}
    for _, tab in ipairs(chat and chat.tabs or {}) do
        for _, message in ipairs(tab.messages) do
            if message.role == "you" and not message.answered and (message.state == "sent" or message.state == "sending") then
                waiting[#waiting + 1] = message
            end
        end
    end
    return waiting
end

local function AlreadyShown(text)
    local chat = Chat()
    for _, tab in ipairs(chat and chat.tabs or {}) do
        for _, message in ipairs(tab.messages) do
            if message.role == "claude" and message.text == text then return true end
        end
    end
    return false
end

-- A question whose answer is no longer wanted: answered, or its conversation
-- closed. Kept for as long as the plugin keeps an answer (2 hours).
local function NoteDone(question)
    local chat = Chat()
    chat.done = chat.done or {}
    chat.done[#chat.done + 1] = question.at
    while #chat.done > 30 or chat.done[1] and time() - chat.done[1] > 2 * 3600 do tremove(chat.done, 1) end
end

-- Those questions, for the plugin to forget their answers.
local function Answered()
    local chat, ids, seen = Chat(), {}, {}
    local function Add(at)
        if seen[at] or time() - at > 2 * 3600 then return end
        seen[at] = true
        ids[#ids + 1] = at
    end
    for _, at in ipairs(chat and chat.done or {}) do Add(at) end
    for _, tab in ipairs(chat and chat.tabs or {}) do
        for _, message in ipairs(tab.messages) do
            if message.role == "you" and message.answered then Add(message.at) end
        end
    end
    return ids
end

-- A conversation's name: its first question.
local function TabTitle(tab)
    for _, message in ipairs(tab.messages) do
        if message.role == "you" then return message.text end
    end
    return L.NEW_CHAT
end

-- How long Claude usually takes for a kind of question, in seconds: the mean
-- of the last five times, as the silent mode says or from a question sent to
-- its answer pasted
-- (ns.db.answerTimes = { free = { ... }, bags = { ... } }).
local DEFAULT_TIME = { free = 20, bags = 40 }

local function AnswerTime(kind)
    kind = kind or "free"
    local times = ns.db.answerTimes and ns.db.answerTimes[kind] or {}
    if #times == 0 then return DEFAULT_TIME[kind] or 20 end
    local total = 0
    for _, seconds in ipairs(times) do total = total + seconds end
    return floor(total / #times + 0.5)
end

local function NoteAnswerTime(kind, seconds)
    ns.db.answerTimes = ns.db.answerTimes or {}
    local times = ns.db.answerTimes[kind] or {}
    ns.db.answerTimes[kind] = times
    table.insert(times, 1, max(5, min(seconds, 120)))
    while #times > 5 do tremove(times) end
end

----------------------------------------------------------------------
-- Messages on screen
----------------------------------------------------------------------

-- The next free element of a widget's pool, made when missing.
local function Acquire(widget, pool, make)
    widget.used[pool] = (widget.used[pool] or 0) + 1
    local list = widget.pools[pool]
    local item = list[widget.used[pool]]
    if not item then
        item = make(widget)
        list[#list + 1] = item
    end
    item:ClearAllPoints()
    item:Show()
    return item
end

local function ReleaseAll(widget)
    for pool, list in pairs(widget.pools) do
        for _, item in ipairs(list) do item:Hide() end
        widget.used[pool] = 0
    end
end

local MAKE = {
    text = function(widget) return T.Text(widget, "sans", UI_SIZE, "text") end,
    -- an action Claude proposes (Buttons.lua): its tooltip shows all it does
    button = function(widget)
        local chip = T.Chip(widget, "Check", "", function(self) ns.ClickButton(self.message, self.index, self.button) end)
        chip:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            ns.ButtonTip(self.button)
            GameTooltip:Show()
        end)
        chip:HookScript("OnLeave", GameTooltip_Hide)
        return chip
    end,
    marker = function(widget) return T.Text(widget, "sans", UI_SIZE, "secondary") end,
    code = function(widget)
        local box = CreateFrame("Frame", nil, widget)
        T.Box(box, 8, "chrome", "border")
        box.text = T.Text(box, "mono", 12, "secondary")
        box.text:SetPoint("TOPLEFT", 12, -10)
        box.copy = T.IconButton(box, "Copy", 12, L.CODE_COPY, function(self) ns.CopyText(self:GetParent().raw, L.COPY_TEXT) end)
        box.copy:SetPoint("TOPRIGHT", -2, -2)
        -- a long one: the bar under it unfolds it, and folds it again
        box.more = CreateFrame("Button", nil, box)
        box.more:SetPoint("BOTTOMLEFT", 1, 1)
        box.more:SetPoint("BOTTOMRIGHT", -1, 1)
        box.more:SetHeight(24)
        T.Box(box.more, 6, "none")
        box.more.icon = T.Icon(box.more, "Chevron", 10, "muted")
        box.more.icon:SetPoint("LEFT", 12, 0)
        box.more.label = T.Text(box.more, "sans", 12, "muted")
        box.more.label:SetPoint("LEFT", box.more.icon, "RIGHT", 6, 0)
        box.more:SetScript("OnEnter", function(self) T.PaintBox(self, "hover") end)
        box.more:SetScript("OnLeave", function(self) T.PaintBox(self, "none") end)
        box.more:SetScript("OnClick", function(self)
            local open = unfolded[self.message] or {}
            open[self.index] = not open[self.index] or nil
            unfolded[self.message] = open
            ns.RenderClaude()
        end)
        return box
    end,
    rule = function(widget) return T.Line(widget) end,
    bar = function(widget) return T.Line(widget, "borderStrong") end,
}

-- A block's look: points over the answers' size (Look.lua), colour, space above it.
local STYLE = {
    para = { 0, "body", 10 },
    row = { -1, "secondary", 4 },
    quote = { 0, "secondary", 10 },
    bullet = { 0, "body", 6 },
    number = { 0, "body", 6 },
    heading = { 2, "title", 18 },
}
local HEADING_GROWTH = { 5, 3, 1 } -- "#", "##", "###" and deeper: points over the body's size

----------------------------------------------------------------------
-- Links to the game (Markdown.lua): tooltips and clicks
----------------------------------------------------------------------

local function Say(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ec9b0claude-in-wow|r " .. text)
end

function ns.MapName(map)
    local info = map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    return info and info.name
end

local function InsertInChat(link)
    local insert = ChatEdit_InsertLink or (ChatFrameUtil and ChatFrameUtil.InsertLink)
    if link and insert then insert(link) end
end

-- A pin there, followed on screen, and the map open on it; not the map in
-- combat (the game keeps it for itself then). True when the pin is set.
function ns.ShowOnMap(map, x, y)
    local pinned = x and y and ns.Game.Pin(map, x, y) or false
    if InCombatLockdown() then
        Say(L.MAP_COMBAT)
    else
        ns.Game.OpenMap(map)
    end
    return pinned
end

-- The quest log open on a quest of it: true once done.
function ns.ShowQuest(questID)
    if InCombatLockdown() then return Say(L.QUEST_COMBAT) end
    if not ns.Game.OpenQuest(questID) then return Say(L.QUEST_NOT_YOURS) end
    return true
end

local function LinkParts(link)
    return match(link or "", "^ciw(%a+):(.*)$")
end

local function LinkEnter(self, link, text)
    local kind, rest = LinkParts(link)
    if not kind then return end
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR_RIGHT", 16, 0)
    if kind == "item" then
        GameTooltip:SetHyperlink("item:" .. rest)
    elseif kind == "quest" then
        local shown = pcall(GameTooltip.SetHyperlink, GameTooltip, "quest:" .. rest)
        if not shown or (GameTooltip:NumLines() or 0) == 0 then GameTooltip:SetText(ns.StripCodes(text), 1, 0.82, 0) end
        GameTooltip:AddLine(L.LINK_QUEST_TIP, 0.6, 0.6, 0.6, true)
    elseif kind == "map" then
        local map, x, y = match(rest, "^(%d+):([%d%.]+):([%d%.]+)$")
        GameTooltip:SetText(format("%s  %s, %s", ns.MapName(tonumber(map)) or "", x or "", y or ""), 1, 0.82, 0)
        GameTooltip:AddLine(L.LINK_MAP_TIP, 1, 1, 1, true)
    elseif kind == "zone" then
        GameTooltip:SetText(ns.MapName(tonumber(rest)) or ns.StripCodes(text), 1, 0.82, 0)
        GameTooltip:AddLine(L.LINK_ZONE_TIP, 1, 1, 1, true)
    elseif kind == "npc" then -- what the game tells of a creature, when it knows it
        pcall(GameTooltip.SetHyperlink, GameTooltip, ("unit:Creature-0-0-0-0-%s-0000000000"):format(rest))
        if (GameTooltip:NumLines() or 0) == 0 then GameTooltip:SetText(ns.StripCodes(text), 1, 1, 1) end
    elseif ns.linkKinds[kind] then
        ns.linkKinds[kind].enter(GameTooltip, rest)
    end
    GameTooltip:Show()
end

local function LinkClick(_, link)
    local kind, rest = LinkParts(link)
    if kind == "item" then
        local _, itemLink = C_Item.GetItemInfo(tonumber(rest))
        if IsModifiedClick("CHATLINK") then
            InsertInChat(itemLink)
        elseif IsModifiedClick("DRESSUP") and itemLink and DressUpItemLink then
            DressUpItemLink(itemLink)
        end
    elseif kind == "quest" then
        if IsModifiedClick("CHATLINK") and GetQuestLink then InsertInChat(GetQuestLink(tonumber(rest))) else ns.ShowQuest(tonumber(rest)) end
    elseif kind == "map" then
        local map, x, y = match(rest, "^(%d+):([%d%.]+):([%d%.]+)$")
        if ns.ShowOnMap(tonumber(map), tonumber(x), tonumber(y)) and IsModifiedClick("CHATLINK") then
            InsertInChat(ns.Game.PinLink())
        end
    elseif kind == "zone" then
        ns.ShowOnMap(tonumber(rest))
    elseif ns.linkKinds[kind] then
        ns.linkKinds[kind].click(rest)
    end
end

-- Items and quests asked for by links: the window is drawn again once the game has them.
local itemsDue, questsDue = {}, {}
ns.claudeItemsDue, ns.claudeQuestsDue = itemsDue, questsDue

local Fill = ns.FillText

-- A text's first lines, cut where a line holds so many letters; and how many lines it
-- has in all. (The game does not fold a text it has already drawn.)
function ns.FoldText(text, fits, keep)
    local kept, lines = {}, 0
    for line in gmatch(text .. "\n", "([^\n]*)\n") do
        local letters = 0
        for _ in gmatch(line, "[^\128-\191]") do letters = letters + 1 end
        local taken = max(1, ceil(letters / fits))
        if lines + taken <= keep then
            kept[#kept + 1] = line
        elseif lines < keep then
            local room, count, cut = (keep - lines) * fits - 1, 0, #line
            for at in gmatch(line, "()[^\128-\191]") do
                count = count + 1
                if count > room then
                    cut = at - 1
                    break
                end
            end
            kept[#kept + 1] = line:sub(1, cut) .. "\226\128\166"
        end
        lines = lines + taken
    end
    return concat(kept, "\n"), lines
end

local Show -- below

-- Claude's answer: its blocks, the marks button, what it took (the model, the
-- tokens), the spark under the last one.
local function LayoutClaude(widget, message, width, isLast)
    local margin = ns.ConversationMargins()
    local left = margin + 4
    local right = max(width - margin - 4, left + 60)
    local face, titles, base = ns.AnswerLook()
    local dot, digits = floor(base * 16 / 14 + 0.5), floor(base * 22 / 14 + 0.5) -- a list's marks
    local y = 0
    local buttons, shown, why = ns.ButtonsBlock(message.text)
    local last -- the block before
    for index, block in ipairs(ns.Markdown(shown)) do
        local style = STYLE[block.kind]
        -- copied, the lines of a list follow each other, paragraphs are apart
        local gap = last == block.kind and (last == "bullet" or last == "number" or last == "row") and "\n" or "\n\n"
        last = block.kind
        if index > 1 then y = y + (style and style[3] or 10) end
        if block.kind == "code" then
            local box = Acquire(widget, "code", MAKE.code)
            local size, raw = max(base - 2, 8), ns.PlainText(block.text)
            local room = right - left - 24 - 22
            Fill(box.text, "mono", size, "secondary", room, "0000000000")
            local fits = max(10, floor(room / max(T.TextWidth(box.text) / 10, 1))) -- letters a line: all as wide
            local folded, lines = ns.FoldText(block.text, fits, FOLD_TO)
            local long, open = lines > FOLD_OVER, unfolded[message] and unfolded[message][index]
            local height = Fill(box.text, "mono", size, "secondary", room, long and not open and ns.PlainText(folded) or raw)
            box.raw = block.text
            box.more:SetShown(long)
            box.more.message, box.more.index = message, index
            box.more.icon:SetTexCoord(0, 1, open and 1 or 0, open and 0 or 1)
            box.more.label:SetText(open and L.CODE_FOLD or format(L.CODE_UNFOLD, lines))
            height = height + (long and 22 or 0)
            box:SetPoint("TOPLEFT", left, -y)
            box:SetSize(right - left, height + 20)
            widget.texts[#widget.texts + 1] = { text = box.text, before = "", gap = gap, whole = raw }
            y = y + height + 20
        elseif block.kind == "rule" then
            local line = Acquire(widget, "rule", MAKE.rule)
            line:SetPoint("TOPLEFT", left, -y - 6)
            line:SetSize(right - left, 1)
            y = y + 13
        else
            local x, bar, before = left, nil, ""
            if block.kind == "bullet" or block.kind == "number" then
                x = left + (block.depth or 0) * 18
                local marker = Acquire(widget, "marker", MAKE.marker)
                Fill(marker, face, base, "secondary", digits, block.kind == "bullet" and "\226\128\162" or (block.number .. "."))
                marker:SetPoint("TOPLEFT", x, -y)
                x = x + (block.kind == "bullet" and dot or digits)
                before = ("  "):rep(block.depth or 0) .. (block.kind == "bullet" and "- " or block.number .. ". ")
            elseif block.kind == "quote" then
                bar = Acquire(widget, "bar", MAKE.bar)
                x = left + 14
            end
            local text = Acquire(widget, "text", MAKE.text)
            local heading = block.kind == "heading"
            local size = base + (heading and (HEADING_GROWTH[block.level] or 1) or style[1])
            local height = Fill(text, heading and titles or face, size, style[2], right - x, ns.MarkdownInline(block.text, shown))
            text:SetPoint("TOPLEFT", x, -y)
            widget.texts[#widget.texts + 1] = { text = text, before = before, gap = gap }
            if bar then
                bar:SetPoint("TOPLEFT", left, -y)
                bar:SetSize(2, height)
            end
            y = y + height
        end
    end

    -- how Claude came to it, folded
    widget.why:SetShown(why ~= nil)
    widget.whyText:SetShown(false)
    if why then
        local open = unfolded[message] and unfolded[message].why
        widget.why.message = message
        widget.why.icon:SetTexCoord(0, 1, open and 1 or 0, open and 0 or 1)
        widget.why:SetPoint("TOPLEFT", left - 4, -y - 8)
        y = y + 8 + 22
        if open then
            widget.whyText:SetShown(true)
            widget.whyText:SetPoint("TOPLEFT", left + 12, -y - 2)
            y = y + 2 + Fill(widget.whyText, face, max(base - 2, 9), "muted", right - left - 12, ns.PlainText(why))
        end
    end

    local block, count = ns.MarksBlock(shown)
    widget.marksChip:SetShown(block ~= nil)
    if block then
        local on = ns.MarksShown(message)
        widget.marksChip:SetIcon(on and "Trash" or "Check")
        widget.marksChip:SetBadge(ns.ButtonBadge({ effect = "show" }))
        widget.marksChip:SetLabel(on and L.MARKS_REMOVE or format(L.APPLY_MARKS, count))
        widget.marksChip:SetPoint("TOPLEFT", left, -y - 12)
        widget.marksChip.block = block
        widget.marksChip.message = message
        y = y + 12 + 28
    end

    -- the actions it proposes: the player's clicks
    local x, row = left, 0
    for index, button in ipairs(buttons or {}) do
        local chip = Acquire(widget, "button", MAKE.button)
        local done = message.done and message.done[index]
        local undoes = ns.ButtonUndoes(button, done)
        chip:SetIcon(undoes and "Trash" or done and not button.undo and "Check" or button.icon)
        chip:SetBadge(ns.ButtonBadge(button))
        chip:SetLabel(undoes and (button.undoLabel or format(L.BUTTON_UNDO, button.label)) or button.label)
        chip:SetAlpha(done and not undoes and not button.undo and 0.6 or 1)
        chip.button, chip.message, chip.index = button, message, index
        if x > left and x + chip:GetWidth() > right then x, row = left, row + 1 end
        chip:SetPoint("TOPLEFT", x, -y - 12 - row * 34)
        x = x + chip:GetWidth() + 8
    end
    if buttons then y = y + 12 + (row + 1) * 34 - 6 end

    widget.spark:SetShown(isLast)
    if isLast then widget.spark:SetPoint("TOPLEFT", left, -y - 14) end
    widget.copy:ClearAllPoints()
    widget.copy:SetPoint("TOPRIGHT", widget, "TOPLEFT", right + 6, -y - (isLast and 11 or 5))
    widget.copy:Show()
    local took = ns.AnswerNote(message)
    widget.took:SetShown(took ~= nil)
    widget.tookOver:SetShown(took ~= nil and message.detail ~= nil)
    widget.tookOver.answer = message
    if took then
        local x = isLast and left + 18 + 8 or left
        widget.took:SetWidth(right - x - 30)
        widget.took:SetText(took)
        widget.took:ClearAllPoints()
        widget.took:SetPoint("TOPLEFT", x, -y - (isLast and 17 or 10))
        local height = widget.took:GetStringHeight() or 13
        return y + (isLast and max(14 + 20, 17 + height) or 10 + height)
    end
    return y + (isLast and 14 + 20 or 24)
end

-- What happened to a question you sent, under its bubble.
local function NoteOf(message)
    if message.state == "said" then return "Check", L.STATE_SAID, "muted" end
    if message.state == "sending" then return "Camera", L.STATE_SENDING, "muted" end
    if message.state == "sent" then return "Check", prepared[message] and L.STATE_SENT_COPY or L.STATE_SENT, "muted" end
    if message.state == "copy" and prepared[message] then return "Copy", L.STATE_COPY, "clay" end
    if message.state == "copied" then
        return "Check", prepared[message] and L.STATE_COPIED_AGAIN or L.STATE_COPIED, "muted"
    end
    if prepared[message] then return "Copy", L.COPY_AGAIN, "muted" end
end

-- Your message: its bubble on the right, the note under it.
local function LayoutYou(widget, message, width)
    local height = widget.bubble:Fill(ns.PlainText(message.text), width)
    widget.texts[1] = { text = widget.bubble.text, before = "", gap = "\n\n" }
    widget.bubble:Show()

    local icon, note, color = NoteOf(message)
    widget.note:SetShown(icon ~= nil)
    if icon then
        widget.noteIcon:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Claude\\" .. icon)
        widget.noteIcon:SetVertexColor(T.Color(color))
        widget.noteText:SetText(note)
        widget.noteText:SetTextColor(T.Color(color))
        widget.note:SetSize(T.TextWidth(widget.noteText) + 20, 18)
        widget.note:ClearAllPoints()
        widget.note:SetPoint("TOPRIGHT", widget.bubble, "BOTTOMRIGHT", -4, -6)
        widget.note.message = message
        height = height + 24
    end
    return height
end

local function NewWidget(index)
    local widget = CreateFrame("Frame", nil, content)
    widget.pools, widget.used = { text = {}, marker = {}, code = {}, rule = {}, bar = {}, button = {} }, {}
    -- the links in its texts
    widget:SetHyperlinksEnabled(true)
    widget:SetScript("OnHyperlinkEnter", LinkEnter)
    widget:SetScript("OnHyperlinkLeave", GameTooltip_Hide)
    widget:SetScript("OnHyperlinkClick", LinkClick)
    ns.Selectable(widget)
    widget.texts = {} -- in order: { text, before (a list's mark), gap (what parts it from the one before) }

    widget.bubble = ns.NewBubble(widget)

    widget.note = CreateFrame("Button", nil, widget)
    widget.noteIcon = T.Icon(widget.note, "Copy", 12, "muted")
    widget.noteIcon:SetPoint("LEFT")
    widget.noteText = T.Text(widget.note, "sans", 11, "muted")
    widget.noteText:SetWordWrap(false)
    widget.noteText:SetPoint("LEFT", widget.noteIcon, "RIGHT", 5, 0)
    widget.note:SetScript("OnClick", function(self)
        if self.message and prepared[self.message] then Show(self.message) end
    end)

    widget.why = CreateFrame("Button", nil, widget)
    widget.why:SetSize(10 + 6 + 200, 22)
    T.Box(widget.why, 6, "none")
    widget.why.icon = T.Icon(widget.why, "Chevron", 10, "muted")
    widget.why.icon:SetPoint("LEFT", 4, 0)
    widget.why.label = T.Text(widget.why, "sans", 12, "muted")
    widget.why.label:SetWordWrap(false)
    widget.why.label:SetPoint("LEFT", widget.why.icon, "RIGHT", 6, 0)
    widget.why.label:SetText(L.WHY)
    widget.why:SetWidth(10 + 4 + 6 + T.TextWidth(widget.why.label) + 8)
    widget.why:SetScript("OnEnter", function(self) T.PaintBox(self, "hover") end)
    widget.why:SetScript("OnLeave", function(self) T.PaintBox(self, "none") end)
    widget.why:SetScript("OnClick", function(self)
        local open = unfolded[self.message] or {}
        open.why = not open.why or nil
        unfolded[self.message] = open
        ns.RenderClaude()
    end)
    widget.whyText = T.Text(widget, "sans", 12, "muted")
    widget.marksChip = T.Chip(widget, "Check", "", function(self) ns.ToggleMarks(self.message, self.block) end)
    widget.marksChip:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        ns.ButtonTip({ label = self.label:GetText(), tip = L.APPLY_MARKS_TIP, effect = "show", back = "both" })
        GameTooltip:Show()
    end)
    widget.marksChip:HookScript("OnLeave", GameTooltip_Hide)
    widget.copy = T.IconButton(widget, "Copy", 12, L.COPY_ANSWER, function(self) ns.CopyText(ns.PlainOf(self:GetParent().texts), L.COPY_TEXT) end)
    widget.spark = T.Logo(widget, 18)
    widget.took = T.Text(widget, "sans", 11, "muted")
    widget.tookOver = CreateFrame("Frame", nil, widget)
    widget.tookOver:SetAllPoints(widget.took)
    widget.tookOver:EnableMouse(true)
    widget.tookOver:SetScript("OnEnter", function(self) ns.ShowAnswerDetail(self, self.answer) end)
    widget.tookOver:SetScript("OnLeave", GameTooltip_Hide)

    widgets[index] = widget
    return widget
end

local function Layout(widget, message, width, isLast)
    ReleaseAll(widget)
    widget.texts = {}
    widget.copy:Hide()
    widget.bubble:Hide()
    widget.note:Hide()
    widget.marksChip:Hide()
    widget.why:Hide()
    widget.whyText:Hide()
    widget.spark:Hide()
    widget.took:Hide()
    widget.tookOver:Hide()
    if message.role == "you" then return LayoutYou(widget, message, width) end
    return LayoutClaude(widget, message, width, isLast)
end

----------------------------------------------------------------------
-- Drawing it all
----------------------------------------------------------------------

local function Greeting()
    local hour = tonumber(date("%H")) or 12
    local text = (hour >= 5 and hour < 12) and L.GREETING_MORNING or (hour >= 12 and hour < 18) and L.GREETING_AFTERNOON
        or L.GREETING_EVENING
    return format(text, UnitName("player") or "")
end

-- A button of the empty conversation: its question is in its tooltip.
local function NewShortcut()
    local chip = T.Chip(empty, "ArrowUp", "", function(self) self.shortcut.run() end)
    chip:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns.PlainText(self.shortcut.tip), 0.76, 0.75, 0.71, 1, true)
        GameTooltip:Show()
    end)
    chip:HookScript("OnLeave", GameTooltip_Hide)
    return chip
end

local function LayoutEmpty(width, height)
    empty:SetSize(width, height)
    empty.greeting:SetText(Greeting())
    -- the chips in rows, centred
    local rows, row, rowWidth = {}, {}, 0
    local chips = {}
    for index, shortcut in ipairs(ns.Shortcuts()) do
        local chip = empty.chips[index] or NewShortcut()
        empty.chips[index] = chip
        chip.shortcut = shortcut
        chip:SetIcon(shortcut.icon)
        chip:SetLabel(ns.PlainText(shortcut.label))
        chip:Show()
        chips[index] = chip
    end
    for index = #chips + 1, #empty.chips do empty.chips[index]:Hide() end
    chips[#chips + 1] = empty.edit -- at the end, to change them
    for _, chip in ipairs(chips) do
        local chipWidth = chip:GetWidth() or 0
        if #row > 0 and rowWidth + 8 + chipWidth > width - 2 * PAD then
            rows[#rows + 1], row, rowWidth = row, {}, 0
        end
        rowWidth = rowWidth + (#row > 0 and 8 or 0) + chipWidth
        row[#row + 1] = chip
        row.width = rowWidth
    end
    rows[#rows + 1] = row
    local top = floor(height / 2) - 70
    empty.logo:SetPoint("TOP", empty, "TOP", 0, -max(12, top))
    for index, chips in ipairs(rows) do
        local x = -floor((chips.width or 0) / 2)
        for _, chip in ipairs(chips) do
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", empty, "TOP", x, -max(12, top) - 112 - (index - 1) * 36)
            x = x + chip:GetWidth() + 8
        end
    end
end

local function UpdatePlaceholder()
    local hasMessages = #Messages() > 0
    placeholder:SetText(pasteMode and L.PLACEHOLDER_PASTE or hasMessages and L.PLACEHOLDER_REPLY or L.PLACEHOLDER)
    placeholder:SetShown((input:GetText() or "") == "")
    local ready = strtrim(input:GetText() or "") ~= ""
    sendButton:SetAlpha(ready and 1 or 0.45)
end

local function UpdateContext()
    ns.UpdateBars(not settingsShown)
    modelPicker:SetLabel(ns.ChoiceLabel("model"))
    effortPicker:SetLabel(ns.db.options.effort == "default" and L.EFFORT or ns.ChoiceLabel("effort"))
end

-- The conversation's next step, for the button over the box you write in:
-- { icon, label, run } (no run: wait), or nil. Pasting is the player's own
-- Ctrl+V (addons cannot read the clipboard): the button only says so and
-- puts the cursor in the box.
local function NextStep()
    if notice then return { icon = "Close", label = notice } end -- a paste refused, a moment
    if strip and strip:IsShown() then return nil end
    local messages = Messages()
    local last = messages[#messages]
    if not last then return nil end
    if last.role == "you" then
        if last.state == "sending" then return { icon = "Camera", label = L.NEXT_SENDING } end
        if last.state == "copy" and prepared[last] then
            return { icon = "Copy", label = L.NEXT_COPY, run = function() Show(last) end }
        end
        -- sent: the answer comes by itself, or is to paste; a paste too early is
        -- refused (its mark)
        if ns.Unheard(last) then return { icon = "Gear", label = L.NEXT_HELP, run = ns.OpenHelp } end
        local label = L.NEXT_PASTE
        if last.state == "sent" and not last.answered then
            if last.ready then
                label = L.NEXT_READY
            elseif last.slot then
                label = L.NEXT_ARRIVES
            elseif ns.db.options.soundReady then
                label = L.NEXT_PASTE_SOUND
            end
        end
        return { icon = "Clipboard", label = label, run = function()
            pasteMode = true
            input:SetFocus()
            ns.RenderClaude()
        end }
    end
    local block, count = ns.MarksBlock(select(2, ns.ButtonsBlock(last.text)))
    if block and not last.applied then
        return { icon = "Check", label = format(L.APPLY_MARKS, count), run = function() ns.ToggleMarks(last, block) end }
    end
    local few = ns.SlotsWarning()
    if few then return { icon = "Check", label = few, run = ns.ReloadInterface } end
end

-- The button for it, centred over the box; how much room it takes.
local function UpdateNextStep()
    local step = not settingsShown and NextStep()
    nextButton:SetShown(step and true or false)
    if not step then return 0 end
    nextButton:SetIcon(step.icon)
    nextButton:SetLabel(step.label)
    nextButton.run = step.run
    nextButton:SetAlpha(step.run and 1 or 0.6)
    return 28 + 12
end

----------------------------------------------------------------------
-- The conversations, as tabs
----------------------------------------------------------------------

local function ShowTab(index)
    local chat = Chat()
    chat.current = index
    HideStrip()
    pasteMode = false
    ns.RenderClaude(true)
    input:SetFocus()
end

-- Closes a conversation; the last one closed leaves a fresh one. The Claude
-- session is not touched.
local function CloseTab(index)
    local chat = Chat()
    for _, message in ipairs(chat.tabs[index].messages) do
        if message.role == "you" then NoteDone(message) end
    end
    tremove(chat.tabs, index)
    if #chat.tabs == 0 then chat.tabs[1] = { messages = {} } end
    if chat.current > index then chat.current = chat.current - 1 end
    if chat.current > #chat.tabs then chat.current = #chat.tabs end
    HideStrip()
    pasteMode = false
    ns.RenderClaude(true)
end

-- A new conversation. Over MAX_TABS, the oldest one not waiting for an answer
-- goes (one waiting never does, however many there are).
local function NewTab()
    local chat = Chat()
    if #Messages() == 0 then return input:SetFocus() end -- already one to write in
    if #chat.tabs >= MAX_TABS then
        for index, tab in ipairs(chat.tabs) do
            if index ~= chat.current and not Pending(tab) then
                tremove(chat.tabs, index)
                break
            end
        end
    end
    chat.tabs[#chat.tabs + 1] = { messages = {} }
    chat.current = #chat.tabs
    HideStrip()
    pasteMode = false
    ns.RenderClaude(true)
    input:SetFocus()
end

local function NewTabButton(index)
    local button = CreateFrame("Button", nil, tabStrip)
    button:SetHeight(26)
    T.Box(button, 8, "none")
    button.label = T.Text(button, "sans", 12, "muted")
    button.label:SetWordWrap(false)
    button.label:SetPoint("LEFT", 10, 0)
    -- Claude at work on a question here, or its answer came and was not seen
    button.dot = button:CreateTexture(nil, "OVERLAY")
    button.dot:SetTexture("Interface\\AddOns\\" .. addonName .. "\\Media\\Claude\\Circle32")
    button.dot:SetVertexColor(T.Color("clay"))
    button.dot:SetSize(6, 6)
    button.dot:SetPoint("LEFT", 9, 0)
    button.close = T.IconButton(button, "Close", 10, L.CLOSE_TAB, function() CloseTab(button.index) end)
    button.close:SetSize(18, 18)
    button.close:SetPoint("RIGHT", -3, 0)
    button:SetScript("OnClick", function(self) ShowTab(self.index) end)
    button:SetScript("OnEnter", function(self) if not self.active then T.PaintBox(self, "hover") end end)
    button:SetScript("OnLeave", function(self) if not self.active then T.PaintBox(self, "none") end end)
    tabButtons[index] = button
    return button
end

local function RenderTabs()
    local chat = Chat()
    tabStrip:SetShown(chat ~= nil and not settingsShown)
    if not chat or settingsShown then return end
    local count = #chat.tabs
    local room = (tabStrip:GetWidth() or WIDTH) - 2 * 12 - 34 -- the button for one more
    local width = max(44, min(150, floor((room - (count - 1) * 4) / count)))
    for index, tab in ipairs(chat.tabs) do
        local button = tabButtons[index] or NewTabButton(index)
        button.index = index
        button.active = index == chat.current
        button:SetWidth(width)
        button:ClearAllPoints()
        button:SetPoint("LEFT", 12 + (index - 1) * (width + 4), 0)
        local dot = Pending(tab) and "clay" or tab.unread and "accent"
        button.dot:SetShown(dot and true or false)
        if dot then button.dot:SetVertexColor(T.Color(dot)) end
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", dot and 21 or 10, 0)
        button.label:SetWidth(width - (dot and 21 or 10) - 26)
        button.label:SetText(ns.PlainText(TabTitle(tab)))
        button.label:SetTextColor(T.Color(button.active and "text" or "muted"))
        T.PaintBox(button, button.active and "field" or "none")
        button.close:SetShown(button.active or count > 1)
        button:Show()
    end
    for index = count + 1, #tabButtons do tabButtons[index]:Hide() end
    plusTab:ClearAllPoints()
    plusTab:SetPoint("RIGHT", -10, 0)
end

-- Claude at work on the question, with how long it has been: a tick a
-- second while the window shows it.
local function StopThinking()
    if thinkTicker then thinkTicker:Cancel() end
    thinkTicker = nil
end

local function ThinkingText(message)
    if message.ready then return L.ANSWER_READY end
    if ns.Unheard(message) then return ns.BySession() and L.NOT_RECEIVED_SESSION or L.NOT_RECEIVED end
    local elapsed, usual = time() - (message.sentAt or time()), AnswerTime(message.kind)
    return format(elapsed <= 2 * usual and L.THINKING or L.THINKING_LONG, elapsed, usual)
end

local function UpdateThinking()
    local message = Pending()
    thinking.text:SetText(message and ThinkingText(message) or "")
end

local function StartThinking()
    if thinkTicker or not C_Timer.NewTicker then return end
    thinkTicker = C_Timer.NewTicker(1, function()
        if frame:IsShown() and thinking:IsShown() then
            UpdateThinking()
        else
            StopThinking()
        end
    end)
end

-- The bottom of the window, up: the bars (StatusBars.lua), the box you write in,
-- as high as its text (or as the question to copy), then the conversation. The
-- box's anchors are only moved when they change, and never taken off: without
-- them its text would have no width, and nothing could be typed.
local placed = {}
local function LayoutBottom()
    local bars = ns.LayoutBars(frame, PAD, BOTTOM, not settingsShown)
    local under = bars > 0 and BOTTOM + bars + 6 or PAD
    local height = COMPOSER + (strip and strip:IsShown() and 56 or min(max(input:GetHeight() or LINE, LINE), MOST))
    if placed.under ~= under then
        composer:SetPoint("BOTTOMLEFT", PAD, under)
        composer:SetPoint("BOTTOMRIGHT", -PAD, under)
    end
    if placed.height ~= height then composer:SetHeight(height) end
    if placed.under ~= under or placed.height ~= height then scroll:SetPoint("BOTTOMRIGHT", 0, under + height + 6) end
    placed.under, placed.height = under, height
end

-- As its text grows or shrinks: once the game is done laying it out.
local layoutDue = false
local function LayoutSoon()
    if layoutDue then return end
    layoutDue = true
    C_Timer.After(0, function()
        layoutDue = false
        LayoutBottom()
    end)
end

-- The settings page in place of the conversation, or back.
local function ShowSettings(on)
    settingsShown = on and true or false
    if settingsShown and not settingsPage then settingsPage = ns.BuildSettings(settingsArea) end
    settingsArea:SetShown(settingsShown)
    scroll:SetShown(not settingsShown)
    composer:SetShown(not settingsShown)
    gear.icon:SetVertexColor(T.Color(settingsShown and "text" or "muted"))
    if menu then menu:Hide() end
    if settingsShown then input:ClearFocus() end
end

-- Lays the conversation out again; to its end when asked.
function ns.RenderClaude(toEnd)
    if not frame or not frame:IsShown() then return end
    if not settingsShown and CurrentTab() then CurrentTab().unread = nil end
    RenderTabs()
    LayoutBottom()
    UpdateContext()
    if settingsShown then
        title:SetText(L.SETTINGS)
        nextButton:Hide()
        thinking:Hide()
        StopThinking()
        settingsPage:Refresh()
        return
    end
    local messages = Messages()
    local width, view = scroll:GetWidth() or WIDTH, scroll:GetHeight() or 0
    content:SetWidth(width)
    title:SetText("Claude")
    local nextRoom = UpdateNextStep()

    empty:SetShown(#messages == 0)
    if #messages == 0 then LayoutEmpty(width, view) end

    local sides, ends = ns.ConversationMargins()
    local y = ends
    for index, message in ipairs(messages) do
        local widget = widgets[index] or NewWidget(index)
        if index > 1 then y = y + 22 end
        local height = Layout(widget, message, width, index == #messages)
        widget:ClearAllPoints()
        widget:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        widget:SetSize(width, max(height, 1))
        widget:Show()
        y = y + height
    end
    for index = #messages + 1, #widgets do widgets[index]:Hide() end

    local waiting = Pending()
    thinking:SetShown(waiting ~= nil)
    if waiting then
        thinking:ClearAllPoints()
        thinking:SetPoint("TOPLEFT", content, "TOPLEFT", sides + 4, -y - 18)
        thinking:SetWidth(max(width - 2 * sides - 8, 60))
        UpdateThinking()
        StartThinking()
        y = y + 18 + 30
    else
        StopThinking()
    end
    content:SetHeight(max(y + ends + 4 + nextRoom, 1))
    UpdatePlaceholder()
    scroll:To(toEnd and scroll:Range() or scroll:GetVerticalScroll())
    ns.SelectionLaidOut()
end

----------------------------------------------------------------------
-- Copying a question
----------------------------------------------------------------------

local stripMessage

function HideStrip()
    if not strip or not strip:IsShown() then return end
    stripBox:ClearFocus()
    strip:Hide()
    stripMessage = nil
    ns.RenderClaude()
end

-- Copied: Claude's answer is next, the box waits for it.
local function Copied()
    if not strip:IsShown() then return end
    if not stripMessage then -- a string
        HideStrip()
        return Notice(strip.isText and L.SELECT_COPIED or L.COPIED_STRING)
    end
    stripMessage.state = "copied"
    HideStrip()
    pasteMode = true
    ns.RenderClaude(true)
    input:SetFocus()
end

-- The question selected over the box you write in, for Ctrl+C.
function Show(message, string, hint)
    stripMessage = message
    local text = string or prepared[message] or ""
    strip.hint:SetText(hint or string and L.COPY_STRING or L.COPY_STRIP)
    strip.isText = hint ~= nil
    stripBox.copyText = text
    stripBox:SetText(text)
    strip:Show()
    nextButton:Hide() -- the strip says what to do
    stripBox:SetFocus()
    stripBox:HighlightText()
    stripBox:SetCursorPosition(0)
    stripBox:HighlightText()
end

-- A text of an answer (an import string), shown selected the same way.
function ns.CopyText(text, hint)
    input:ClearFocus()
    Show(nil, text, hint)
end

-- For the selection (Select.lua): the conversation's texts on screen, in order,
-- what it scrolls in, and the box you write in.
function ns.ConversationTexts()
    local list = {}
    for _, widget in ipairs(widgets) do
        if widget:IsShown() then
            for _, entry in ipairs(widget.texts) do list[#list + 1] = entry end
        end
    end
    return list
end

function ns.ConversationScroll() return scroll end
function ns.ConversationInput() return input end

----------------------------------------------------------------------
-- What the box takes
----------------------------------------------------------------------

-- A word in the next step's place, for a moment (a paste refused: why).
function ns.Notice(text) return Notice(text) end

function Notice(text)
    notice = text
    noticeToken = noticeToken + 1
    local token = noticeToken
    C_Timer.After(8, function()
        if noticeToken == token then
            notice = nil
            ns.RenderClaude()
        end
    end)
    ns.RenderClaude(true)
end

-- What an answer's mark says of the silent mode's session, kept for the
-- settings and the line under the box; the answer's time in seconds, the model
-- that gave it, the tokens it took and, of them, those read again from the
-- cache, and where they went, if told. picked: the model asked, nil for the
-- default.
local function NoteStatus(extra, picked)
    local session = match(extra, "session=(%w+)")
    local seconds = tonumber(match(extra, " s=(%d+)"))
    local model = match(extra, " m=([%w%.%-]+)")
    if model then ns.NoteModel(model, picked) end
    ns.NotePlan(extra)
    ns.db.claudeLanguage = match(extra, " l=(%l%l)") or ns.db.claudeLanguage
    if session then
        ns.db.claudeStatus = {
            session = session, questions = tonumber(match(extra, " n=(%d+)")), seconds = seconds, at = time(),
            tokens = tonumber(match(extra, " c=(%d+)")), model = model,
        }
    end
    local detail
    for tokens in gmatch(match(extra, " d=([%d,]+)") or "", "%d+") do
        detail = detail or {}
        detail[#detail + 1] = tonumber(tokens)
    end
    return seconds, model, tonumber(match(extra, " t=(%d+)")), tonumber(match(extra, " r=(%d+)")), detail
end

-- A pasted text: Claude's answer. An answer copied by the silent mode or
-- answer_to_game carries the question it is for (its first line), and goes to
-- that question's conversation: one for another question, or already pasted,
-- is refused. Without a mark, while a question waits, it is refused once (it
-- may be an older answer still in the clipboard): pasted again, it is taken.
-- A marks block pasted alone shows as code.
local ANSWER_MARK = "^%[claude%-in%-wow réponse (%d+)([^%]]*)%]%s*$"

-- The marked answers of a paste, in order: { id, extra, text }; nil without a mark.
local function SplitAnswers(text)
    local parts, lines
    for line in gmatch(text .. "\n", "([^\n]*)\n") do
        line = gsub(line, "\r$", "")
        local id, extra = match(line, ANSWER_MARK)
        if id then
            parts = parts or {}
            lines = {}
            parts[#parts + 1] = { id = tonumber(id), extra = extra, lines = lines }
        elseif lines then
            lines[#lines + 1] = line
        end
    end
    for _, part in ipairs(parts or {}) do part.text = strtrim(concat(part.lines, "\n")) end
    return parts
end

-- The answers of a text that carry marks: each to its question's
-- conversation, the ones already taken or for no question here left out.
-- byItself: they came without a paste, so the conversation shown stays.
local function TakeMarked(parts, byItself)
    local chat = Chat()
    local seen = frame and frame:IsShown() and not settingsShown
    local taken, already, shownHere, lastTab = 0, 0, false, nil
    for _, part in ipairs(parts) do
        local question, tabIndex, tab = QuestionAt(part.id)
        if question and question.answered then
            already = already + 1
        elseif question and part.text ~= "" then
            question.answered = true
            local seconds, model, tokens, cached, detail = NoteStatus(part.extra, question.model)
            if seconds or question.sentAt then NoteAnswerTime(question.kind or "free", seconds or time() - question.sentAt) end
            local answer = AddMessage({
                role = "claude", text = part.text, model = model, effort = question.effort, tokens = tokens, cached = cached, detail = detail,
            }, tab)
            ns.NoteUsage(question.text, answer, seconds)
            taken, lastTab = taken + 1, tabIndex
            shownHere = shownHere or tabIndex == chat.current
            if byItself then tab.unread = not (seen and tabIndex == chat.current) or nil end
        end
    end
    if byItself then
        if taken > 0 and shownHere then pasteMode = false end
        if taken > 0 and not (frame and frame:IsShown()) then
            DEFAULT_CHAT_FRAME:AddMessage("|cff4ec9b0claude-in-wow|r " .. L.ANSWER_CAME)
        end
        return ns.RenderClaude(shownHere)
    end
    if taken == 0 then return Notice(already > 0 and L.ANSWER_ALREADY or L.ANSWER_OTHER) end
    if not shownHere then chat.current = lastTab end -- none for this conversation: to the last one
    refusedText, notice = nil, nil
    pasteMode = false
    ns.RenderClaude(true)
end

-- What the player said to Claude outside the game, and its answer: in the conversation
-- shown, or another when it waits for an answer. True for a text of that kind.
local function TakeSaid(text, byItself)
    local id, asked, answer = match(text, "^%s*%[claude%-in%-wow dit (%d+)%]%s*\n(.-)\n%[claude%-in%-wow réponse %d+[^%]]*%]%s*\n(.*)$")
    if not id then return false end
    id = tonumber(id)
    local chat = Chat()
    for _, tab in ipairs(chat.tabs) do
        for _, message in ipairs(tab.messages) do
            if message.said == id then
                if not byItself then Notice(L.ANSWER_ALREADY) end
                return true
            end
        end
    end
    local index = chat.current
    for other, tab in ipairs(Pending() and chat.tabs or {}) do
        if not Pending(tab) then index = other break end
    end
    local tab, shownHere = chat.tabs[index], index == chat.current
    AddMessage({ role = "you", text = strtrim(asked), state = "said", said = id, answered = true }, tab)
    AddMessage({ role = "claude", text = strtrim(answer) }, tab)
    local shown = frame and frame:IsShown()
    tab.unread = not (shown and not settingsShown and shownHere) or nil
    if byItself and not shown then DEFAULT_CHAT_FRAME:AddMessage("|cff4ec9b0claude-in-wow|r " .. L.ANSWER_CAME) end
    ns.RenderClaude(shownHere)
    return true
end

-- Answers that came by themselves (Inbox.lua).
function ns.TakeInbox(text)
    if TakeSaid(text, true) then return end
    local parts = SplitAnswers(text)
    if parts then TakeMarked(parts, true) end
end

-- Whether a pasted text is an answer: it says so (its mark, a block of marks), or
-- the window waits for one to paste. Anything else is yours, to go on writing.
local function IsAnswer(text)
    return pasteMode or SplitAnswers(text) ~= nil or match(text, "^%s*%[claude%-in%-wow dit %d+%]") ~= nil or match(text, "%[claude%-in%-wow%] *[mM]ar[kq]") ~= nil
end

local function TakeAnswer(text)
    input:SetText("")
    text = strtrim(gsub(text or "", "||", "|")) -- an edit box doubles the "|" it is given
    if text == "" then return end

    if TakeSaid(text) then return end
    local marked = SplitAnswers(text)
    if marked then return TakeMarked(marked) end
    local question, tab = Pending(), nil
    if question then
        if AlreadyShown(text) then return Notice(L.ANSWER_OLD) end
        if refusedText ~= text then
            refusedText = text
            return Notice(L.ANSWER_AGAIN)
        end
        question.answered = true
    end

    refusedText, notice = nil, nil
    if match(text, "^%[claude%-in%-wow%]") and not match(text, "```") then text = "```\n" .. text .. "\n```" end
    AddMessage({ role = "claude", text = text }, tab)
    pasteMode = false
    ns.RenderClaude(true)
end

local function Send()
    local text = strtrim(gsub(input:GetText() or "", "||", "|")) -- an edit box doubles the "|" it is given
    if text == "" then
        input:SetFocus()
        return
    end
    input:SetText("")
    ns.Ask("free", text)
end

----------------------------------------------------------------------
-- The "+" menu: the player's questions (Shortcuts.lua), then what is here; the model's menu
----------------------------------------------------------------------

local ACTIONS = {
    { icon = "Trash", label = "CLEAR_MARKS", run = function() ns.ClearMarks() end,
      shown = function() return ns.char and ns.char.marks and next(ns.char.marks) ~= nil end },
}

-- The window's menu, under a button of it, or over it when above (T.Menu).
function ns.ToggleMenu(anchor, entries, above)
    if not menu then menu = T.Menu(frame) end
    menu:Toggle(anchor, entries, above)
end

-- A menu where the mouse is (the links of an answer).
local cursor
function ns.MenuAtCursor(entries)
    if not frame then return end
    cursor = cursor or CreateFrame("Frame", nil, frame)
    cursor:SetSize(1, 1)
    local x, y = GetCursorPosition()
    local scale = frame:GetEffectiveScale() or 1
    cursor:ClearAllPoints()
    cursor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    if menu then menu:Hide() end
    ns.ToggleMenu(cursor, entries)
end

local function ToggleActions()
    local entries = {}
    for index, shortcut in ipairs(ns.Shortcuts(true)) do
        entries[index] = { icon = shortcut.icon, label = ns.PlainText(shortcut.label), run = shortcut.run }
    end
    if ns.On("shortcutsEdit") then entries[#entries + 1] = { icon = "Gear", label = L.SHORTCUTS_EDIT, run = function() ns.EditShortcuts() end } end
    for _, action in ipairs(ACTIONS) do
        if not action.shown or action.shown() then
            entries[#entries + 1] = { icon = action.icon, label = L[action.label], run = action.run }
        end
    end
    ns.ToggleMenu(plus, entries, true)
end

-- A picker over the box you write in: "model" or "effort".
local function NewPicker(key, tooltip)
    local picker = T.Picker(composer, function(self) ns.ToggleMenu(self, ns.ChoiceEntries(key), true) end, false, tooltip)
    picker.menuRight = true
    return picker
end

----------------------------------------------------------------------
-- Building the window
----------------------------------------------------------------------

local function SavePlace()
    ns.db.claude = {
        left = floor(frame:GetLeft() + 0.5), top = floor(frame:GetTop() + 0.5),
        width = floor(frame:GetWidth() + 0.5), height = floor(frame:GetHeight() + 0.5),
    }
end

local function BuildHeader()
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER)
    header:SetFrameLevel(frame:GetFrameLevel() + 10) -- over the skin's borders
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePlace()
    end)

    local logo = T.Logo(header, 18)
    logo:SetPoint("LEFT", PAD, 0)
    local close = T.IconButton(header, "Close", 16, L.CLOSE, function() frame:Hide() end)
    close:SetPoint("RIGHT", T.Skin().closeX or -10, 0)
    gear = T.IconButton(header, "Gear", 16, L.SETTINGS, function()
        ShowSettings(not settingsShown)
        ns.RenderClaude(true)
    end)
    gear:SetPoint("RIGHT", close, "LEFT", -2, 0)
    -- the gear stays lit while its page shows
    gear:HookScript("OnLeave", function(self) if settingsShown then self.icon:SetVertexColor(T.Color("text")) end end)

    title = T.Text(header, "sansMedium", 14, "text")
    title:SetWordWrap(false)
    title:SetJustifyV("MIDDLE")
    title:SetPoint("LEFT", logo, "RIGHT", 9, 0)
    title:SetPoint("RIGHT", gear, "LEFT", -8, 0)

    local divider = T.Line(header)
    divider:SetShown(not T.Skin().noDivider)
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", 1, 0)
    divider:SetPoint("BOTTOMRIGHT", -1, 0)
end

local function BuildTabs()
    tabStrip = CreateFrame("Frame", nil, frame)
    tabStrip:SetPoint("TOPLEFT", 0, -HEADER - 1)
    tabStrip:SetPoint("TOPRIGHT", 0, -HEADER - 1)
    tabStrip:SetHeight(TABS)
    tabStrip:SetClipsChildren(true)
    plusTab = T.IconButton(tabStrip, "Plus", 14, L.NEW_CHAT, NewTab)
    local line = T.Line(tabStrip)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 1, 0)
    line:SetPoint("BOTTOMRIGHT", -1, 0)
end

local function BuildThinking()
    thinking = CreateFrame("Frame", nil, content)
    thinking:SetHeight(24)
    local spark = CreateFrame("Frame", nil, thinking)
    spark:SetSize(18, 18)
    spark:SetPoint("LEFT", 0, 0)
    T.Logo(spark, 18):SetPoint("CENTER")
    thinking.text = T.Text(thinking, "sans", 13, "muted")
    thinking.text:SetWordWrap(false)
    thinking.text:SetPoint("LEFT", spark, "RIGHT", 8, 0)
    -- the spark breathes while Claude works
    local pulse = spark:CreateAnimationGroup()
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.3)
    fade:SetDuration(0.8)
    fade:SetSmoothing("IN_OUT")
    pulse:SetLooping("BOUNCE")
    thinking:SetScript("OnShow", function() pulse:Play() end)
    thinking:SetScript("OnHide", function() pulse:Stop() end)
    thinking:Hide()
end

local function BuildBody()
    scroll = T.Scroll(frame)
    scroll:SetPoint("TOPLEFT", 0, -HEADER - 1 - TABS)
    scroll:SetPoint("BOTTOMRIGHT", 0, PAD + COMPOSER + LINE + 6) -- then LayoutBottom
    content = scroll.content
    content:SetSize(WIDTH, 1)

    empty = CreateFrame("Frame", nil, scroll)
    empty:SetPoint("TOPLEFT")
    empty.logo = T.Logo(empty, 40)
    empty.greeting = T.Text(empty, "sansMedium", 23, "text")
    empty.greeting:SetWordWrap(false)
    empty.greeting:SetJustifyH("CENTER")
    empty.greeting:SetPoint("TOP", empty.logo, "BOTTOM", 0, -18)
    empty.chips = {}
    empty.edit = T.IconButton(empty, "Gear", 14, L.SHORTCUTS_EDIT, function() ns.EditShortcuts() end)
    BuildThinking()
end

local function BuildComposer()
    composer = CreateFrame("Frame", nil, frame)
    composer:SetPoint("BOTTOMLEFT", PAD, PAD)
    composer:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    composer:SetHeight(COMPOSER + LINE)
    T.Box(composer, 16, "field", "border")
    composer:EnableMouse(true)
    composer:SetScript("OnMouseDown", function() input:SetFocus() end)

    local area = CreateFrame("ScrollFrame", nil, composer)
    area:SetPoint("TOPLEFT", 16, -13)
    area:SetPoint("BOTTOMRIGHT", -16, 47)
    input = CreateFrame("EditBox", nil, area)
    input:SetMultiLine(true)
    input:SetAutoFocus(false)
    input:SetMaxLetters(0)
    T.SetFont(input, "sans", UI_SIZE + 1)
    input:SetTextColor(T.Color("text"))
    input:SetWidth(WIDTH - 2 * PAD - 32)
    area:SetScrollChild(input)
    area:SetScript("OnSizeChanged", function(_, width)
        if width and width > 40 then input:SetWidth(width) end -- never without a width
    end)
    input:SetScript("OnSizeChanged", LayoutSoon)
    area:SetScript("OnMouseDown", function() input:SetFocus() end)

    placeholder = T.Text(composer, "sans", UI_SIZE + 1, "muted")
    placeholder:SetWordWrap(false)
    placeholder:SetPoint("TOPLEFT", area, "TOPLEFT", 0, 0)
    placeholder:SetPoint("RIGHT", area, "RIGHT")

    -- the cursor stays in view as the text grows
    input:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local offset, view = area:GetVerticalScroll(), area:GetHeight()
        y = -y
        if y < offset then
            area:SetVerticalScroll(y)
        elseif y + height > offset + view then
            area:SetVerticalScroll(y + height - view)
        end
    end)
    input:SetScript("OnTextChanged", function(self, userInput)
        local text = self:GetText() or ""
        if userInput and #text - (self.lastLength or 0) >= PASTE_SIZE and IsAnswer(text) then
            self.lastLength = 0
            TakeAnswer(text)
            return
        end
        self.lastLength = #text
        UpdatePlaceholder()
    end)
    input:SetScript("OnEnterPressed", function(self)
        if IsShiftKeyDown() then
            local cursor = self:GetCursorPosition()
            if (self:GetText() or ""):sub(cursor, cursor) ~= "\n" then self:Insert("\n") end
        else
            Send()
        end
    end)
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    plus = T.IconButton(composer, "Plus", 16, L.MORE, ToggleActions, true)
    plus:SetPoint("BOTTOMLEFT", 10, 10)

    sendButton = CreateFrame("Button", nil, composer)
    sendButton:SetSize(30, 30)
    sendButton:SetPoint("BOTTOMRIGHT", -10, 10)
    T.Box(sendButton, 8, "send", nil, "send")
    local arrow = T.Icon(sendButton, "ArrowUp", 16, "white")
    arrow:SetPoint("CENTER")
    sendButton:SetScript("OnEnter", function(self) T.PaintBox(self, "sendHover") end)
    sendButton:SetScript("OnLeave", function(self) T.PaintBox(self, "send") end)
    sendButton:SetScript("OnClick", Send)

    effortPicker = NewPicker("effort", L.EFFORT_TIP)
    effortPicker:SetPoint("RIGHT", sendButton, "LEFT", -6, 0)
    modelPicker = NewPicker("model", L.MODEL_TIP)
    modelPicker:SetPoint("RIGHT", effortPicker, "LEFT", 0, 0)
end

-- Over the box you write in: the question to copy, selected.
local function BuildStrip()
    strip = CreateFrame("Frame", nil, composer)
    strip:SetAllPoints()
    strip:SetFrameLevel(composer:GetFrameLevel() + 10)
    strip:EnableMouse(true)
    T.Box(strip, 16, "field", "clay")

    local icon = T.Icon(strip, "Copy", 16, "clay")
    icon:SetPoint("TOPLEFT", 16, -14)
    local hint = T.Text(strip, "sansMedium", UI_SIZE, "text")
    hint:SetWordWrap(false)
    hint:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    hint:SetText(L.COPY_STRIP)
    strip.hint = hint
    local close = T.IconButton(strip, "Close", 14, L.CANCEL, HideStrip)
    close:SetPoint("TOPRIGHT", -8, -8)

    local clip = CreateFrame("Frame", nil, strip)
    clip:SetPoint("TOPLEFT", 16, -40)
    clip:SetPoint("BOTTOMRIGHT", -16, 12)
    clip:SetClipsChildren(true)
    stripBox = CreateFrame("EditBox", nil, clip)
    stripBox:SetMultiLine(true)
    stripBox:SetAutoFocus(false)
    stripBox:SetMaxLetters(0)
    stripBox:SetPoint("TOPLEFT")
    stripBox:SetPoint("TOPRIGHT")
    T.SetFont(stripBox, "mono", 11)
    stripBox:SetTextColor(T.Color("muted"))
    -- read only: what is typed is undone, the whole text selected again
    stripBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(self.copyText or "")
            self:HighlightText()
        end
    end)
    stripBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    stripBox:SetScript("OnMouseUp", function(self) self:HighlightText() end)
    stripBox:SetScript("OnEscapePressed", HideStrip)
    stripBox:SetScript("OnKeyDown", function(_, key)
        if key == "C" and (IsControlKeyDown() or (IsMetaKeyDown and IsMetaKeyDown())) then
            C_Timer.After(0.1, Copied) -- once the game has copied the selection
        end
    end)
    strip:SetScript("OnMouseDown", function() stripBox:SetFocus() end)
    strip:Hide()
end

-- The window's own background, as see-through as the settings say; what is on
-- it stays as it is.
function ns.ApplyOpacity()
    if frame then T.PaintBox(frame, T.Faded("page", ns.db.options.opacity / 100)) end
end

local function Build()
    frame = CreateFrame("Frame", "ClaudeInWoWWindow", UIParent)
    HEADER = T.Skin().header or HEADER
    local place = ns.db and ns.db.claude
    frame:SetSize(place and place.width or WIDTH, place and place.height or HEIGHT)
    if place and place.left and place.top then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", place.left, place.top)
    else
        frame:SetPoint("CENTER")
    end
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(380, 460, 1000, 1400) end
    frame:EnableMouse(true)
    T.Box(frame, 14, "page", "border", "window")
    ns.ApplyOpacity()
    UISpecialFrames[#UISpecialFrames + 1] = "ClaudeInWoWWindow" -- Escape closes it

    BuildHeader()
    BuildTabs()
    BuildBody()
    BuildComposer()
    BuildStrip()
    ns.BuildSelection(content)
    strip:SetScript("OnShow", LayoutSoon)
    strip:SetScript("OnHide", LayoutSoon)
    LayoutBottom()

    -- the next step, over the box you write in
    nextButton = T.Chip(frame, "Clipboard", "", function(self) if self.run then self.run() end end, true)
    nextButton:SetPoint("BOTTOM", composer, "TOP", 0, 10)
    nextButton:SetFrameLevel(composer:GetFrameLevel() + 5)
    nextButton:Hide()

    -- the settings page (Settings.lua), in place of the conversation
    settingsArea = CreateFrame("Frame", nil, frame)
    settingsArea:SetPoint("TOPLEFT", 0, -HEADER - 1)
    settingsArea:SetPoint("BOTTOMRIGHT")
    settingsArea:Hide()

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel(composer:GetFrameLevel() + 20)
    local gripTexture = grip:CreateTexture(nil, "OVERLAY")
    gripTexture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gripTexture:SetAllPoints()
    gripTexture:SetVertexColor(T.Color("muted"))
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SavePlace()
        ns.RenderClaude()
    end)

    frame:SetScript("OnSizeChanged", function() ns.RenderClaude() end)
    frame:SetScript("OnHide", function()
        input:ClearFocus()
        StopThinking()
        HideStrip()
        if menu then menu:Hide() end
    end)
    for _, event in ipairs({ "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP" }) do frame:RegisterEvent(event) end -- the bars
    frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    pcall(frame.RegisterEvent, frame, "QUEST_DATA_LOAD_RESULT") -- not in the Classic versions
    local redrawDue = false
    frame:SetScript("OnEvent", function(_, event, id)
        local due = event == "ITEM_DATA_LOAD_RESULT" and itemsDue or event == "QUEST_DATA_LOAD_RESULT" and questsDue
        if not due then
            UpdateContext()
        elseif due[id] then -- one a link waited for: drawn again once, for all that came
            due[id] = due == questsDue and false or nil -- a quest the game does not know is not asked again
            if not redrawDue then
                redrawDue = true
                C_Timer.After(0.2, function()
                    redrawDue = false
                    ns.RenderClaude()
                end)
            end
        end
    end)
    frame:Hide()
end

----------------------------------------------------------------------
-- Opening it
----------------------------------------------------------------------

-- Opens the window; mode "paste" makes the box wait for Claude's answer,
-- "settings" shows the settings page.
function ns.OpenClaude(mode)
    if not frame then Build() end
    if mode == "paste" then pasteMode = true end
    frame:Show()
    ShowSettings(mode == "settings")
    UpdateContext()
    ns.RenderClaude(true)
    if settingsShown then
        ns.StopTour()
    elseif ns.TourDue() then
        ns.StartTour()
    elseif not (strip and strip:IsShown()) then
        input:SetFocus()
    end
end

-- The window and its parts, for the guided tour.
function ns.TourTargets()
    return frame, { input = composer, shortcuts = empty:IsShown() and empty.chips[1] or nil, model = modelPicker, tabs = tabStrip, gear = gear }
end

function ns.ToggleClaude()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        ns.OpenClaude()
    end
end

-- The question to copy, when the photo cannot carry it.
local function CopyInstead(message)
    message.state = "copy"
    message.signal, message.slot = nil, nil
    pasteMode = false
    ns.RenderClaude(true)
    input:ClearFocus()
    Show(message)
end

-- A question prepared (Ask.lua): your message in the conversation, sent in
-- a photo, or selected for Ctrl+C when no photo can be taken now or the player
-- prefers so (settings). label: what the bubble says; kind: "free" or "bags";
-- wanted: what to read for it besides what it speaks of (Topics.lua).
function ns.ShowCopy(text, label, kind, wanted)
    ns.OpenClaude()
    local message = AddMessage({ role = "you", text = label or match(text, "^[^\n]*"), state = "sending", kind = kind or "free" })
    prepared[message] = text
    if ns.db.options.sendByPhoto then ns.TakeChannel(message) end
    pasteMode = not message.slot -- Claude's answer comes next, by itself or to paste
    ns.RenderClaude(true)
    -- the conversation it was asked in, and what the settings say for the
    -- silent mode: the model and its effort, how it answers, whether to start
    -- its Claude session afresh
    local options
    message.model, message.effort, options = ns.QuestionChoices()
    local question = {
        id = message.at, kind = kind or "free", text = message.text, at = message.at,
        tab = TabTitle(CurrentTab()), newSession = ns.db.claudeNewSession or nil, got = Answered(),
        model = message.model, effort = message.effort, options = options,
        signal = message.signal, slot = message.slot,
    }
    local function SendIt()
        local started = ns.TakePhoto(question, function(ok)
            if ok then
                message.state = "sent"
                message.sentAt = time()
                ns.db.claudeNewSession = nil
                if message.signal then ns.WatchAnswers() end
                ns.RenderClaude(true)
            else
                CopyInstead(message)
            end
        end)
        if not started then CopyInstead(message) end
    end
    if not ns.db.options.sendByPhoto then return CopyInstead(message) end
    local topics, reads = ns.WhatToRead(message.text, wanted)
    if #topics + #reads == 0 then return SendIt() end
    ns.Gather(topics, function(read)
        if #reads > 0 then read.reads = ns.ReadAll(reads) end
        question.read = read
        SendIt()
    end)
end

----------------------------------------------------------------------
-- The module
----------------------------------------------------------------------

local function Skins()
    local list = {}
    for index, skin in ipairs(T.Skins()) do list[index] = { value = skin.key, label = L[skin.label] or skin.label } end
    return list
end

local function Languages()
    local list = {
        { value = "claude", label = L.LANGUAGE_CLAUDE },
        { value = "game", label = L.LANGUAGE_GAME },
    }
    for _, language in ipairs(ns.Languages()) do list[#list + 1] = { value = language.code, label = language.name } end
    return list
end

-- Another language is picked: so too.
local function LanguageWaits()
    if ns.LanguageOf(ns.db.options.language) ~= ns.Language() then return L.SKIN_WAITS end
end

-- Another skin is picked: it waits for the interface to load again.
local function SkinWaits()
    if ns.db.options.skin ~= T.Skin().key then return L.SKIN_WAITS end
end

local function ReloadChip(parent)
    local holder = CreateFrame("Frame", nil, parent)
    local chip = T.Chip(holder, "Check", L.SKIN_RELOAD, function() ns.ReloadInterface() end, true)
    chip:SetPoint("TOPLEFT")
    function holder:Refresh(width)
        local waits = SkinWaits() ~= nil or LanguageWaits() ~= nil
        chip:SetShown(waits)
        self:SetSize(width, waits and 28 or 1)
        return waits and 28 or 1
    end
    return holder
end

ns.Module({
    key = "window", category = "window", order = 10, fixed = true, title = "WINDOW_MODULE", tip = "WINDOW_MODULE_TIP",
    settings = {
        { key = "language", label = "LANGUAGE", tip = "LANGUAGE_TIP", default = "claude", choices = Languages, warning = LanguageWaits },
        { key = "skin", label = "SKIN", tip = "SKIN_TIP", default = "claude", choices = Skins, warning = SkinWaits },
        { key = "opacity", label = "OPTION_OPACITY", tip = "OPTION_OPACITY_TIP", default = 100, slider = { 20, 100, 5 }, changed = ns.ApplyOpacity },
    },
    custom = ReloadChip,
})
