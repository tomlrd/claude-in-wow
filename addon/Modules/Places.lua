-- claude-in-wow module: the places. Each place of the game named in one of
-- Claude's answers is drawn as the game does, in gold with a pin, and a click
-- opens the map on it: continents, zones and cities (the map itself), dungeons
-- and raids (the map of their zone, with their entrance once you went in), and
-- the towns flight masters know (a pin there). The names are the game's own, in
-- the client's language; the English and French ones of the zones and the
-- dungeons are known too.
-- They are saved (ns.db.places) for Claude to write them as the game does.

local addonName, ns = ...

local find, floor, format, gsub, ipairs, lower, match, next, pairs, pcall, select, sort, sub, tonumber =
    string.find, math.floor, string.format, string.gsub, ipairs, string.lower, string.match, next, pairs, pcall, select, table.sort, string.sub, tonumber
local byte = string.byte
local L, T = ns.L, ns.Theme

ns.Module({
    key = "places", category = "conversation", order = 10, title = "PLACES", tip = "PLACES_TIP",
    settings = {
        { key = "placesIcon", label = "PLACES_ICON", tip = "PLACES_ICON_TIP", default = true },
        { key = "placesPin", label = "PLACES_PIN", tip = "PLACES_PIN_TIP", default = true },
    },
})

----------------------------------------------------------------------
-- The places the game knows
----------------------------------------------------------------------

local CONTINENT, ZONE, DUNGEON = 2, 3, 4 -- Enum.UIMapType
local AZEROTH = 947
local MIN_LENGTH = 4
local ARTICLES = { "^Les ", "^Le ", "^La ", "^L'", "^The " }

-- The old world's dungeons and raids (the other versions list theirs themselves):
-- the game's number of each (GetRealZoneText gives
-- its name), the map of the zone it is in, its English and French names.
local DUNGEONS = {
    { 389, 1454, "Ragefire Chasm", "Gouffre de Ragefeu" },
    { 43, 1413, "Wailing Caverns", "Cavernes des lamentations" },
    { 36, 1436, "The Deadmines", "Les Mortemines" },
    { 33, 1421, "Shadowfang Keep", "Donjon d'Ombrecroc" },
    { 48, 1440, "Blackfathom Deeps", "Profondeurs de Brassenoire" },
    { 34, 1453, "The Stockade", "La Prison" },
    { 90, 1426, "Gnomeregan", "Gnomeregan" },
    { 47, 1413, "Razorfen Kraul", "Kraal de Tranchebauge" },
    { 189, 1420, "Scarlet Monastery", "Monastère écarlate" },
    { 129, 1413, "Razorfen Downs", "Souilles de Tranchebauge" },
    { 70, 1418, "Uldaman", "Uldaman" },
    { 209, 1446, "Zul'Farrak", "Zul'Farrak" },
    { 349, 1443, "Maraudon", "Maraudon" },
    { 109, 1435, "Sunken Temple", "Le temple d'Atal'Hakkar" },
    { 230, 1427, "Blackrock Depths", "Profondeurs de Blackrock" },
    { 229, 1428, "Blackrock Spire", "Pic Blackrock" },
    { 289, 1422, "Scholomance", "Scholomance" },
    { 329, 1423, "Stratholme", "Stratholme" },
    { 429, 1444, "Dire Maul", "Hache-tripes" },
    { 409, 1428, "Molten Core", "Cœur du Magma" },
    { 249, 1445, "Onyxia's Lair", "Repaire d'Onyxia" },
    { 469, 1428, "Blackwing Lair", "Repaire de l'Aile noire" },
    { 309, 1434, "Zul'Gurub", "Zul'Gurub" },
    { 509, 1451, "Ruins of Ahn'Qiraj", "Ruines d'Ahn'Qiraj" },
    { 531, 1451, "Temple of Ahn'Qiraj", "Temple d'Ahn'Qiraj" },
    { 533, 1423, "Naxxramas", "Naxxramas" },
}

