-- claude-in-wow module: the players. Each player the game knows (guild,
-- friends, group, oneself) named in one of Claude's answers is drawn in their
-- class's colour, with their level; hovering tells who they are and where, a
-- click offers what can be done with them. Read only from what the game already
-- has; nothing is asked of its servers.

local addonName, ns = ...

local format, ipairs, match, pairs, pcall, sort, sub, tostring =
    string.format, ipairs, string.match, pairs, pcall, table.sort, string.sub, tostring
local find = string.find
local L, T = ns.L, ns.Theme

ns.Module({
    key = "players", category = "conversation", order = 20, title = "PLAYERS", tip = "PLAYERS_TIP",
    settings = {
        { key = "playersClass", label = "PLAYERS_CLASS", tip = "PLAYERS_CLASS_TIP", default = true },
        { key = "playersLevel", label = "PLAYERS_LEVEL", tip = "PLAYERS_LEVEL_TIP", default = true },
    },
})

----------------------------------------------------------------------
-- The players the game knows
----------------------------------------------------------------------

local players -- name -> { name, level, class (localized), file (of the class), zone, rank, note, online, me }
local names

local function Try(fn, ...)
    if not fn then return nil end
    local ok, first, second = pcall(fn, ...)
    if ok then return first, second end
end

local function Class(id)
    local info = id and Try(C_CreatureInfo and C_CreatureInfo.GetClassInfo, id)
    if info then return info.className, info.classFile end
end

local function Add(player)
    player.name = ns.Clean(player.name)
    if not player.name or #player.name < 3 or find(player.name, "|", 1, true) then return end
    local known = players[player.name]
    if not known then
        players[player.name] = player
        return
    end
    for key, value in pairs(player) do
        if known[key] == nil then known[key] = value end
    end
end

-- The class of a localized name ("Prêtresse" as "Prêtre").
local files
local function FileOf(name)
    if not files then
        files = {}
        for _, list in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
            for file, localized in pairs(list) do files[localized] = file end
        end
    end
    return name and files[name]
end

local function Build()
    players, names = {}, {}
    for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
        local name, surname = Try(UnitName, unit)
        if unit == "player" and ns.Surname() then name, surname = ns.Surname() end
        if ns.Clean(name) then
            local class, file = Try(UnitClass, unit)
            Add({ name = ns.Clean(surname) and surname ~= "" and name .. " " .. surname or name, level = ns.Clean(Try(UnitLevel, unit)), class = class, file = file,
                online = true, me = unit == "player" or nil })
        end
    end
    local club = Try(C_Club and C_Club.GetGuildClubId)
    for _, id in ipairs(club and Try(C_Club.GetClubMembers, club) or {}) do
        local info = Try(C_Club.GetMemberInfo, club, id)
        if info then
            local class, file = Class(info.classID)
            local online = info.presence == 1 or info.presence == 2 or info.presence == 4 or info.presence == 5 -- Enum.ClubMemberPresence
            Add({ name = info.name, level = info.level, class = class, file = file, zone = online and info.zone or nil, rank = info.guildRank,
                note = info.memberNote ~= "" and info.memberNote or nil, online = online, me = info.isSelf or nil })
        end
    end
    for index = 1, Try(C_FriendList and C_FriendList.GetNumFriends) or 0 do
        local info = Try(C_FriendList.GetFriendInfoByIndex, index)
        if info then
            Add({ name = info.name, level = info.connected and info.level or nil, class = info.className, file = FileOf(info.className),
                zone = info.connected and info.area or nil, online = info.connected })
        end
    end
    for name in pairs(players) do names[#names + 1] = name end
    sort(names, function(a, b) return #a > #b or #a == #b and a < b end)
end

-- The player of a name, nil when the game does not know them.
function ns.FindPlayer(name)
    if not players then Build() end
    return players[name]
end

-- Read again at the next answer once something changed.
local events = CreateFrame("Frame")
for _, event in ipairs({ "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "GROUP_ROSTER_UPDATE", "CLUB_MEMBER_UPDATED", "INITIAL_CLUBS_LOADED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function() players = nil end)

----------------------------------------------------------------------
-- In an answer
----------------------------------------------------------------------

local function Color(player)
    local color = ns.On("playersClass") and player.file and C_ClassColor and Try(C_ClassColor.GetClassColor, player.file)
    return color and color.r and format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255) or T.Code("white")
end

-- Whether the text right after a name already gives the level.
local function Given(level, after)
    return find(" " .. sub(after, 1, 28) .. " ", "%f[%d]" .. tostring(level) .. "%f[%D]") ~= nil
end

local function Link(player, label, after)
    local level = ns.On("playersLevel") and player.level and player.level > 0 and not Given(player.level, after) and not player.me
    return format("%s|Hciwplayer:%s|h%s|h|r%s", Color(player), player.name, label,
        level and format(" %s%d|r", T.Code("muted"), player.level) or "")
end

ns.Decorate("players", function(text, keep, answer)
    if not players then Build() end
    text = ns.DrawNames(text, names, function(name, after, written) return keep(Link(players[name], written, after)) end)
    -- a first name alone, once the whole name is somewhere in the answer
    for _, name in ipairs(names) do
        local first = match(name, "^(%S+)%s")
        if first and #first >= 4 and find(answer or "", name, 1, true) then
            text = ns.DrawNames(text, { first }, function(_, after, written) return keep(Link(players[name], written, after)) end)
        end
    end
    return text
end)

ns.LinkKind("player", {
    enter = function(tooltip, rest)
        local player = ns.FindPlayer(rest)
        if not player then return tooltip:SetText(rest) end
        tooltip:SetText(Color(player) .. player.name .. "|r")
        if player.level or player.class then tooltip:AddLine(format(L.PLAYERS_LEVEL_CLASS, player.level or "?", player.class or ""), 1, 1, 1) end
        if player.rank then tooltip:AddLine(player.rank, 0.25, 1, 0.25) end
        if player.zone then tooltip:AddLine(player.zone, 1, 0.82, 0) elseif player.online == false then tooltip:AddLine(L.PLAYERS_OFFLINE, 0.6, 0.6, 0.6) end
        if player.note then tooltip:AddLine(ns.StripCodes(player.note), 0.76, 0.75, 0.71, true) end
        if not player.me then tooltip:AddLine(L.PLAYERS_CLICK, 0.6, 0.6, 0.6, true) end
    end,
    click = function(rest)
        local player = ns.FindPlayer(rest) or { name = rest }
        if player.me then return end
        local entries = {
            { icon = "ArrowUp", label = L.PLAYERS_WHISPER, run = function() ns.Tell(player.name, "") end },
            { icon = "Plus", label = L.PLAYERS_INVITE, run = function() C_PartyInfo.InviteUnit(player.name) end },
            { icon = "MapPin", label = L.PLAYERS_WHO, run = function() C_FriendList.SendWho(player.name) end },
        }
        local place = player.zone and ns.FindPlace(player.zone)
        if place then
            entries[#entries + 1] = { icon = "MapPin", label = format(L.PLAYERS_ZONE, player.zone), run = function() ns.ShowOnMap(place.map) end }
        end
        ns.MenuAtCursor(entries)
    end,
})
