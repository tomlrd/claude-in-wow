-- claude-in-wow module: how much of the player's plan (Pro, Max) is used, as
-- Claude Code says it with each answer, in the answer's mark (the plugin's
-- clipboard.mjs): its window of a few hours and its weeks, all the plan's uses
-- together, and the game's part of them, estimated by the plugin (share.mjs).
--   ns.db.claudePlan = { at, windows = { { window ("5h", "7d", "7d-opus"), percent, resets,
--     own (the game's part, in hundredths of a percent of the plan) } } }
-- Without a plan (a key paid by use) nothing is said, and nothing shown.

local addonName, ns = ...

local date, floor, format, gmatch, gsub, ipairs, match, max, min, time, tonumber, upper =
    date, math.floor, string.format, string.gmatch, string.gsub, ipairs, string.match, math.max, math.min, time, tonumber, string.upper
local L, T = ns.L, ns.Theme

local TRACK = 8    -- a bar's height
local ROW = 50
local SEEN = 3     -- the least of a bar that shows
local OWN, REST = "accent", "plan"
local NEAR = 80    -- percent from which the figure stands out

-- What an answer's mark says of it: " p=5h:30:1795567200:12,7d:55:1795870800:40".
function ns.NotePlan(extra)
    local said = match(extra, " p=([%w%-:,]+)")
    if not said then return end
    local windows = {}
    for part in gmatch(said, "[^,]+") do
        local window, percent, resets, own = match(part, "^([%w%-]+):(%d+):(%d+):?(%d*)$")
        if window then windows[#windows + 1] = { window = window, percent = tonumber(percent), resets = tonumber(resets), own = tonumber(own) } end
    end
    if #windows > 0 then ns.db.claudePlan = { at = time(), windows = windows } end
end

local function Name(window)
    if window == "5h" then return L.PLAN_5H end
    local only = match(window, "^7d%-(%l+)$")
    return only and format(L.PLAN_7D_ONLY, upper(only:sub(1, 1)) .. only:sub(2)) or L.PLAN_7D
end

local function Duration(seconds)
    local minutes = max(1, floor(seconds / 60 + 0.5))
    return minutes < 60 and format(L.PLAN_MINUTES, minutes) or format(L.PLAN_HOURS, floor(minutes / 60), minutes % 60)
end

-- The plan's windows as they read: { { name, percent, own (nil once back to zero, own
-- when it is not known), note } }.
function ns.PlanLines()
    local lines, now = {}, time()
    for index, window in ipairs(ns.db.claudePlan and ns.db.claudePlan.windows or {}) do
        local left, note = window.resets - now, nil
        if left <= 0 then
            note = window.resets > 0 and format(L.PLAN_RESET, date(L.PLAN_TIME, window.resets)) or nil
        elseif left < 86400 then
            note = format(L.PLAN_RESETS, date(L.PLAN_TIME, window.resets), Duration(left))
        else
            note = format(L.PLAN_RESETS_DAY, date(L.PLAN_DATE, window.resets))
        end
        local counts = left > 0 or window.resets == 0
        lines[index] = { name = Name(window.window), percent = counts and window.percent or nil, own = counts and window.own or nil, note = note }
    end
    return lines
end

-- "0,05 %" of 5 hundredths; "12 %" of 1234: the decimals only while they say something.
local function Small(hundredths)
    local whole, decimals = floor(hundredths / 100), ""
    if hundredths < 1000 and hundredths % 100 > 0 then
        decimals = L.PLAN_DECIMAL .. gsub(format("%02d", hundredths % 100), "0$", "")
    elseif hundredths >= 1000 then
        whole = floor(hundredths / 100 + 0.5)
    end
    return format(L.PLAN_PERCENT_TEXT, whole .. decimals)
end

-- "31 %", and the game's part of it: "dont 0,05 % pour le jeu" (nil when not known).
function ns.PlanPercent(line)
    return line.percent and format(L.PLAN_PERCENT, line.percent) or "", line.own and format(L.PLAN_OWN, Small(line.own)) or nil
end

-- A window: its name and how much of it is used, its bar (the game's part, then the
-- rest), when it is back to zero.
local function Row(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW)
    row.name = T.Text(row, "sans", 12, "secondary")
    row.name:SetPoint("TOPLEFT")
    row.percent = T.Text(row, "sans", 12, "muted")
    row.percent:SetPoint("TOPRIGHT")
    local track = CreateFrame("Frame", nil, row)
    track:SetPoint("TOPLEFT", 0, -18)
    track:SetPoint("TOPRIGHT", 0, -18)
    track:SetHeight(TRACK)
    local back = T.Line(track, "field")
    back:SetAllPoints()
    row.own, row.rest = T.Line(track, OWN), T.Line(track, REST)
    row.own:SetPoint("TOPLEFT")
    row.own:SetPoint("BOTTOMLEFT")
    for _, fill in ipairs({ row.own, row.rest }) do fill:SetDrawLayer("ARTWORK", 1) end
    row.note = T.Text(row, "sans", 11, "muted")
    row.note:SetPoint("TOPLEFT", 0, -30)
    for _, text in ipairs({ row.name, row.percent, row.note }) do text:SetWordWrap(false) end
    function row:Fill(line, width)
        self.name:SetText(line.name)
        local percent, own = ns.PlanPercent(line)
        self.percent:SetText(T.Code((line.percent or 0) >= NEAR and "gold" or "text") .. percent .. "|r" .. (own and ", " .. own or ""))
        self.note:SetText(line.note or "")
        local used = floor(min(line.percent or 0, 100) / 100 * width + 0.5)
        local ours = (line.own or 0) > 0 and max(SEEN, floor(min(line.own / 100, 100) / 100 * width + 0.5)) or 0
        local others = (line.percent or 0) * 100 > (line.own or 0) and max(SEEN, used - ours) or 0
        self.own:SetShown(ours > 0)
        self.own:SetWidth(max(1, ours))
        self.rest:SetShown(others > 0)
        self.rest:SetPoint("TOPLEFT", ours, 0)
        self.rest:SetPoint("BOTTOMLEFT", ours, 0)
        self.rest:SetWidth(max(1, others))
    end
    return row
end

-- What a colour of the bars is.
local function Legend(parent, color, label)
    local square = T.Line(parent, color)
    square:SetSize(8, 8)
    local text = T.Text(parent, "sans", 11, "muted")
    text:SetPoint("LEFT", square, "RIGHT", 6, 0)
    text:SetText(label)
    return square, text
end

-- The plan, at the top of the settings' tab on the usage: its Refresh(width) tells
-- its height.
local function Section(parent)
    local frame, rows = CreateFrame("Frame", nil, parent), {}
    local at = T.Text(frame, "sans", 11, "muted")
    at:SetPoint("TOPLEFT")
    local unknown = T.Text(frame, "sans", 12, "muted")
    unknown:SetPoint("TOPLEFT")
    unknown:SetPoint("RIGHT")
    unknown:SetJustifyH("LEFT")
    unknown:SetText(L.PLAN_UNKNOWN)
    local legend = CreateFrame("Frame", nil, frame)
    legend:SetPoint("TOPLEFT", 0, -22)
    legend:SetPoint("TOPRIGHT", 0, -22)
    legend:SetHeight(16)
    legend:EnableMouse(true)
    legend:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.PLAN_OWN_TIP, 0.76, 0.75, 0.71, 1, true)
        GameTooltip:Show()
    end)
    legend:SetScript("OnLeave", GameTooltip_Hide)
    local ours, oursText = Legend(legend, OWN, L.PLAN_LEGEND_OWN)
    local rest = Legend(legend, REST, L.PLAN_LEGEND_REST)
    ours:SetPoint("LEFT")
    rest:SetPoint("LEFT", oursText, "RIGHT", 16, 0)
    function frame:Refresh(width)
        local lines, plan = ns.PlanLines(), ns.db.claudePlan
        local y = #lines > 0 and 24 or 0
        self:SetWidth(width)
        unknown:SetShown(#lines == 0)
        local parted = false
        for _, line in ipairs(lines) do parted = parted or line.own ~= nil end
        legend:SetShown(parted)
        if parted then y = y + 22 end
        at:SetText(plan and date(date("%x", plan.at) == date("%x") and L.PLAN_AT or L.PLAN_AT_DAY, plan.at) or "")
        for index, line in ipairs(lines) do
            rows[index] = rows[index] or Row(frame)
            rows[index]:SetPoint("TOPLEFT", 0, -y)
            rows[index]:SetPoint("TOPRIGHT", 0, -y)
            rows[index]:Fill(line, width)
            rows[index]:Show()
            y = y + ROW
        end
        for index = #lines + 1, #rows do rows[index]:Hide() end
        if #lines == 0 then y = y + max(16, unknown:GetStringHeight() or 0) end
        self:SetHeight(y)
        return y
    end
    return frame
end

ns.Module({ key = "plan", category = "usage", order = 5, fixed = true, title = "PLAN", tip = "PLAN_TIP", custom = Section })
ns.Module({ key = "planShare", category = "limits", limit = true, order = 25, title = "PLAN_SHARE", tip = "PLAN_SHARE_TIP" })
