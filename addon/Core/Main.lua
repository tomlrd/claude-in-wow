-- claude-in-wow: snapshots and events. Invisible: it notes the game state
-- at every reload or logout, when the game writes its saved data to disk.

local addonName, ns = ...

local time = time

local function Snapshot()
    local char = ns.char
    if not char then return end

    ns.Collect(char)
    char.savedAt = time()
    return char
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... == addonName then
            ns.InitDB()
            ns.MergePendingErrors()
            ns.RegisterMinimapButton()
        end
    elseif event == "PLAYER_LOGIN" then
        ns.WatchErrors()
        ns.ResumeAnswers()
    elseif event == "PLAYER_LOGOUT" then
        Snapshot()
    elseif event == "BANKFRAME_OPENED" then
        C_Timer.After(1, ns.ScanBank)
    elseif event == "BANKFRAME_CLOSED" then
        ns.ScanBank()
    else -- a blocked or forbidden action
        ns.BlockedAction(...)
    end
end)
