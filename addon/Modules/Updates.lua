-- claude-in-wow module: updates, and what is new. The plugin looks for them (updates.mjs)
-- and tells the game: at each login or reload in an addon it makes (claude-in-wow_News),
-- and as the answer to a request. A badge on the title's line then says it; a click on it opens the
-- settings' tab, where what is new is, with "Update". The request goes in a photo,
-- as a question does, but Claude is not asked. The addon itself is updated by CurseForge,
-- or by the plugin from GitHub, as the player chose: then once the game is closed.

local addonName, ns = ...

local concat, date, floor, format, gmatch, ipairs, match, max, sub, time, tonumber =
    table.concat, date, math.floor, string.format, string.gmatch, ipairs, string.match, math.max, string.sub, time, tonumber
local L, T = ns.L, ns.Theme

local NEWS = addonName .. "_News"

ns.Category({ key = "updates", title = "TAB_UPDATES", order = 68 })

local asked -- what the last request of this session came to: "sending", "asked", "lost"

local function Version()
    return C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
end

-- Whether a version comes after another.
local function Newer(a, b)
    local x, y = {}, {}
    for part in gmatch(a or "", "%d+") do x[#x + 1] = tonumber(part) end
    for part in gmatch(b or "", "%d+") do y[#y + 1] = tonumber(part) end
    for index = 1, max(#x, #y) do
        if (x[index] or 0) ~= (y[index] or 0) then return (x[index] or 0) > (y[index] or 0) end
    end
    return false
end

-- What the plugin told, read and kept; nil for another text.
function ns.TakeUpdate(text)
    if not match(text or "", "^%s*%[claude%-in%-wow update%]") then return nil end
    local told = { at = time(), notes = {} }
    for name, value in gmatch(text, "([%w%.]+)=([^\n\r]+)") do
        local code = match(name, "^notes%.(%a+)$")
        if code then
            told.notes[code] = told.notes[code] or {}
            told.notes[code][#told.notes[code] + 1] = value
        else
            told[name] = value
        end
    end
    ns.db.update = told
    return told
end

-- The versions out that are not here: the addon's, the plugin's.
local function Out()
    local told = ns.db.update
    if not told or ns.db.options.updates == "never" then return nil, nil end
    local addon = Newer(told.addon, Version()) and told.addon or nil
    local plugin = Newer(told.plugin, told.pluginNow) and told.pluginState ~= "done" and told.plugin or nil
    return addon, plugin
end

-- Whether there is something left to ask for (an addon that waits for the game to be
-- closed is asked for already).
function ns.UpdateDue()
    local addon, plugin = Out()
    if addon and ns.db.update.waits == addon then addon = nil end
    return addon or plugin
end

function ns.OpenUpdates()
    ns.db.settingsTab = "updates"
    ns.OpenClaude("settings")
end

local function Refresh()
    ns.RenderClaude()
end

-- Asks the plugin to look, or to update.
function ns.AskUpdate(check)
    if asked == "sending" or asked == "asked" then return end
    local question = {
        id = time(), kind = "update", text = "update", at = time(), sentAt = time(),
        options = { slots = ns.WantedSlots() }, update = { check = check or nil, from = ns.db.options.updateFrom },
    }
    ns.TakeChannel(question)
    if not question.slot then -- nowhere to answer: the next reload frees some
        asked = "lost"
        return Refresh()
    end
    asked = "sending"
    if not ns.TakePhoto(question, function(ok)
        asked = ok and "asked" or nil
        if ok then
            question.sentAt = time()
            ns.WatchReply(question, function(text)
                asked = not ns.TakeUpdate(text) and "lost" or nil
                Refresh()
            end)
        end
        Refresh()
    end) then
        asked = nil
    end
    Refresh()
end

----------------------------------------------------------------------
-- The tab
----------------------------------------------------------------------

-- What is there to say, in lines.
local function Status()
    local told, lines = ns.db.update, {}
    local addon, plugin = Out()
    if asked == "lost" then
        lines[1] = L.UPDATE_LOST
    elseif asked then
        lines[1] = L.UPDATE_SENDING
    elseif not told then
        lines[1] = L.UPDATE_UNKNOWN
    elseif told.checked == "failed" then
        lines[1] = L.UPDATE_FAILED
    elseif told.checked == "none" then
        lines[1] = L.UPDATE_NOWHERE
    elseif not addon and not plugin then
        lines[1] = L.UPDATE_NONE
    end
    if addon then lines[#lines + 1] = format(L.UPDATE_ADDON, Version(), addon) end
    if plugin then lines[#lines + 1] = format(L.UPDATE_PLUGIN, told.pluginNow or "?", plugin) end
    if told and not asked then
        if told.waits and addon == told.waits then
            lines[#lines + 1] = L.UPDATE_ADDON_READY
        elseif addon and L["UPDATE_ADDON_" .. (told.addonState or ""):upper()] then
            lines[#lines + 1] = L["UPDATE_ADDON_" .. told.addonState:upper()]
        end
        if told.pluginState and L["UPDATE_PLUGIN_" .. told.pluginState:upper()] then lines[#lines + 1] = L["UPDATE_PLUGIN_" .. told.pluginState:upper()] end
    end
    return concat(lines, "\n"), (addon or plugin) and "text" or "secondary"
end

-- A list of lines as a text: "= 1.0.0" is a version, the others what it brought.
local function Listed(list)
    local lines = {}
    for _, line in ipairs(list) do
        local version = match(line, "^= (.+)$")
        lines[#lines + 1] = version and (#lines > 0 and "\n" or "") .. T.Code("title") .. version .. "|r" or "\226\128\162 " .. ns.PlainText(line)
    end
    return concat(lines, "\n")
end

local function Page(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame.status = T.Text(frame, "sans", 13, "text")
    frame.update = T.Chip(frame, "ArrowUp", L.UPDATE, function() ns.AskUpdate() end, true)
    frame.check = T.Chip(frame, "Check", L.UPDATE_CHECK, function() ns.AskUpdate(true) end)
    frame.news = T.Text(frame, "sans", 13, "secondary")
    function frame:Refresh(width)
        local text, color = Status()
        self.status:SetText(text)
        self.status:SetTextColor(T.Color(color))
        self.status:SetWidth(width)
        self.status:ClearAllPoints()
        self.status:SetPoint("TOPLEFT")
        local y = (self.status:GetStringHeight() or 13) + 12
        local due = ns.UpdateDue() and not (asked == "sending" or asked == "asked")
        self.update:SetShown(due and true or false)
        self.check:SetShown(not due and ns.db.options.updates ~= "never")
        local chip = due and self.update or self.check
        chip:ClearAllPoints()
        chip:SetPoint("TOPLEFT", 0, -y)
        y = y + 28 + 18
        local list = {}
        local addon = Out()
        if addon then
            local notes = ns.db.update.notes
            list[1] = "= " .. addon
            for _, line in ipairs(notes[ns.Language()] or notes.enUS or {}) do list[#list + 1] = line end
        end
        for _, line in ipairs(L.CHANGES) do list[#list + 1] = line end
        self.news:SetText(Listed(list))
        self.news:SetWidth(width)
        self.news:ClearAllPoints()
        self.news:SetPoint("TOPLEFT", 0, -y)
        y = y + (self.news:GetStringHeight() or 13)
        self:SetSize(width, y)
        return y
    end
    return frame
end

local function Modes()
    return { { value = "notify", label = L.UPDATES_NOTIFY }, { value = "auto", label = L.UPDATES_AUTO }, { value = "never", label = L.UPDATES_NEVER } }
end

local function Places()
    return { { value = "curseforge", label = "CurseForge" }, { value = "github", label = "GitHub" } }
end

ns.Module({
    key = "update", category = "updates", order = 10, fixed = true, title = "UPDATES", tip = "UPDATES_TIP",
    settings = {
        { key = "updates", label = "UPDATES_MODE", tip = "UPDATES_MODE_TIP", default = "notify", choices = Modes },
        { key = "updateFrom", label = "UPDATE_FROM", tip = "UPDATE_FROM_TIP", default = "curseforge", choices = Places },
    },
    custom = Page,
})

----------------------------------------------------------------------
-- The badge on the title's line
----------------------------------------------------------------------

-- What it says and its tooltip, whichever of the two is to be updated; nil when none is.
function ns.UpdateBadge()
    if asked == "sending" or asked == "asked" then return L.UPDATE_BADGE, L.UPDATE_SENDING end
    if not ns.UpdateDue() then return nil end
    local addon, plugin = Out()
    local lines = {}
    if addon then lines[1] = format(L.UPDATE_ADDON, Version(), addon) end
    if plugin then lines[#lines + 1] = format(L.UPDATE_PLUGIN, ns.db.update.pluginNow or "?", plugin) end
    return L.UPDATE_BADGE, concat(lines, "\n") .. "\n" .. L.UPDATE_BADGE_TIP
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    local told = ns.ReadAddon(NEWS)
    if told then
        ns.TakeUpdate(told)
        ns.RenderClaude()
    end
end)
