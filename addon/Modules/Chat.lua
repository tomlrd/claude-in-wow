-- claude-in-wow module: the recent chat. The last lines of the open channels
-- (guild, group, say, yell, emotes, general and the like) are noted as they
-- come, in memory only, and go with a question that speaks of the chat (a topic,
-- Topics.lua). Never whispers, Battle.net nor the officers' channel: they are
-- not even listened to.

local addonName, ns = ...

local date, gsub, ipairs, pairs, pcall, strtrim, time, tremove, type =
    date, string.gsub, ipairs, pairs, pcall, strtrim, time, table.remove, type
local L = ns.L

local MAX_LINES = 120 -- noted
local SENT = 60       -- in a question
local MAX_TEXT = 255  -- characters of a line

-- The events listened to, and how each channel is called.
local CHANNELS = {
    CHAT_MSG_GUILD = "guild", CHAT_MSG_PARTY = "party", CHAT_MSG_PARTY_LEADER = "party", CHAT_MSG_RAID = "raid", CHAT_MSG_RAID_LEADER = "raid",
    CHAT_MSG_INSTANCE_CHAT = "instance", CHAT_MSG_INSTANCE_CHAT_LEADER = "instance", CHAT_MSG_SAY = "say", CHAT_MSG_YELL = "yell",
    CHAT_MSG_EMOTE = "emote", CHAT_MSG_TEXT_EMOTE = "emote", CHAT_MSG_CHANNEL = "channel",
}

local lines = {} -- { at, where, who, said }, the last one last

-- A line's text: the game's links as what they show.
local function Said(text)
    text = ns.Clean(text)
    if type(text) ~= "string" then return nil end
    text = strtrim(ns.StripCodes((gsub(gsub(text, "|K.-|k", "?"), "|H.-|h(.-)|h", "%1"))))
    return text ~= "" and text:sub(1, MAX_TEXT) or nil
end

local events = CreateFrame("Frame")

local function Listen(on)
    for event in pairs(CHANNELS) do
        if on then pcall(events.RegisterEvent, events, event) else events:UnregisterEvent(event) end
    end
    if not on then lines = {} end
end

events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, text, who, _, _, _, _, _, _, channel)
    if event == "PLAYER_LOGIN" then return Listen(ns.On("chat")) end
    if not ns.On("chat") then return end
    local where, said = CHANNELS[event], Said(text)
    if not where or not said then return end
    if where == "channel" then where = ns.Clean(channel) or where end
    lines[#lines + 1] = { at = time(), where = where, who = ns.Clean(who), said = said }
    if #lines > MAX_LINES then tremove(lines, 1) end
end)

ns.Topic("chat", {
    module = "chat",
    words = { "chat", "tchat", "canal", "canaux", "channel", "channels" },
    read = function()
        local list = {}
        for index = #lines, 1, -1 do
            if #list >= SENT then break end
            local line = lines[index]
            table.insert(list, 1, { at = date("%H:%M", line.at), where = line.where, who = line.who, said = line.said })
        end
        return { lines = list, note = "the open channels since the last login or /reload; no whispers" }
    end,
})

ns.Module({ key = "chat", category = "limits", limit = true, order = 40, title = "CHAT_MODULE", tip = "CHAT_MODULE_TIP", changed = Listen })
