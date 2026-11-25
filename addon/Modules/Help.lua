-- claude-in-wow module: what to do for Claude to answer. The settings' tab "Help":
-- whether Claude has answered yet, what to install, and what to look at when nothing
-- answers. It opens from a question that nobody received (Inbox.lua). And, in the tab
-- "Questions", how to speak instead of writing, with what Windows has for it.

local addonName, ns = ...

local date, ipairs, max, next = date, ipairs, math.max, next
local L, T = ns.L, ns.Theme

local SETUP = "/wow-mcp:setup"

ns.Category({ key = "help", title = "TAB_HELP", order = 65 })

-- Whether nothing has ever answered.
function ns.NeverAnswered()
    return not ns.db.claudeStatus and not (ns.db.usage and next(ns.db.usage.list))
end

function ns.OpenHelp()
    ns.db.settingsTab = "help"
    ns.OpenClaude("settings")
end

local function Status()
    local status = ns.db.claudeStatus
    local lost = false
    for _, question in ipairs(ns.WaitingQuestions()) do lost = lost or ns.Unheard(question) end
    if lost then return ns.BySession() and L.HELP_UNHEARD_SESSION or ns.NeverAnswered() and L.HELP_UNHEARD_FIRST or L.HELP_UNHEARD, "clay" end
    if status and status.at then return date(L.HELP_LAST, status.at), "secondary" end
    return L.HELP_NEVER, "secondary"
end

-- A page of heads, lists and chips, one under the other. The text above them says its own
-- (text, colour) at each showing; none without.
local function Pages(parent, above, fill)
    local frame = CreateFrame("Frame", nil, parent)
    local status = above and T.Text(frame, "sans", 13, "secondary")
    local parts = {}
    local function Head(key)
        local head = T.Text(frame, "sansMedium", 14, "text")
        head:SetText(L[key])
        parts[#parts + 1] = { text = head, above = 18, indent = 0 }
    end
    local function List(lines, numbered)
        for index, line in ipairs(lines) do
            local mark, text = T.Text(frame, "sans", 13, "muted"), T.Text(frame, "sans", 13, "secondary")
            mark:SetText(numbered and index .. "." or "\226\128\162")
            text:SetText(line)
            parts[#parts + 1] = { text = text, mark = mark, above = 8, indent = 20 }
        end
    end
    local function Chip(icon, label, run)
        parts[#parts + 1] = { frame = T.Chip(frame, icon, label, run), above = 10, indent = 20 }
    end
    fill(Head, List, Chip)

    function frame:Refresh(width)
        local y = 0
        if status then
            local text, color = above()
            status:SetText(text)
            status:SetTextColor(T.Color(color))
            status:SetWidth(width)
            status:ClearAllPoints()
            status:SetPoint("TOPLEFT")
            y = status:GetStringHeight() or 13
        end
        for index, part in ipairs(parts) do
            y = y + ((index > 1 or status) and part.above or 0)
            local shown = part.text or part.frame
            shown:ClearAllPoints()
            shown:SetPoint("TOPLEFT", part.indent, -y)
            if part.mark then
                part.mark:ClearAllPoints()
                part.mark:SetPoint("TOPLEFT", 0, -y)
            end
            if part.text then
                part.text:SetWidth(max(width - part.indent, 60))
                y = y + (part.text:GetStringHeight() or 13)
            else
                y = y + 28
            end
        end
        self:SetSize(width, y)
        return y
    end
    return frame
end

local function Page(parent)
    return Pages(parent, Status, function(Head, List, Chip)
        Head("HELP_STEPS")
        List(L.HELP_LIST, true)
        Chip("Copy", L.HELP_COPY:format(SETUP), function()
            ns.OpenClaude()
            ns.CopyText(SETUP, L.COPY_TEXT)
        end)
        Chip("Check", L.TOUR_AGAIN, function()
            ns.OpenClaude()
            ns.StartTour()
        end)
        Head("HELP_WRONG")
        List(L.HELP_WRONG_LIST, false)
    end)
end

local function Voice(parent)
    return Pages(parent, nil, function(Head, List)
        List(L.VOICE_LIST, true)
        Head("VOICE_ONE")
        List(L.VOICE_ONE_LIST, false)
        Head("VOICE_WRONG")
        List(L.VOICE_WRONG_LIST, false)
    end)
end

ns.Module({ key = "voice", category = "questions", order = 30, fixed = true, title = "VOICE", tip = "VOICE_TIP", custom = Voice })
ns.Module({ key = "help", category = "help", order = 10, fixed = true, title = "HELP_STATUS", custom = Page })
