-- claude-in-wow module: what the answers took. Each answer that says its
-- tokens is noted (ns.NoteUsage, from the window), account-wide:
--   ns.db.usage = { list = { { at, question, model, effort, tokens, cached, detail, seconds, who } },  the last one last
--     days = { ["2026-11-24"] = { tokens, cached, answers } },     kept for good
--     models = { haiku-5.5 = { tokens, answers } } }
-- The settings' tab on it: after the player's plan (Plan.lua): today, the last days,
-- everything; by day, by model; and the last answers, with where its tokens went (ns.ShowAnswerDetail).

local addonName, ns = ...

local date, floor, format, gsub, ipairs, max, min, pairs, sort, time, tostring, tremove =
    date, math.floor, string.format, string.gsub, ipairs, math.max, math.min, pairs, table.sort, time, tostring, table.remove
local L, T = ns.L, ns.Theme

local MAX_LIST = 500    -- answers kept one by one
local MAX_QUESTION = 90 -- characters of a question kept
local DAYS = 14         -- in the chart
local SHOWN = 10        -- answers shown, the last ones
local CHART = 56        -- the chart's height

ns.Category({ key = "usage", title = "TAB_USAGE", order = 55 })

----------------------------------------------------------------------
-- What is noted
----------------------------------------------------------------------

local function Day(at)
    return date("%Y-%m-%d", at)
end

local function Count(usage, entry)
    local day = Day(entry.at)
    local days, models = usage.days, usage.models
    days[day] = days[day] or { tokens = 0, cached = 0, answers = 0 }
    days[day].tokens, days[day].cached, days[day].answers =
        days[day].tokens + entry.tokens, days[day].cached + (entry.cached or 0), days[day].answers + 1
    local model = entry.model or "?"
    models[model] = models[model] or { tokens = 0, answers = 0 }
    models[model].tokens, models[model].answers = models[model].tokens + entry.tokens, models[model].answers + 1
end

local function Trim(usage)
    while #usage.list > MAX_LIST do tremove(usage.list, 1) end
end

-- A text cut at a length, never in the middle of a letter.
local function Cut(text, length)
    if #text <= length then return text end
    return (gsub(text:sub(1, length), "[\128-\255]*$", "")) .. "\226\128\166"
end

-- The answers of the conversations still there, when nothing was noted yet.
local function FromConversations(usage)
    for who, char in pairs(ns.db.characters or {}) do
        for _, tab in ipairs(char.chat and char.chat.tabs or {}) do
            local question
            for _, message in ipairs(tab.messages or {}) do
                if message.role == "you" then
                    question = message.text
                elseif message.tokens and message.at then
                    usage.list[#usage.list + 1] = {
                        at = message.at, question = Cut(question or "", MAX_QUESTION), model = message.model, effort = message.effort,
                        tokens = message.tokens, cached = message.cached, detail = message.detail, who = who,
                    }
                end
            end
        end
    end
    sort(usage.list, function(a, b) return a.at < b.at end)
    for _, entry in ipairs(usage.list) do Count(usage, entry) end
    Trim(usage)
end

local function Usage()
    local usage = ns.db.usage
    if not usage then
        usage = { list = {}, days = {}, models = {} }
        ns.db.usage = usage
        FromConversations(usage)
    end
    return usage
end

