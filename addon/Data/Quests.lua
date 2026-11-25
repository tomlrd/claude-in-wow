-- claude-in-wow: the quest log, with each quest's zone header and objectives.
-- Quests under a header folded in the log may be left out if the game lists
-- only the log's open lines: questsNotListed, from the game's own count, tells.

local addonName, ns = ...

local Game, StripCodes = ns.Game, ns.StripCodes
local concat, ipairs, sort = table.concat, ipairs, table.sort

local function Objectives(questID)
    local list = {}
    for _, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        list[#list + 1] = {
            text = StripCodes(objective.text),
            done = objective.finished or nil,
            have = objective.numFulfilled,
            need = objective.numRequired,
            type = objective.type,
        }
    end
    return list
end

local function Tag(questID)
    return Game.QuestTag(questID)
end

-- The quests handed in, by number: the game's own list, at a reload or a logout
-- only (long, so never in a photo). The game no longer gives it as you leave: it is
-- read when you enter, and each quest handed in is added.
local done

local function ReadDone()
    local ids = Game.QuestsHandedIn()
    if ids and #ids > 0 then done = ids end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("QUEST_TURNED_IN")
events:SetScript("OnEvent", function(_, event, questID)
    if event == "QUEST_TURNED_IN" and done then
        done[#done + 1] = questID
    else
        ReadDone()
    end
end)

ns.AddCollector("questsDone", function(char)
    if not done then ReadDone() end
    if not done then return end
    sort(done)
    char.questsDone = concat(done, " ")
end)

ns.AddCollector("quests", function(char)
    local quests, header, seen = {}, nil, 0
    local entries, questsInLog = Game.QuestLines()

    for index = 1, entries do
        local info = Game.QuestLine(index)
        if info then
            if info.isHeader then
                header = info.title
            else
                seen = seen + 1
                if not info.isHidden then
                    local questID = info.questID
                    quests[#quests + 1] = {
                        id = questID,
                        title = StripCodes(info.title),
                        level = info.level,
                        zone = header,
                        group = (info.suggestedGroup or 0) > 0 and info.suggestedGroup or nil,
                        tag = Tag(questID),
                        complete = Game.QuestComplete(questID) or nil,
                        ready = Game.QuestReady(questID) or nil,
                        failed = Game.QuestFailed(questID) or nil,
                        objectives = Objectives(questID),
                    }
                end
            end
        end
    end

    char.quests = quests
    local notListed = (questsInLog or 0) - seen
    char.questsNotListed = notListed > 0 and notListed or nil
end)
