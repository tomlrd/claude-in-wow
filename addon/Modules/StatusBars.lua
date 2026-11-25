-- claude-in-wow module: the two bars under the box you write in. The first
-- is the character, the zone, the server and the layer (World.lua); the second
-- Claude's session (its questions, what it holds, the answers on their way, those that
-- may still come by themselves) and
-- today's tokens: a click opens the settings on the usage. Each bar's tooltip says
-- more, the gold of the account's characters too.

local addonName, ns = ...

local date, floor, format, ipairs, pairs, pcall, sort, tostring =
    date, math.floor, string.format, ipairs, pairs, pcall, table.sort, tostring
local L, T = ns.L, ns.Theme

local HEIGHT = 18
local GOLD = "|TInterface\\MoneyFrame\\UI-GoldIcon:11:11:1:0|t"
local DOT = "  \194\183  "

local function Try(fn, ...)
    if not fn then return nil end
    local ok, first, second = pcall(fn, ...)
    if ok then return first, second end
end

----------------------------------------------------------------------
-- The character and the account
----------------------------------------------------------------------

local function Gold(copper)
    return ns.GroupNumber(floor((copper or 0) / 10000)) .. GOLD
end

-- A class' colour, as a text's code.
local function ClassCode(file)
    local color = file and C_ClassColor and Try(C_ClassColor.GetClassColor, file)
    return color and color.r and format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255) or T.Code("text")
end

ns.ClassCode = ClassCode

