-- claude-in-wow module: while the conversation shows, a Shift+click on an item, a quest, a
-- spell... puts it in the question, as it does in the game's chat. The chat comes first,
-- when one is being written in. What the game does with the same click when no chat takes
-- it (splitting a stack, following a quest) is put back.
-- In the question sent, a link is its name and its number: "[Linen Cloth] (item:2589)".

local addonName, ns = ...

local C_Timer, gsub, match, tonumber = C_Timer, string.gsub, string.match, tonumber

local NUMBERED = { item = true, quest = true, spell = true, enchant = true, achievement = true, currency = true, talent = true }

-- A text with its links as words, for Claude.
function ns.PlainLinks(text)
    text = gsub(text, "|A.-|a", "")
    text = gsub(text, "|T.-|t", "")
    text = gsub(text, "|H(%a+):([^|]*)|h(.-)|h", function(kind, rest, name)
        local id = NUMBERED[kind] and match(rest, "^(%d+)")
        return id and name .. " (" .. kind .. ":" .. id .. ")" or name
    end)
    text = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = gsub(text, "|cn[^:|]*:", "")
    text = gsub(text, "|r", "")
    return text
end

local function ChatTakes()
    local active = ChatFrameUtil and ChatFrameUtil.GetActiveWindow or ChatEdit_GetActiveWindow
    return active and active() ~= nil
end

local function Linked(link)
    link = ns.Clean(link)
    if type(link) ~= "string" or not ns.On("linkClick") or not IsModifiedClick("CHATLINK") or ChatTakes() then return end
    if not ns.InsertInQuestion(link) then return end
    local quest = tonumber(match(link, "|Hquest:(%d+)"))
    local followed = quest and ns.Game.QuestWatched(quest)
    C_Timer.After(0, function()
        if StackSplitFrame and StackSplitFrame:IsShown() then StackSplitFrame:Hide() end
        if quest and ns.Game.QuestWatched(quest) ~= followed then
            if followed then ns.Game.WatchQuest(quest) else ns.Game.UnwatchQuest(quest) end
        end
    end)
end

if ChatFrameUtil and ChatFrameUtil.InsertLink then
    hooksecurefunc(ChatFrameUtil, "InsertLink", Linked)
elseif ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", Linked)
end

ns.Module({ key = "linkClick", category = "conversation", order = 70, title = "LINK_CLICK", tip = "LINK_CLICK_TIP" })
