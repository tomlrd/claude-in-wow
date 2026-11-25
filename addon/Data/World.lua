-- claude-in-wow: the server and the layer the character is on.
-- The server: the realm's name; where there are no realms (Forever), the region
-- and the kind of server, which the game does not tell addons: it shows in a
-- contested zone, where a PVP server flags you by itself and a normal one does not.
-- The layer: the game does not name it either, but a creature's id says it,
-- "Creature-0-<server>-<instance>-<layer>-<creature>-<spawn>": read on each
-- creature under the mouse or targeted, outside instances, and forgotten where it
-- may have changed, another zone, or the game moving the character.
--   ns.char.world = { layer (kept for a reload), kind ("NORMAL", "PVP", "HARDCORE") }

local addonName, ns = ...

local format, ipairs, match, pcall, tonumber = string.format, ipairs, string.match, pcall, tonumber
local Clean, L = ns.Clean, ns.L

local REGIONS = { "US", "KR", "EU", "TW", "CN" }
local SETTLED = 10 -- seconds in a zone before its flag is sure

local function Ask(fn, ...)
    if not fn then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return Clean(value) end
end

local enteredAt = 0

local function Kind()
    if Ask(C_GameRules and C_GameRules.IsHardcoreActive) then return "HARDCORE" end
    if GetTime() - enteredAt < SETTLED or Ask(UnitIsDeadOrGhost, "player") or Ask(UnitOnTaxi, "player") then return nil end
    if Ask(C_PvP and C_PvP.GetZonePVPInfo or GetZonePVPInfo) ~= "contested" then return nil end
    local flagged = Ask(UnitIsPVP, "player")
    if flagged == false then return "NORMAL" end
    if flagged and Ask(GetPVPDesired) == false and Ask(IsPVPTimerRunning) == false then return "PVP" end
end

-- The server's name, nil when nothing says it.
local function Server(kind)
    local realm = Ask(GetRealmName)
    if realm and realm ~= "" then return realm end
    local region = Ask(GetCurrentRegionName) or REGIONS[Ask(GetCurrentRegion) or 0]
    if not region or region == "" then return nil end
    return kind and format(L.WORLD_SERVER_KIND, region, L["WORLD_" .. kind]) or format(L.WORLD_SERVER, region)
end

-- The server's name; the layer's number, nil while unknown; whether the character is
-- where there are layers.
function ns.World()
    local seen, outside = ns.char and ns.char.world or {}, not Ask(IsInInstance)
    return Server(seen.kind), outside and seen.layer or nil, outside
end

local function Note(layer, kind)
    local seen = ns.char and ns.char.world or {}
    kind = kind or seen.kind
    if not ns.char or seen.layer == layer and seen.kind == kind then return end
    ns.char.world = { layer = layer, kind = kind }
    ns.RefreshBar("barCharacter")
end

local function Read(unit)
    if not Ask(UnitExists, unit) or Ask(UnitPlayerControlled, unit) or Ask(IsInInstance) then return end -- a pet keeps the layer it was called on
    local made, layer = match(Ask(UnitGUID, unit) or "", "^(%a+)%-%d+%-%d+%-%d+%-(%d+)%-")
    if made == "Creature" or made == "Vehicle" then Note(tonumber(layer), Kind()) end
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "SHARD_TRANSFER" }) do
    pcall(frame.RegisterEvent, frame, event) -- the last one is not in every version
end
frame:SetScript("OnEvent", function(_, event, _, reloaded)
    if event == "UPDATE_MOUSEOVER_UNIT" then
        Read("mouseover")
    elseif event == "PLAYER_TARGET_CHANGED" then
        Read("target")
    else
        enteredAt = GetTime()
        if event ~= "PLAYER_ENTERING_WORLD" or not reloaded then Note(nil) end
    end
end)