-- The zones' English names, from map 1411 on.
local ENGLISH = {
    "Durotar", "Mulgore", "The Barrens", "Kalimdor", "Eastern Kingdoms", "Alterac Mountains", "Arathi Highlands", "Badlands", "Blasted Lands",
    "Tirisfal Glades", "Silverpine Forest", "Western Plaguelands", "Eastern Plaguelands", "Hillsbrad Foothills", "The Hinterlands", "Dun Morogh",
    "Searing Gorge", "Burning Steppes", "Elwynn Forest", "Deadwind Pass", "Duskwood", "Loch Modan", "Redridge Mountains", "Stranglethorn Vale",
    "Swamp of Sorrows", "Westfall", "Wetlands", "Teldrassil", "Darkshore", "Ashenvale", "Thousand Needles", "Stonetalon Mountains", "Desolace",
    "Feralas", "Dustwallow Marsh", "Tanaris", "Azshara", "Felwood", "Un'Goro Crater", "Moonglade", "Silithus", "Winterspring", "Stormwind City",
    "Orgrimmar", "Ironforge", "Thunder Bluff", "Darnassus", "Undercity",
}
-- Their French ones: a French Forever keeps some in English.
local FRENCH = {
    "Durotar", "Mulgore", "Les Tarides", "Kalimdor", "Royaumes de l'est", "Montagnes d'Alterac", "Hautes-terres d'Arathi", "Terres ingrates", "Terres foudroyées",
    "Clairières de Tirisfal", "Forêt des Pins argentés", "Maleterres de l'ouest", "Maleterres de l'est", "Contreforts d'Hillsbrad", "Les Hinterlands", "Dun Morogh",
    "Gorge des Vents brûlants", "Steppes ardentes", "Forêt d'Elwynn", "Défilé de Deuillevent", "Bois de la Pénombre", "Loch Modan", "Les Carmines", "Vallée de Strangleronce",
    "Marais des Chagrins", "Marche de l'Ouest", "Les Paluns", "Teldrassil", "Sombrivage", "Orneval", "Mille pointes", "Les Serres-Rocheuses", "Désolace",
    "Féralas", "Marécage d'Âprefange", "Tanaris", "Azshara", "Gangrebois", "Cratère d'Un'Goro", "Reflet-de-Lune", "Silithus", "Berceau-de-l'Hiver", "Hurlevent",
    "Orgrimmar", "Forgefer", "Les Pitons-du-Tonnerre", "Darnassus", "Fossoyeuse",
}
local FIRST_NAMED = 1411

local places -- name -> { name, map, x, y }
local names  -- the names, the longest first

local function Try(fn, ...)
    if not fn then return nil end
    local ok, result = pcall(fn, ...)
    return ok and result or nil
end

local function Add(name, kind, map, x, y, shown)
    name = ns.Clean(name)
    if not name or #name < MIN_LENGTH or find(name, "^zz") then return end -- "zzOLD...": the game's leftovers
    local called = name
    name = gsub(name, "’", "'") -- as the names of an answer are read
    shown = shown and gsub(shown, "’", "'")
    local place = places[name] or shown and places[shown] or { name = shown or called, kind = kind, map = map, x = x, y = y }
    places[name] = place
    for _, article in ipairs(ARTICLES) do -- "Les Hinterlands", "dans les Hinterlands"
        local short, cut = gsub(name, article, "", 1)
        if cut > 0 and #short >= MIN_LENGTH and not places[short] then places[short] = place end
    end
end

-- The map above all others, from the player's; Azeroth's in an instance.
local function World()
    local map, top, kind = Try(C_Map.GetBestMapForUnit, "player"), nil, nil
    for _ = 1, 10 do
        local info = map and map > 0 and Try(C_Map.GetMapInfo, map)
        if not info then break end
        top, map, kind = map, info.parentMapID, info.mapType
    end
    if not kind or kind >= CONTINENT then return Try(C_Map.GetMapInfo, AZEROTH) and AZEROTH or top end
    return top
end

-- A position the game gives, in percent.
local function Percent(position)
    if not position then return nil end
    local x, y = position.x, position.y
    if position.GetXY then x, y = position:GetXY() end
    if not x or not y then return nil end
    return x * 100, y * 100
end