-- Every character noted, this one as it is now: { name, level, class, file, money, at }.
local function Characters()
    local list = {}
    for key, char in pairs(ns.db.characters or {}) do
        local info = char.character
        if key == ns.key then
            local class, file = UnitClass("player")
            list[#list + 1] = { name = key, level = UnitLevel("player"), class = class, file = file, money = GetMoney(), me = true }
        elseif info and info.level then
            list[#list + 1] = { name = key, level = info.level, class = info.class, file = info.classFile, money = info.money or 0, at = char.savedAt }
        end
    end
    sort(list, function(a, b) return a.money > b.money end)
    return list
end

local function Total(list)
    local total = 0
    for _, char in ipairs(list) do total = total + (char.money or 0) end
    return total
end

local function FreeSlots()
    local free = 0
    for bag = 0, 5 do free = free + (Try(C_Container and C_Container.GetContainerNumFreeSlots, bag) or 0) end
    return free
end

local function Quests()
    local count, ready = 0, 0
    for index = 1, Try(ns.Game.QuestLines) or 0 do
        local info = Try(ns.Game.QuestLine, index)
        if info and not info.isHeader and not info.isHidden then
            count = count + 1
            if Try(ns.Game.QuestComplete, info.questID) then ready = ready + 1 end
        end
    end
    return count, ready
end

local function CharacterBar(bar)
    local _, file = UnitClass("player")
    local zone = GetRealZoneText and GetRealZoneText() or GetZoneText()
    bar.left:SetText(ClassCode(file) .. (ns.key or UnitName("player") or "") .. "|r " .. tostring(UnitLevel("player") or "") .. (zone and zone ~= "" and DOT .. zone or ""))
    local server, layer, outside = ns.World()
    local parts = { server }
    if outside then parts[#parts + 1] = format(L.BAR_LAYER, layer or "?") end
    bar.right:SetText(table.concat(parts, DOT))
end

local function CharacterTip()
    local _, file = UnitClass("player")
    GameTooltip:SetText(ClassCode(file) .. (ns.key or "") .. "|r", 1, 1, 1)
    local function Line(label, value) GameTooltip:AddDoubleLine(label, value, 0.76, 0.75, 0.71, 1, 1, 1) end
    local xp, most = ns.Clean(UnitXP("player")), ns.Clean(UnitXPMax("player"))
    if xp and most and most > 0 then Line(L.BAR_XP, format(L.BAR_XP_VALUE, floor(xp / most * 100))) end
    local rested = ns.Clean(GetXPExhaustion and GetXPExhaustion())
    if rested and most and most > 0 then Line(L.BAR_RESTED, format(L.BAR_XP_VALUE, floor(rested / most * 100))) end
    Line(L.BAR_BAGS, tostring(FreeSlots()))
    local count, ready = Quests()
    Line(L.BAR_QUESTS, format(L.BAR_QUESTS_VALUE, count, ready))
    local server, layer, outside = ns.World()
    if server then Line(L.BAR_SERVER_NAME, server) end
    if layer then Line(L.BAR_LAYER_NAME, tostring(layer)) elseif outside then GameTooltip:AddLine(L.BAR_LAYER_HINT, 0.6, 0.6, 0.6) end
    GameTooltip:AddLine(" ")
    local list = Characters()
    for _, char in ipairs(list) do
        GameTooltip:AddDoubleLine(ClassCode(char.file) .. char.name .. "|r " .. tostring(char.level) .. (char.at and "  " .. T.Code("muted") .. date(L.BAR_AT, char.at) .. "|r" or ""),
            Gold(char.money), 1, 1, 1, 1, 1, 1)
    end
    if #list > 1 then GameTooltip:AddDoubleLine(L.BAR_TOTAL, Gold(Total(list)), 1, 0.82, 0, 1, 1, 1) end
end

----------------------------------------------------------------------
-- Claude's session and the usage
----------------------------------------------------------------------

-- The answers that may still come by themselves, and how many there are; none when they
-- do not.
local function Slots()
    if not ns.On("arrive") then return 0, 0 end
    return ns.SlotsLeft()
end

local function SessionBar(bar)
    local status, waiting = ns.db.claudeStatus, #ns.WaitingQuestions()
    local parts = {}
    if waiting > 0 then parts[1] = T.Code("clay") .. (waiting == 1 and L.BAR_WAITING_ONE or format(L.BAR_WAITING, waiting)) .. "|r" end
    if ns.db.claudeNewSession then
        parts[#parts + 1] = L.BAR_NEW_SESSION
    elseif status then
        local questions = status.questions or 0
        parts[#parts + 1] = format(ns.IsOne(questions) and L.BAR_QUESTION or L.BAR_QUESTIONS, questions)
        if status.tokens then parts[#parts + 1] = format(L.BAR_HELD, ns.ShortNumber(status.tokens * 1000)) end
    elseif waiting == 0 then
        parts[1] = L.BAR_NO_SESSION
    end
    local left, all = Slots()
    if all > 0 then parts[#parts + 1] = (ns.SlotsWarning() and T.Code("clay") or "") .. format(L.BAR_SLOTS, left, all) .. (ns.SlotsWarning() and "|r" or "") end
    bar.left:SetText(table.concat(parts, DOT))
    -- the addon's, then the player's whole plan, each in the colour it has in the settings
    local uses, shown, plan = {}, ns.db.options.barUse, ns.PlanLines()[1]
    if shown ~= "plan" then uses[1] = T.Code("accent") .. format(L.BAR_TODAY, (ns.ShortNumber((ns.UsageOf(1))))) .. "|r" end
    if shown ~= "addon" and plan and plan.percent then uses[#uses + 1] = T.Code("plan") .. format(L.BAR_PLAN, plan.percent) .. "|r" end
    if shown ~= "addon" and ns.db.claudeKey then uses[#uses + 1] = T.Code("plan") .. format(L.BAR_KEY, ns.Dollars(ns.PriceOf(1))) .. "|r" end
    bar.right:SetText(table.concat(uses, DOT))
end

local function SessionTip()
    local status = ns.db.claudeStatus
    GameTooltip:SetText(status and format(L.BAR_SESSION_NAME, status.session) or L.BAR_NO_SESSION, 1, 1, 1)
    local function Line(label, value) GameTooltip:AddDoubleLine(label, value, 0.76, 0.75, 0.71, 1, 1, 1) end
    if status then
        if status.tokens then Line(L.BAR_SESSION_HELD, ns.ShortNumber(status.tokens * 1000)) end
        if status.at then Line(L.BAR_LAST, format(L.BAR_LAST_VALUE, date("%H:%M", status.at), status.seconds or 0)) end
        if status.model then Line(L.BAR_MODEL, ns.ModelName(status.model)) end
        GameTooltip:AddLine(" ")
    end
    local left, all = Slots()
    if all > 0 then
        Line(L.BAR_SLOTS_NAME, format(L.BAR_SLOTS_VALUE, left, all))
        GameTooltip:AddLine(" ")
    end
    local plan = ns.PlanLines()
    if plan[1] then
        GameTooltip:AddLine(L.PLAN, 1, 1, 1)
        for _, line in ipairs(plan) do
            local percent, own = ns.PlanPercent(line)
            Line(line.name, percent .. (own and ", " .. own or ""))
        end
        GameTooltip:AddLine(" ")
    end
    if ns.db.claudeKey then
        GameTooltip:AddLine(L.KEY, 1, 1, 1)
        for _, span in ipairs({ { L.BAR_DAY, 1 }, { L.BAR_WEEK, 7 }, { L.BAR_ALL } }) do Line(span[1], ns.Dollars(ns.PriceOf(span[2]))) end
        GameTooltip:AddLine(" ")
    end
    GameTooltip:AddLine(L.USAGE_MODULE, 1, 1, 1)
    for _, span in ipairs({ { L.BAR_DAY, 1 }, { L.BAR_WEEK, 7 }, { L.BAR_ALL } }) do
        local tokens, _, answers = ns.UsageOf(span[2])
        Line(span[1], ns.UsageLine(tokens, answers))
    end
    GameTooltip:AddLine(L.BAR_CLICK, 0.6, 0.6, 0.6)
end

----------------------------------------------------------------------
-- The bars
----------------------------------------------------------------------

local BARS = {
    { key = "route", always = true, wanted = function() return ns.RouteActive() end, fill = function(bar)
        local line = ns.RouteLine()
        bar.left:SetText(line and T.Code("accent") .. ns.PlainText(line) .. "|r" or "")
        bar.right:SetText(L.ROUTE_BAR)
    end, tip = function()
        local line, advice = ns.RouteLine()
        GameTooltip:SetText(line or "", 1, 1, 1, 1, true)
        if advice then GameTooltip:AddLine(advice, 0.76, 0.75, 0.71, true) end
        GameTooltip:AddLine(L.ROUTE_BAR_TIP, 0.6, 0.6, 0.6, true)
    end, click = function(self) if ns.RouteActive() then ns.ToggleMenu(self, ns.RouteMenu(), true) end end },
    { key = "barCharacter", fill = CharacterBar, tip = CharacterTip },
    { key = "barSession", fill = SessionBar, tip = SessionTip, click = function()
        ns.db.settingsTab = "usage"
        ns.OpenClaude("settings")
    end },
}
local bars -- the frames, once the window is built

local function NewBar(parent, spec)
    local bar = CreateFrame("Button", nil, parent)
    bar:SetHeight(HEIGHT)
    bar.spec = spec
    bar.right = T.Text(bar, "sans", 11, "muted")
    bar.right:SetJustifyH("RIGHT")
    bar.left = T.Text(bar, "sans", 11, "muted")
    for _, text in ipairs({ bar.left, bar.right }) do
        text:SetWordWrap(false)
        text:SetJustifyV("MIDDLE")
    end
    bar.right:SetPoint("RIGHT", -2, 0)
    bar.left:SetPoint("LEFT", 2, 0)
    bar.left:SetPoint("RIGHT", bar.right, "LEFT", -10, 0)
    bar:SetScript("OnEnter", function(self)
        self.left:SetTextColor(T.Color("secondary"))
        self.right:SetTextColor(T.Color("secondary"))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        spec.tip()
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function(self)
        self.left:SetTextColor(T.Color("muted"))
        self.right:SetTextColor(T.Color("muted"))
        GameTooltip:Hide()
    end)
    if spec.click then bar:SetScript("OnClick", spec.click) end
    return bar
end

-- Places the bars shown at the bottom of the window: the height they take.
function ns.LayoutBars(parent, pad, bottom, shown)
    if not bars then
        bars = {}
        for index, spec in ipairs(BARS) do bars[index] = NewBar(parent, spec) end
    end
    local y = bottom
    for index = #bars, 1, -1 do -- from the last one up
        local bar = bars[index]
        local on = (bar.spec.always or ns.On(bar.spec.key)) and (not bar.spec.wanted or bar.spec.wanted())
        bar:SetShown(on and shown)
        if on then
            bar:SetPoint("BOTTOMLEFT", pad, y)
            bar:SetPoint("BOTTOMRIGHT", -pad, y)
            y = y + HEIGHT
        end
    end
    return y - bottom
end

-- What a bar shown says, read again.
function ns.RefreshBar(key)
    for _, bar in ipairs(bars or {}) do
        if bar.spec.key == key and bar:IsVisible() then bar.spec.fill(bar) end
    end
end

-- What they say, read again; hidden with the box you write in.
function ns.UpdateBars(shown)
    for _, bar in ipairs(bars or {}) do
        local on = shown and (bar.spec.always or ns.On(bar.spec.key)) and (not bar.spec.wanted or bar.spec.wanted())
        bar:SetShown(on)
        if on then bar.spec.fill(bar) end
    end
end

ns.Module({ key = "barCharacter", category = "window", order = 12, title = "BAR_CHARACTER", tip = "BAR_CHARACTER_TIP" })
local function Uses()
    return { { value = "both", label = L.BAR_USE_BOTH }, { value = "addon", label = L.BAR_USE_ADDON }, { value = "plan", label = L.BAR_USE_PLAN } }
end
ns.Module({
    key = "barSession", category = "window", order = 14, title = "BAR_SESSION", tip = "BAR_SESSION_TIP",
    settings = { { key = "barUse", label = "BAR_USE", default = "both", choices = Uses } },
})