-- An answer that came: answer = { at, model, effort, tokens, cached, detail }.
function ns.NoteUsage(question, answer, seconds)
    if not answer.tokens then return end
    local usage = Usage()
    for index = #usage.list, max(1, #usage.list - 20), -1 do -- already there, from the conversations
        local entry = usage.list[index]
        if entry.at == answer.at and entry.tokens == answer.tokens then return end
    end
    local entry = {
        at = answer.at or time(), question = Cut(question or "", MAX_QUESTION), model = answer.model, effort = answer.effort,
        tokens = answer.tokens, cached = answer.cached, detail = answer.detail, seconds = seconds, who = ns.key,
    }
    usage.list[#usage.list + 1] = entry
    Count(usage, entry)
    Trim(usage)
end

-- The tokens, those from the cache and the answers of the last days (nil: all).
function ns.UsageOf(days)
    local tokens, cached, answers = 0, 0, 0
    local from = days and Day(time() - (days - 1) * 86400)
    for day, sum in pairs(Usage().days) do
        if not from or day >= from then tokens, cached, answers = tokens + sum.tokens, cached + sum.cached, answers + sum.answers end
    end
    return tokens, cached, answers
end

-- "950", "52 k", "1,2 M".
function ns.ShortNumber(count)
    if count < 1000 then return tostring(count) end
    if count < 999500 then return format(L.USAGE_THOUSAND, tostring(floor(count / 1000 + 0.5))) end
    local tenths = floor(count / 100000 + 0.5)
    return format(L.USAGE_MILLION, floor(tenths / 10) .. (tenths % 10 > 0 and L.USAGE_DECIMAL .. tenths % 10 or ""))
end

-- Whether a count takes the singular (none does too, in some languages).
function ns.IsOne(count)
    return count == 1 or count == 0 and L.ZERO_IS_ONE
end

-- "52 k jetons, 3 réponses".
function ns.UsageLine(tokens, answers)
    return format(ns.IsOne(answers) and L.USAGE_LINE_ONE or L.USAGE_LINE, ns.ShortNumber(tokens), answers)
end

local function Percent(part, whole)
    return whole > 0 and floor(part / whole * 100 + 0.5) or 0
end

----------------------------------------------------------------------
-- The tab
----------------------------------------------------------------------

-- A card: a name, the tokens, how many answers.
local function Card(parent, label, days)
    local card = CreateFrame("Frame", nil, parent)
    T.Box(card, 10, "field", "border")
    card.label = T.Text(card, "sans", 11, "muted")
    card.label:SetText(L[label])
    card.value = T.Text(card, "sansMedium", 18, "text")
    card.sub = T.Text(card, "sans", 11, "muted")
    for _, text in ipairs({ card.label, card.value, card.sub }) do text:SetWordWrap(false) end
    card.label:SetPoint("TOPLEFT", 12, -9)
    card.label:SetPoint("RIGHT", -8, 0)
    card.sub:SetPoint("BOTTOMLEFT", 12, 9)
    card.sub:SetPoint("RIGHT", -8, 0)
    function card:Refresh(wide)
        local tokens, cached, answers = ns.UsageOf(days)
        self.value:SetText(ns.ShortNumber(tokens))
        self.sub:SetText(format(ns.IsOne(answers) and L.USAGE_ANSWER or L.USAGE_ANSWERS, answers, Percent(cached, tokens)))
        self.value:ClearAllPoints()
        if wide then self.value:SetPoint("TOPLEFT", 12, -25) else self.value:SetPoint("TOPRIGHT", -12, -8) end
    end
    return card
end

-- A bar of the chart: a day.
local function Bar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:EnableMouse(true)
    bar.fill = T.Line(bar, "clay")
    bar.fill:SetPoint("BOTTOMLEFT")
    bar.fill:SetPoint("BOTTOMRIGHT")
    bar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(date(L.USAGE_DAY, self.at), 1, 1, 1)
        GameTooltip:AddLine(ns.UsageLine(self.sum and self.sum.tokens or 0, self.sum and self.sum.answers or 0), 0.76, 0.75, 0.71)
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", GameTooltip_Hide)
    return bar
end

-- An answer: its question and its tokens, then the rest.
local function Line(parent)
    local line = CreateFrame("Frame", nil, parent)
    line:EnableMouse(true)
    T.Box(line, 6, "none")
    line.question = T.Text(line, "sans", 12, "text")
    line.tokens = T.Text(line, "sansMedium", 12, "text")
    line.note = T.Text(line, "sans", 11, "muted")
    for _, text in ipairs({ line.question, line.tokens, line.note }) do text:SetWordWrap(false) end
    line.tokens:SetPoint("TOPRIGHT", -6, -4)
    line.tokens:SetJustifyH("RIGHT")
    line.question:SetPoint("TOPLEFT", 6, -4)
    line.question:SetPoint("RIGHT", line.tokens, "LEFT", -10, 0)
    line.note:SetPoint("TOPLEFT", 6, -20)
    line.note:SetPoint("RIGHT", -6, 0)
    line:SetScript("OnEnter", function(self)
        T.PaintBox(self, "hover")
        ns.ShowAnswerDetail(self, self.entry)
    end)
    line:SetScript("OnLeave", function(self)
        T.PaintBox(self, "none")
        GameTooltip:Hide()
    end)
    function line:Fill(entry)
        self.entry = entry
        self.question:SetText(ns.PlainText(entry.question ~= "" and entry.question or "?"))
        self.tokens:SetText(ns.ShortNumber(entry.tokens))
        local parts = { date(L.USAGE_DATE, entry.at), entry.model and ns.ModelName(entry.model) or nil }
        if entry.effort then parts[#parts + 1] = L.EFFORTS[entry.effort] or entry.effort end
        if entry.seconds then parts[#parts + 1] = format(L.USAGE_SECONDS, entry.seconds) end
        parts[#parts + 1] = format(L.USAGE_CACHED, Percent(entry.cached or 0, entry.tokens))
        self.note:SetText(table.concat(parts, "  \194\183  "))
    end
    return line
end

local function Tab(parent)
    local frame = CreateFrame("Frame", nil, parent)
    local cards = { Card(frame, "USAGE_TODAY", 1), Card(frame, "USAGE_WEEK", 7), Card(frame, "USAGE_ALL") }
    local heads, bars, models, lines = {}, {}, {}, {}
    for index, key in ipairs({ "USAGE_DAYS", "USAGE_MODELS", "USAGE_LIST" }) do
        heads[index] = T.Text(frame, "sansMedium", 13, "text")
        heads[index]:SetText(format(L[key], key == "USAGE_LIST" and SHOWN or DAYS))
    end
    local first, last = T.Text(frame, "sans", 10, "muted"), T.Text(frame, "sans", 10, "muted")
    last:SetJustifyH("RIGHT")
    local base = T.Line(frame)
    base:SetHeight(1)
    for index = 1, DAYS do bars[index] = Bar(frame) end
    local none = T.Text(frame, "sans", 12, "muted")
    none:SetText(L.USAGE_NONE)
    local sure = false
    local clear = T.Chip(frame, "Trash", L.USAGE_CLEAR, function()
        if sure then
            ns.db.usage = { list = {}, days = {}, models = {} }
        end
        sure = not sure
        ns.RenderClaude()
    end)
    frame:SetScript("OnHide", function() sure = false end)

    -- The days, from the oldest: the tallest bar is the fullest day.
    local function Chart(width, y)
        local usage, top = Usage(), 1
        for index, bar in ipairs(bars) do
            bar.at = time() - (DAYS - index) * 86400
            bar.sum = usage.days[Day(bar.at)]
            top = max(top, bar.sum and bar.sum.tokens or 0)
        end
        local step = floor(width / DAYS)
        for index, bar in ipairs(bars) do
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT", (index - 1) * step, -y)
            bar:SetSize(step - 4, CHART)
            local tokens = bar.sum and bar.sum.tokens or 0
            bar.fill:SetHeight(tokens > 0 and max(2, floor(tokens / top * CHART + 0.5)) or 0.01)
            bar.fill:SetAlpha(index == DAYS and 1 or 0.6)
        end
        y = y + CHART
        base:ClearAllPoints()
        base:SetPoint("TOPLEFT", 0, -y)
        base:SetWidth(step * DAYS - 4)
        for text, index in pairs({ [first] = 1, [last] = DAYS }) do text:SetText(date(L.USAGE_DAY, bars[index].at)) end
        first:ClearAllPoints()
        first:SetPoint("TOPLEFT", 0, -y - 4)
        last:ClearAllPoints()
        last:SetPoint("TOPRIGHT", frame, "TOPLEFT", step * DAYS - 4, -y - 4)
        return y + 18
    end

    local function Head(index, y)
        heads[index]:ClearAllPoints()
        heads[index]:SetPoint("TOPLEFT", 0, -y)
        return y + 22
    end

    function frame:Refresh(width)
        local usage, y = Usage(), 0
        local wide = width >= 330
        local each = wide and floor((width - 16) / 3) or width
        for index, card in ipairs(cards) do
            card:Refresh(wide)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", wide and (index - 1) * (each + 8) or 0, -y)
            card:SetSize(each, wide and 72 or 46)
            if not wide then y = y + 52 end
        end
        y = y + (wide and 72 or 0) + 18

        local any = #usage.list > 0
        none:SetShown(not any)
        for _, object in ipairs({ heads[1], heads[2], heads[3], first, last, base, clear }) do object:SetShown(any) end
        for _, bar in ipairs(bars) do bar:SetShown(any) end
        for _, text in ipairs(models) do text:Hide() end
        for _, line in ipairs(lines) do line:Hide() end
        if not any then
            none:ClearAllPoints()
            none:SetPoint("TOPLEFT", 0, -y)
            self:SetSize(width, y + 20)
            return y + 20
        end

        y = Chart(width, Head(1, y)) + 14

        y = Head(2, y)
        local names = {}
        for name in pairs(usage.models) do names[#names + 1] = name end
        sort(names, function(a, b) return usage.models[a].tokens > usage.models[b].tokens end)
        for index, name in ipairs(names) do
            models[index] = models[index] or T.Text(frame, "sans", 12, "secondary")
            local sum = usage.models[name]
            models[index]:SetText(T.Code("text") .. ns.ModelName(name) .. "|r   " .. ns.UsageLine(sum.tokens, sum.answers))
            models[index]:ClearAllPoints()
            models[index]:SetPoint("TOPLEFT", 0, -y)
            models[index]:Show()
            y = y + 18
        end
        y = Head(3, y + 14)

        local count = #usage.list
        for index = 1, min(SHOWN, count) do
            local line = lines[index] or Line(frame)
            lines[index] = line
            line:Fill(usage.list[count - index + 1])
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", -6, -y)
            line:SetSize(width + 12, 38)
            line:Show()
            y = y + 40
        end
        y = y + 10
        clear:SetLabel(sure and L.USAGE_CLEAR_SURE or L.USAGE_CLEAR)
        clear:ClearAllPoints()
        clear:SetPoint("TOPRIGHT", frame, "TOPLEFT", width, -y)
        self:SetSize(width, y + 28)
        return y + 28
    end
    return frame
end

ns.Module({ key = "usage", category = "usage", order = 10, fixed = true, title = "USAGE_MODULE", tip = "USAGE_MODULE_TIP", custom = Tab })