-- The towns flight masters know on a continent. A zone's own list holds all the
-- continent's: each one's zone is the one under its point on the continent's map,
-- and its point there is in that zone's list.
local function AddTowns(continent)
    local lists = {} -- zone -> node number -> its point there
    local function PointIn(zone, id)
        if not lists[zone] then
            lists[zone] = {}
            for _, node in ipairs(Try(C_TaxiMap.GetTaxiNodesForMap, zone) or {}) do lists[zone][node.nodeID or 0] = node.position end
        end
        local x, y = Percent(lists[zone][id])
        if x and x > 0 and x < 100 and y > 0 and y < 100 then return x, y end
    end
    for _, node in ipairs(Try(C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap, continent) or {}) do
        local x, y = Percent(node.position)
        local zone = x and Try(C_Map.GetMapInfoAtPosition, continent, x / 100, y / 100)
        if zone and zone.mapType == ZONE then
            Add(node.name and match(node.name, "^([^,]+)"), "town", zone.mapID, PointIn(zone.mapID, node.nodeID or 0))
        end
    end
end

-- The dungeons: the entrance is where you were before you went in (below), else
-- the map of the zone alone. Those the list lacks are known once you went in.
local function AddDungeons()
    local entrances = ns.db.entrances or {}
    -- a client that takes no number gives the zone you are in for each
    local named = Try(GetRealZoneText, DUNGEONS[1][1]) ~= Try(GetRealZoneText, DUNGEONS[2][1])
    for _, dungeon in ipairs(ns.Game.oldWorld and DUNGEONS or {}) do
        local id, map, english, french = dungeon[1], dungeon[2], dungeon[3], dungeon[4]
        local entrance = entrances[id]
        local name = named and ns.Clean(Try(GetRealZoneText, id))
        if not name or name == "" then name = GetLocale() == "frFR" and french or english end
        local x, y
        if entrance then map, x, y = entrance.map, entrance.x, entrance.y end
        for _, known in ipairs({ name, french, english }) do Add(known, "dungeon", map, x, y, name) end
    end
    for _, entrance in pairs(entrances) do Add(entrance.name, "dungeon", entrance.map, entrance.x, entrance.y) end
end

