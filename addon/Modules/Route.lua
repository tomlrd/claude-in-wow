-- claude-in-wow module: a way to follow, step by step, that Claude proposes under its
-- answer (Buttons.lua) and the player starts with a click:
--   [claude-in-wow] route Scholomance
--   1425:84.5:41.2 | Take the flight to Chillwind Camp | the flight master is by the inn
--   1422:69.7:73.2 | Enter Caer Darrow
-- Each line: a place ("map:x:y", a map alone, or "-"), what to do there, a word of advice.
-- It only shows: a pin of the game's at the step, a line over the screen as the raid
-- alerts are, a bar under the box. The next step comes as the player arrives (the game
-- says so, or where they stop), or at their click. Nothing moves, flies nor talks for
-- them. Stopping it puts back the pin there was; a /reload ends it.

local addonName, ns = ...

local abs, concat, format, gmatch, gsub, ipairs, match, max, pcall, strtrim, tonumber =
    math.abs, table.concat, string.format, string.gmatch, string.gsub, ipairs, string.match, math.max, pcall, strtrim, tonumber
local L = ns.L

local MOST = 12       -- steps
local NEAR = 1.5      -- percent of the zone's map: there

local route -- { key, name, steps, at, before (the pin there was), away (the steps the player was seen away from) }

local function Clean(text)
    return strtrim((gsub(text or "", "[|%c]", "")))
end

