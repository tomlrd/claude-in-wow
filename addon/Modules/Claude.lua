-- claude-in-wow module: Claude. The model the silent mode asks and how much
-- it thinks ("default": Claude Code's own), also picked in the window by the
-- button that sends; the session all the conversations share; what each
-- question tells the silent mode (ns.QuestionChoices; silent.mjs in the plugin);
-- and the model and the tokens under each answer, with where they went.

local addonName, ns = ...

local date, format, gsub, ipairs, match, tostring, upper = date, string.format, string.gsub, ipairs, string.match, tostring, string.upper
local L, T = ns.L, ns.Theme

----------------------------------------------------------------------
-- The model and its effort
----------------------------------------------------------------------

-- "Opus 5.5" of "opus-5.5".
function ns.ModelName(model)
    local name = gsub(gsub(model, "^%l", upper), "%-", " ", 1)
    return name
end

-- The model an answer came from, for the names here to say its version.
-- picked: the one asked, nil for the default.
function ns.NoteModel(model, picked)
    local db = ns.db
    db.claudeModels = db.claudeModels or {}
    db.claudeModels[match(model, "^%a+") or model] = model
    if not picked then db.claudeDefaultModel = model end
end

-- What a question tells the silent mode: the model and its effort (nil: the
-- default), and how to answer.
function ns.QuestionChoices()
    local options = ns.db.options
    return options.model ~= "default" and options.model or nil, options.effort ~= "default" and options.effort or nil, {
        renew = options.renew, renewAt = options.renewAt * 1000, remember = options.remember,
        renewPause = options.renewPause * 60, renewPauseAt = options.renewPauseAt * 1000, parallel = options.parallel,
        language = ns.Language(), soundStart = options.soundStart, soundReady = options.soundReady,
        slots = ns.WantedSlots(), off = ns.ModulesOff(), blocks = { "route", "why" }, by = options.answerBy,
    }
end

-- "107 901" of 107901, with the language's separator.
function ns.GroupNumber(count)
    local text = gsub(tostring(count):reverse(), "(%d%d%d)", "%1 "):reverse()
    text = gsub(text, "^ ", "")
    text = gsub(text, " ", L.THOUSANDS)
    return text
end

-- What an answer took, under it: the model, its effort, the tokens ({ model,
-- effort, tokens, cached }); nil when it does not say.
local Number = ns.GroupNumber
function ns.AnswerNote(message)
    if not message.model or not ns.On("answerNote") then return nil end
    local note = ns.ModelName(message.model)
    if message.effort then note = note .. "  \194\183  " .. format(L.EFFORT_NOTE, L.EFFORTS[message.effort] or message.effort) end
    if message.tokens then
        note = note .. "  \194\183  " .. format((message.cached or 0) > 0 and L.TOKENS_CACHED or L.TOKENS, Number(message.tokens), Number(message.cached or 0))
    end
    return note
end

-- Where an answer's tokens went, in a tooltip over that line. message.detail:
-- the tokens every session starts with, those of its memory, of the question
-- with what was read for it, of the searches (each reads everything again), of
-- the answer; and how many times Claude was called.
function ns.ShowAnswerDetail(owner, message)
    local detail = message.detail
    if not detail then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText(format(L.DETAIL, Number(message.tokens or 0)), 1, 1, 1)
    for index, label in ipairs({ L.DETAIL_BASE, L.DETAIL_MEMORY, L.DETAIL_QUESTION, format(L.DETAIL_SEARCHES, (detail[6] or 1) - 1), L.DETAIL_ANSWER }) do
        local tokens = detail[index] or 0
        if tokens > 0 then GameTooltip:AddDoubleLine(label, Number(tokens), 0.76, 0.75, 0.71, 1, 1, 1) end
    end
    if (message.cached or 0) > 0 then GameTooltip:AddLine(format(L.DETAIL_CACHED, Number(message.cached)), 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end

----------------------------------------------------------------------
-- The modules
----------------------------------------------------------------------

-- The words claude takes (silent.mjs), a model's name for its latest version.
local function Models()
    local list, default = {}, ns.db.claudeDefaultModel
    for index, value in ipairs({ "default", "opus", "sonnet", "haiku", "fable" }) do
        list[index] = {
            value = value,
            label = value == "default" and L.MODEL_DEFAULT or ns.ModelName(ns.db.claudeModels and ns.db.claudeModels[value] or value),
            detail = value == "default" and default and format(L.MODEL_DEFAULT_KNOWN, ns.ModelName(default)) or L["MODEL_" .. upper(value) .. "_TIP"],
        }
    end
    return list
end

local function Efforts()
    local list = {}
    for index, value in ipairs({ "default", "low", "medium", "high", "xhigh", "max" }) do
        list[index] = { value = value, label = L.EFFORTS[value], detail = L["EFFORT_" .. upper(value) .. "_TIP"] }
    end
    return list
end

-- The default model by the name it answered with.
local function ModelShown(value)
    local default = ns.db.claudeDefaultModel
    if value == "default" then return default and ns.ModelName(default) or L.MODEL_DEFAULT end
    return ns.ModelName(ns.db.claudeModels and ns.db.claudeModels[value] or value)
end

-- What the last answer said of Claude's session.
local function SessionStatus()
    local status = ns.db.claudeStatus
    if not status then return L.SESSION_NONE end
    return format(L.SESSION_STATUS, status.session, status.questions or 0)
        .. (status.tokens and format(L.SESSION_TOKENS, status.tokens) or "")
        .. format(L.SESSION_LAST, date("%H:%M", status.at or 0), status.seconds or 0)
        .. (status.model and format(L.SESSION_BY, ns.ModelName(status.model)) or "") .. "."
end

-- The session, shared by every conversation of the window, and starting it afresh.
local function Session(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame.status = T.Text(frame, "sans", 12, "secondary")
    frame.status:SetPoint("TOPLEFT")
    frame.fresh = T.Chip(frame, "NewChat", L.SESSION_NEW, function()
        ns.db.claudeNewSession = not ns.db.claudeNewSession or nil
        ns.RenderClaude()
    end)
    frame.reload = T.Chip(frame, "Check", L.SESSION_RELOAD, function() ns.ReloadInterface() end)
    frame.reload:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L.SESSION_RELOAD_TIP, 0.76, 0.75, 0.71, 1, true)
        GameTooltip:Show()
    end)
    frame.reload:HookScript("OnLeave", GameTooltip_Hide)
    function frame:Refresh(width)
        self.status:SetWidth(width)
        self.status:SetText(SessionStatus())
        local height = (self.status:GetStringHeight() or 12) + 10
        self.fresh:SetLabel(ns.db.claudeNewSession and L.SESSION_NEW_DUE or L.SESSION_NEW)
        self.fresh:ClearAllPoints()
        self.fresh:SetPoint("TOPLEFT", 0, -height)
        -- the answers' addons are another matter: a reload frees them
        local left, all = ns.SlotsLeft()
        local more = ns.db.claudeNewSession and left < all
        self.reload:SetShown(more and true or false)
        if more then
            self.reload:ClearAllPoints()
            self.reload:SetPoint("TOPLEFT", 0, -height - 34)
            height = height + 34
        end
        self:SetSize(width, height + 28)
        return height + 28
    end
    return frame
end

local function Remembered()
    local list = {}
    for index, count in ipairs({ 0, 3, 6, 10, 20, 50, -1 }) do -- -1: all
        list[index] = { value = count, label = count == 0 and L.REMEMBER_NONE or count < 0 and L.REMEMBER_ALL or format(L.REMEMBER_COUNT, count) }
    end
    return list
end

-- An hour at least: Claude keeps a session ready that long, sooner would save nothing.
local function Pauses()
    local list = {}
    for index, hours in ipairs({ 0, 1, 2, 4, 8, 24 }) do
        list[index] = { value = hours * 60, label = hours == 0 and L.PAUSE_NEVER or format(L.PAUSE_HOURS, hours) }
    end
    return list
end

local function PauseSizes()
    local list = {}
    for index, thousands in ipairs({ 0, 20, 40, 60, 100, 150, 250 }) do
        list[index] = { value = thousands, label = thousands == 0 and L.PAUSE_ANY_SIZE or format(L.RENEW_AT_COUNT, Number(thousands * 1000)) }
    end
    return list
end

local function NotRenewed() return not ns.On("renew") and L.RENEW_OFF or nil end
local function NoPause() return NotRenewed() or ns.db.options.renewPause == 0 and L.PAUSE_OFF or nil end

local function Sizes()
    local list = {}
    for index, thousands in ipairs({ 40, 60, 100, 150, 250, 400, 700, 0 }) do -- 0: whatever its size, it goes on
        list[index] = { value = thousands, label = thousands == 0 and L.RENEW_AT_NEVER or format(L.RENEW_AT_COUNT, Number(thousands * 1000)) }
    end
    return list
end

-- Who answers: the hidden program, or a session of Claude the player sees.
local function Answerers()
    return { { value = "silent", label = L.ANSWER_SILENT }, { value = "session", label = L.ANSWER_SESSION } }
end

ns.Module({
    key = "claude", category = "claude", order = 10, fixed = true, title = "CLAUDE_MODULE",
    settings = {
        { key = "answerBy", label = "ANSWER_BY", tip = "ANSWER_BY_TIP", default = "silent", choices = Answerers, changed = function()
            ns.WatchAnswers()
            if ns.BySession() then ns.TellSpare() end
        end },
        { key = "saidInGame", label = "SAID_IN_GAME", tip = "SAID_IN_GAME_TIP", default = true, changed = function() ns.WatchAnswers() end },
        { key = "model", label = "MODEL", tip = "OPTION_MODEL_TIP", default = "default", choices = Models, shown = ModelShown },
        { key = "effort", label = "EFFORT", tip = "OPTION_EFFORT_TIP", default = "default", choices = Efforts },
        { key = "parallel", label = "OPTION_PARALLEL", tip = "OPTION_PARALLEL_TIP", default = true },
    },
})
ns.Module({
    key = "session", category = "claude", order = 20, fixed = true, title = "SESSION_TITLE", tip = "SESSION_TIP",
    settings = {
        { key = "freshSession", label = "FRESH", tip = "FRESH_TIP", default = false },
        { key = "remember", label = "REMEMBER", tip = "REMEMBER_TIP", default = 6, choices = Remembered },
        { key = "renew", label = "OPTION_RENEW", tip = "OPTION_RENEW_TIP", default = true },
        { key = "renewAt", label = "RENEW_AT", tip = "RENEW_AT_TIP", default = 250, choices = Sizes, warning = NotRenewed },
        { key = "renewPause", label = "PAUSE", tip = "PAUSE_TIP", default = 60, choices = Pauses, warning = NotRenewed },
        { key = "renewPauseAt", label = "PAUSE_AT", tip = "PAUSE_AT_TIP", default = 60, choices = PauseSizes, warning = NoPause },
    },
    custom = Session,
})
ns.Module({ key = "web", category = "limits", limit = true, order = 10, title = "WEB_MODULE", tip = "WEB_MODULE_TIP" })
ns.Module({ key = "addons", category = "limits", limit = true, order = 20, title = "ADDONS_MODULE", tip = "ADDONS_MODULE_TIP" })
ns.Module({ key = "searches", category = "limits", limit = true, order = 50, title = "SEARCHES_MODULE", tip = "SEARCHES_MODULE_TIP" })
ns.Module({ key = "never", category = "limits", order = 70, fixed = true, title = "NEVER_MODULE", tip = "NEVER_MODULE_TIP" })
ns.Module({ key = "answerNote", category = "answers", order = 30, title = "ANSWER_NOTE", tip = "ANSWER_NOTE_TIP" })

-- A new session each time the player logs in, when they prefer so.
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_ENTERING_WORLD")
login:SetScript("OnEvent", function(_, _, initial)
    if initial and ns.On("freshSession") then
        ns.db.claudeNewSession = true
        ns.RenderClaude()
    end
end)