-- What the plugin reads: each place once, by its whole name.
local function Save()
    local list, seen = {}, {}
    for _, name in ipairs(names) do
        local place = places[name]
        if not seen[place.name] then
            seen[place.name] = true
            list[#list + 1] = { name = place.name, map = place.map, kind = place.kind }
        end
    end
    sort(list, function(a, b) return a.map < b.map or a.map == b.map and a.name < b.name end)
    ns.db.places = list
end

local function Build()
    local world = World()
    if not world then return end -- in an instance: at the next answer
    places, names = {}, {}
    local maps = Try(C_Map.GetMapChildrenInfo, world, nil, true) or {}
    for _, info in ipairs(maps) do
        if info.mapType == CONTINENT or info.mapType == ZONE then Add(info.name, info.mapType == ZONE and "zone" or "continent", info.mapID) end
    end
    for _, info in ipairs(maps) do
        if info.mapType == ZONE then
            for _, entrance in ipairs(Try(C_EncounterJournal and C_EncounterJournal.GetDungeonEntrancesForMap, info.mapID) or {}) do
                Add(entrance.name, "dungeon", info.mapID, Percent(entrance.position))
            end
        elseif info.mapType == CONTINENT then
            AddTowns(info.mapID)
        end
    end
    for _, info in ipairs(maps) do
        if info.mapType == DUNGEON then Add(info.name, "dungeon", info.mapID) end
    end
    if not next(places) then -- the game had none to tell yet: at the next answer
        places = nil
        return
    end
    AddDungeons()
    for index, english in ipairs(ns.Game.oldWorld and ENGLISH or {}) do
        local info = Try(C_Map.GetMapInfo, FIRST_NAMED + index - 1)
        if info and places[info.name] then
            for _, name in ipairs({ english, FRENCH[index] }) do Add(name, "zone", info.mapID, nil, nil, info.name) end
        end
    end
    for name in pairs(places) do names[#names + 1] = name end
    sort(names, function(a, b) return #a > #b or #a == #b and a < b end)
    Save()
end

-- The place of a name ({ name, map, x, y }), nil when it is none.
function ns.FindPlace(name)
    if not places then Build() end
    return places and name and places[name]
end

----------------------------------------------------------------------
-- The entrances: where you were outside when you go into a dungeon on foot
----------------------------------------------------------------------

local outside -- { map, x, y }, at the last loading screen outside

local function ZoneOf(id)
    for _, dungeon in ipairs(DUNGEONS) do
        if dungeon[1] == id then return dungeon[2] end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LEAVING_WORLD")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LEAVING_WORLD" then
        outside = nil
        local map = not IsInInstance() and Try(C_Map.GetBestMapForUnit, "player")
        local x, y = Percent(map and Try(C_Map.GetPlayerMapPosition, map, "player"))
        if x and x > 0 then outside = { map = map, x = x, y = y } end
        return
    end
    local inside, kind = IsInInstance()
    if not inside then
        if not places and ns.db then Build() end
        return
    end
    if not outside or kind ~= "party" and kind ~= "raid" then return end
    -- brought in by the group finder: not the entrance
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return end
    local name, id = ns.Clean((GetInstanceInfo())), select(8, GetInstanceInfo())
    local zone = id and ZoneOf(id)
    if not name or not id or zone and zone ~= outside.map then return end
    ns.db.entrances = ns.db.entrances or {}
    ns.db.entrances[id] = { name = name, map = outside.map, x = floor(outside.x * 10 + 0.5) / 10, y = floor(outside.y * 10 + 0.5) / 10 }
    places = nil -- with it, at the next answer
end)

----------------------------------------------------------------------
-- In an answer
----------------------------------------------------------------------

-- Whether what is around a name in a text is not part of a word (accented
-- letters are bytes over 127).
local function Alone(text, first, last)
    local before, after = byte(text, first - 1), byte(text, last + 1)
    local function Letter(code) return code and (code > 127 or match(string.char(code), "%w")) end
    return not Letter(first > 1 and before or nil) and not Letter(after)
end

-- A text with each name of a list drawn by make(name, after, written), the first
-- names first. Capitals may differ ("de l'Ouest"), but a name's first letter.
function ns.DrawNames(text, list, make)
    local low = lower(text)
    for _, name in ipairs(list) do
        local from = 1
        while true do
            local first, last = find(low, lower(name), from, true)
            if not first then break end
            if byte(text, first) == byte(name, 1) and Alone(text, first, last) then
                local drawn = make(name, sub(text, last + 1), sub(text, first, last))
                if not drawn then
                    from = last + 1
                else
                    text = sub(text, 1, first - 1) .. drawn .. sub(text, last + 1)
                    low = lower(text)
                    from = first + #drawn
                end
            else
                from = last + 1
            end
        end
    end
    return text
end

local function Link(place, label)
    return format("%s|Hciwplace:%d:%s:%s:%s|h%s%s|h|r", T.Code("gold"), place.map, place.x and format("%.1f", place.x) or "",
        place.y and format("%.1f", place.y) or "", place.name, ns.On("placesIcon") and ns.PinIcon() or "", label)
end

ns.Decorate("places", function(text, keep)
    if not places then Build() end
    if not places then return text end
    return ns.DrawNames(text, names, function(name, _, written) return keep(Link(places[name], written)) end)
end)

-- Claude's own link to a zone, for a place the game does not list: drawn the same.
function ns.ZoneLink(map, label)
    if not ns.On("places") then return nil end
    local place = ns.FindPlace(label)
    if place and place.map ~= map then place = nil end
    return Link(place or { name = label, map = map }, label)
end

local function Parts(rest)
    local map, x, y, name = match(rest, "^(%d+):([%d%.]*):([%d%.]*):(.*)$")
    return tonumber(map), tonumber(x), tonumber(y), name
end

ns.LinkKind("place", {
    enter = function(tooltip, rest)
        local map, x, y, name = Parts(rest)
        tooltip:SetText(name, 1, 0.82, 0)
        local zone = ns.MapName(map)
        if zone and zone ~= name then tooltip:AddLine(x and format("%s  %.1f, %.1f", zone, x, y) or zone, 1, 1, 1) end
        tooltip:AddLine(L.PLACES_CLICK, 0.6, 0.6, 0.6, true)
    end,
    click = function(rest)
        local map, x, y = Parts(rest)
        if not ns.On("placesPin") then x, y = nil, nil end
        ns.ShowOnMap(map, x, y)
    end,
})