-- The steps of a route's lines: { { map, x, y, text, tip } }.
function ns.ParseRoute(body)
    local steps = {}
    for line in gmatch((body or "") .. "\n", "([^\n]*)\n") do
        local place, rest = match(line, "^%s*%-?%s*([%d:%.%-]+)%s*|%s*(.+)$")
        if place and #steps < MOST then
            local text, tip = match(rest, "^(.-)%s*|%s*(.*)$")
            local map, x, y = match(place, "^(%d+):([%d%.]+):([%d%.]+)$")
            map, x, y = tonumber(map or match(place, "^(%d+)$")), tonumber(x), tonumber(y)
            if map and not ns.MapName(map) then map, x, y = nil, nil, nil end -- not a map of this game
            text, tip = Clean(text or rest), Clean(tip)
            if text ~= "" then steps[#steps + 1] = { map = map, x = x, y = y, text = text, tip = tip ~= "" and tip or nil } end
        end
    end
    return steps
end

function ns.RouteActive()
    return route ~= nil
end

-- Whether the route being followed is this one.
function ns.RouteIs(key)
    return route ~= nil and route.key == key
end

local function Say(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ec9b0claude-in-wow|r " .. text)
end

local function Refresh()
    ns.RenderClaude()
    ns.RefreshBar("route")
end

-- Whether the player is at the step, by their place on its map.
local function There(step)
    if not step.map then return false end
    if not step.x then return ns.Clean(C_Map.GetBestMapForUnit("player")) == step.map end
    local ok, position = pcall(C_Map.GetPlayerMapPosition, step.map, "player")
    local x, y = nil, nil
    if ok and position then x, y = ns.Clean(position.x), ns.Clean(position.y) end
    return x and y and abs(x * 100 - step.x) < NEAR and abs(y * 100 - step.y) < NEAR or false
end

-- The step the player has come to: the one they are on, or one further on (a short cut,
-- a portal). One further on counts when they come to it from elsewhere, and a zone when
-- no step before is in it too: a way that comes back where it begins is not over at once.
local function Reached()
    local crossed, reached = {}, nil
    for index = route.at, #route.steps do
        local step = route.steps[index]
        local there = There(step)
        if index == route.at then
            if there then reached = index end
        elseif step.map and not there then
            route.away[index] = true
        elseif there and not reached and route.away[index] and (step.x or not crossed[step.map]) then
            reached = index
        end
        if step.map then crossed[step.map] = true end
    end
    return reached
end

-- Shows the step: its pin, its line over the screen.
local function Show()
    local step = route.steps[route.at]
    route.away = {}
    Reached() -- where they are away from, for now
    if step.x then
        ns.Game.Pin(step.map, step.x, step.y)
    else
        ns.Game.ClearPin()
    end
    local text = format(L.ROUTE_STEP, route.at, #route.steps, step.text)
    if ns.On("routeAlerts") then ns.Game.Alert(step.tip and text .. "\n" .. step.tip or text) end
    Say(step.tip and text .. " (" .. step.tip .. ")" or text)
    Refresh()
end

local function End()
    local before = route.before
    route = nil
    if before then ns.Game.Pin(before.map, before.x, before.y) else ns.Game.ClearPin() end
    Refresh()
end

-- Follows a route from its first step: true once begun.
function ns.StartRoute(key, name, steps)
    if #steps == 0 then return nil end
    if route then End() end
    route = { key = key, name = name, steps = steps, at = 1, before = ns.Game.CurrentPin() }
    ns.char.pinned = true -- a /reload takes ours away
    Show()
    return true
end

function ns.StopRoute()
    if not route then return end
    End()
    Say(L.ROUTE_STOPPED)
end

function ns.RouteMove(by)
    if not route then return end
    local at = route.at + by
    if at > #route.steps then
        local name = route.name
        End()
        local text = name ~= "" and format(L.ROUTE_DONE, name) or L.ROUTE_DONE_HERE
        if ns.On("routeAlerts") then ns.Game.Alert(text) end
        return Say(text)
    end
    route.at = max(1, at)
    Show()
end

-- What the bar says: the step, and all of it for its tooltip.
function ns.RouteLine()
    if not route then return nil end
    local step = route.steps[route.at]
    return format(L.ROUTE_STEP, route.at, #route.steps, step.text), step.tip
end

function ns.RouteMenu()
    local entries = {}
    if route.at > 1 then entries[#entries + 1] = { icon = "ArrowUp", label = L.ROUTE_BACK, run = function() ns.RouteMove(-1) end } end
    entries[#entries + 1] = { icon = "Check", label = route.at < #route.steps and L.ROUTE_NEXT or L.ROUTE_END, run = function() ns.RouteMove(1) end }
    entries[#entries + 1] = { icon = "Close", label = L.ROUTE_STOP, run = ns.StopRoute }
    return entries
end

-- The steps in lines, for the button's tooltip.
function ns.RouteText(steps)
    local lines = {}
    for index, step in ipairs(steps) do lines[index] = index .. ". " .. step.text end
    return concat(lines, "\n")
end

----------------------------------------------------------------------
-- Arriving
----------------------------------------------------------------------

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_STOPPED_MOVING", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "NAVIGATION_DESTINATION_REACHED", "PLAYER_LOGIN" }) do
    pcall(events.RegisterEvent, events, event) -- the game's own arrival is not in every version
end
events:SetScript("OnEvent", function(_, event, isWaypoint)
    if event == "PLAYER_LOGIN" then -- a pin of ours left by what was shown before
        if ns.char and ns.char.pinned then
            ns.char.pinned = nil
            ns.Game.ClearPin()
        end
        return
    end
    if not route or not ns.On("routeAuto") then return end
    local step = route.steps[route.at]
    if event == "NAVIGATION_DESTINATION_REACHED" then
        if step.x and not isWaypoint then ns.RouteMove(1) end -- a waypoint is a stage of the game's own way there
    else
        local reached = Reached()
        if reached then ns.RouteMove(reached - route.at + 1) end
    end
end)

ns.Module({
    key = "route", category = "conversation", order = 45, title = "ROUTE_MODULE", tip = "ROUTE_MODULE_TIP",
    changed = function(on) if not on then ns.StopRoute() end end,
    settings = {
        { key = "routeAuto", label = "ROUTE_AUTO", tip = "ROUTE_AUTO_TIP", default = true },
        { key = "routeAlerts", label = "ROUTE_ALERTS", default = true },
    },
})
