-- claude-in-wow: the character, where it is, its group and professions.

local addonName, ns = ...

local Clean = ns.Clean
local floor, pairs, select = math.floor, pairs, select

local function Round(value)
    value = Clean(value)
    return value and floor(value * 1000 + 0.5) / 10 or nil -- map coordinates in %, one decimal
end

ns.AddCollector("character", function(char)
    local className, classFile = UnitClass("player")
    local guild, guildRank = GetGuildInfo("player")
    local _, surname = ns.Surname()
    local realm = GetRealmName()

    -- Current health is left out: Forever gave none (a secret value) while the
    -- maximum came through, and it says little out of combat anyway.
    char.character = {
        name = UnitName("player"),
        surname = surname,
        realm = realm ~= "" and realm or nil,
        level = UnitLevel("player"),
        class = className,
        classFile = classFile,
        race = UnitRace("player"),
        raceID = select(3, UnitRace("player")),
        faction = UnitFactionGroup("player"),
        guild = guild,
        guildRank = guildRank,
        money = GetMoney(), -- copper
        xp = Clean(UnitXP("player")),
        xpMax = Clean(UnitXPMax("player")),
        rested = Clean(GetXPExhaustion()),
        healthMax = Clean(UnitHealthMax("player")),
        dead = UnitIsDeadOrGhost("player") or nil,
    }
end)

ns.AddCollector("location", function(char)
    local mapID = C_Map.GetBestMapForUnit("player")
    local mapInfo = mapID and C_Map.GetMapInfo(mapID)
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local x, y
    if position then
        x, y = position:GetXY()
    end

    local location = {
        zone = GetRealZoneText(),
        subZone = GetSubZoneText(),
        mapID = mapID,
        map = mapInfo and mapInfo.name,
        x = Round(x),
        y = Round(y),
        resting = IsResting() or nil,
    }

    local inInstance, instanceType = IsInInstance()
    if inInstance then
        local name, _, _, difficultyName = GetInstanceInfo()
        location.instance = { name = name, type = instanceType, difficulty = difficultyName }
    end

    char.location = location
end)

ns.AddCollector("group", function(char)
    local count = GetNumGroupMembers()
    if count == 0 then
        char.group = nil
        return
    end

    local raid = IsInRaid()
    local members = {}
    for index = 1, raid and count or (count - 1) do
        local unit = (raid and "raid" or "party") .. index
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            members[#members + 1] = {
                name = UnitName(unit),
                level = UnitLevel(unit),
                class = UnitClass(unit),
                role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or nil,
                online = UnitIsConnected(unit) or nil,
            }
        end
    end

    char.group = { raid = raid or nil, members = members }
end)

-- Professions: the modern list when the game has it, else the skill lines.
ns.AddCollector("professions", function(char)
    local list = {}

    if GetProfessions and GetProfessionInfo then
        for _, index in pairs({ GetProfessions() }) do
            local name, _, rank, maxRank = GetProfessionInfo(index)
            if name then
                list[#list + 1] = { name = name, rank = rank, max = maxRank }
            end
        end
    end

    if #list == 0 and GetNumSkillLines and GetSkillLineInfo then
        for index = 1, GetNumSkillLines() do
            local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(index)
            if name and not isHeader then
                list[#list + 1] = { name = name, rank = rank, max = maxRank }
            end
        end
    end

    char.professions = list
end)
