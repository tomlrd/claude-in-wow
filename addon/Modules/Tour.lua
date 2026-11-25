-- claude-in-wow module: the guided tour of the window, the first time it opens (while
-- Claude has never answered), and again from the settings' tab "Help". A card goes from
-- one part of the window to the next, the rest darkened; it only shows, and is left at
-- any moment. Its texts are L.TOUR_TITLES and L.TOUR_TEXTS, a line a step.

local addonName, ns = ...

local ipairs, max, min = ipairs, math.max, math.min
local L, T = ns.L, ns.Theme

local SETUP = "/wow-mcp:setup"
local MARGIN, GAP = 14, 10

-- Each step: the part of the window it shows (ns.TourTargets), nil for none; copy: a text
-- to copy with a click.
local STEPS = {
    {},
    { copy = SETUP },
    { target = "input" },
    { target = "shortcuts" },
    { target = "model" },
    { target = "tabs" },
    {},
    { target = "gear" },
}

local tour, at

local function Dark(parent)
    local dark = parent:CreateTexture(nil, "BACKGROUND")
    dark:SetTexture("Interface\\Buttons\\WHITE8X8")
    dark:SetVertexColor(0, 0, 0, 0.6)
    return dark
end

local function Stop()
    ns.db.tourDone = true
    at = nil
    if tour then tour:Hide() end
end

local function Build(window)
    tour = CreateFrame("Frame", nil, window)
    tour:SetAllPoints()
    tour:SetFrameLevel(window:GetFrameLevel() + 60)
    tour:EnableMouse(true)
    tour:EnableMouseWheel(true)
    tour:SetScript("OnMouseWheel", function() end) -- what is under it stays
    tour.darks = { Dark(tour), Dark(tour), Dark(tour), Dark(tour) } -- around the part shown
    tour.ring = CreateFrame("Frame", nil, tour)
    T.Box(tour.ring, 10, "none", "clay")

    local card = CreateFrame("Frame", nil, tour)
    card:EnableMouse(true)
    card:SetFrameLevel(tour:GetFrameLevel() + 5)
    T.Box(card, 12, "chrome", "borderStrong")
    card.title = T.Text(card, "sansMedium", 16, "text")
    card.title:SetPoint("TOPLEFT", 16, -14)
    card.text = T.Text(card, "sans", 13, "secondary")
    card.count = T.Text(card, "sans", 11, "muted")
    card.copy = T.Chip(card, "Copy", "", function() ns.CopyText(STEPS[at].copy, L.COPY_TEXT) Stop() end)
    card.skip = T.Chip(card, "Close", L.TOUR_SKIP, Stop)
    card.back = T.Chip(card, "ArrowUp", L.TOUR_BACK, function() ns.StartTour(at - 1) end)
    card.back.icon:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1) -- to the left
    card.next = T.Chip(card, "Check", L.TOUR_NEXT, function()
        if at == #STEPS then return Stop() end
        ns.StartTour(at + 1)
    end, true)
    tour.card = card
    tour:SetScript("OnSizeChanged", function() if at then ns.StartTour(at) end end)
end

-- The part shown, from the window's bottom left: left, bottom, right, top; nil for none.
local function Rect(target)
    if not target or not target:IsVisible() then return nil end
    local left, bottom, right, top = target:GetLeft(), target:GetBottom(), target:GetRight(), target:GetTop()
    local x, y = tour:GetLeft(), tour:GetBottom()
    if not (left and bottom and right and top and x and y) then return nil end
    return left - x - 4, bottom - y - 4, right - x + 4, top - y + 4
end

local function Cover(texture, left, bottom, right, top)
    texture:ClearAllPoints()
    texture:SetPoint("BOTTOMLEFT", tour, "BOTTOMLEFT", left, bottom)
    texture:SetPoint("TOPRIGHT", tour, "BOTTOMLEFT", max(right, left), max(top, bottom))
end

local function Place(target)
    local width, height = tour:GetWidth() or 0, tour:GetHeight() or 0
    local left, bottom, right, top = Rect(target)
    if left then
        Cover(tour.darks[1], 0, top, width, height)
        Cover(tour.darks[2], 0, 0, width, bottom)
        Cover(tour.darks[3], 0, bottom, left, top)
        Cover(tour.darks[4], right, bottom, width, top)
    else
        Cover(tour.darks[1], 0, 0, width, height)
        for index = 2, 4 do Cover(tour.darks[index], 0, 0, 0, 0) end
    end
    tour.ring:SetShown(left ~= nil)
    if left then Cover(tour.ring, left, bottom, right, top) end

    -- the card, under the part or over it, in the middle without one
    local card = tour.card
    card:ClearAllPoints()
    if not left then
        card:SetPoint("CENTER")
    elseif (bottom + top) / 2 > height / 2 then
        card:SetPoint("TOP", tour, "BOTTOM", 0, bottom - GAP)
    else
        card:SetPoint("BOTTOM", tour, "BOTTOM", 0, top + GAP)
    end
end

-- The card's text and buttons, in as many lines as they need.
local function Fill(step)
    local card, width = tour.card, min(380, max(240, (tour:GetWidth() or 0) - 2 * MARGIN))
    local inner = width - 32
    card.title:SetWidth(inner)
    card.title:SetText(L.TOUR_TITLES[at] or "")
    local y = 14 + (card.title:GetStringHeight() or 16) + 8
    card.text:SetWidth(inner)
    card.text:SetText(L.TOUR_TEXTS[at] or "")
    card.text:ClearAllPoints()
    card.text:SetPoint("TOPLEFT", 16, -y)
    y = y + (card.text:GetStringHeight() or 13) + 12
    card.copy:SetShown(step.copy ~= nil)
    if step.copy then
        card.copy:SetLabel(L.HELP_COPY:format(step.copy))
        card.copy:ClearAllPoints()
        card.copy:SetPoint("TOPLEFT", 16, -y)
        y = y + 28 + 12
    end
    card.next:SetLabel(at == #STEPS and L.TOUR_END or L.TOUR_NEXT)
    card.back:SetShown(at > 1)
    card.skip:SetShown(at < #STEPS)
    card.count:SetText(at .. " / " .. #STEPS)
    card.count:ClearAllPoints()
    card.count:SetPoint("TOPRIGHT", -14, -16)
    local x = 16
    for _, chip in ipairs({ card.next, card.back, card.skip }) do -- on one line, or on two
        if chip:IsShown() then
            if x > 16 and x + chip:GetWidth() > width - 12 then x, y = 16, y + 34 end
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", x, -y)
            x = x + chip:GetWidth() + 8
        end
    end
    card:SetSize(width, y + 28 + 14)
end

-- The tour from a step, the first one when not said.
function ns.StartTour(step)
    local window, targets = ns.TourTargets()
    if not window then return end
    if not tour then Build(window) end
    at = max(1, min(step or 1, #STEPS))
    tour:Show()
    Fill(STEPS[at])
    Place(targets[STEPS[at].target or ""])
end

-- Whether it is for now: never seen, and nothing has ever answered.
function ns.TourDue()
    return not ns.db.tourDone and ns.NeverAnswered()
end

function ns.StopTour()
    if tour and at then Stop() end
end
