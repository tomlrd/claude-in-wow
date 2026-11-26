-- claude-in-wow module: Claude's answers coming into the game by themselves
-- (the module "arrive"). An addon reads no file while the game runs, but for two
-- things, with files that were there when the game started:
--   A sound: Inbox\NNN.wav are empty; the plugin fills one with a chime when an
--   answer is ready (deliver.mjs). Played, an empty one is over at once, a
--   filled one is still playing a moment later: the game hears it, and so does
--   the player. The game keeps a sound it has heard until it is closed, so
--   each question takes the next file. The same way, Inbox\aNNN.wav says that the
--   plugin has received the question: without it, the player is told.
--   An addon loaded on demand: each claude-in-wow_SNNN is one Lua file, read
--   when it is loaded. The plugin writes the answer in one, as a text. Loaded
--   ones are free again after a /reload. The player picks how many there are
--   (settings, "slots"); the plugin makes them and takes them away (slots.mjs),
--   and the game sees it when it is next started.
-- Each question takes its signal and its slot with it (question.signal and
-- .slot). Without a signal (the game's sound is off, or the files came while
-- the game ran), or without a slot, the answer is pasted as before.
-- Nothing tells the game that a file changed: the signals of the questions
-- that wait are listened to every second, only while some do.
-- And what the player says to Claude outside the game, in a session they see (the setting
-- "answerBy"), shows here too, with its answer: a few signals and slots are set apart for
-- it, told to the plugin in each photo and in the saved data (ns.db.spare), and listened
-- to while that setting is on. A photo tells them as soon as the player picks a session, and
-- again when they run short: without it, what is said there could not come here.

local addonName, ns = ...

local C_AddOns, C_Timer, format, ipairs, min, pcall, time, tostring, tremove, type = C_AddOns, C_Timer, string.format, ipairs, math.min, pcall, time, tostring, table.remove, type

local SIGNALS = 250     -- as the plugin's tools\inbox.mjs makes them
local MAX_SLOTS = 200
local FEW = 3           -- so few left: said
local LOOK = 1          -- seconds
local HEARD = 0.2       -- an empty sound is over by then, the chime is not
local EARLY = 3         -- a signal heard sooner was left by an earlier question
local GIVE_UP = 10 * 60 -- an answer later than that is for the paste
local UNHEARD = 15      -- a question not received by then: nobody seems to listen
local LONG = 180        -- without sounds to tell, an answer this late
local KEPT = 2 * 3600   -- and the plugin keeps it that long
local SPARES = 5        -- set apart for what is said outside the game
local LISTENED = 3      -- of them, the first ones: the plugin takes them in order
local SHORT = 2         -- so few left: more, told in a photo

local function SlotName(number)
    return format("%s_S%03d", addonName, number)
end

-- The handle of a sound file played; nil when the game does not play it.
local function Play(name)
    local ok, plays, handle = pcall(PlaySoundFile, "Interface\\AddOns\\" .. addonName .. "\\Inbox\\" .. name .. ".wav", "Master")
    return ok and plays and handle or nil
end

-- How many slots the game has found.
function ns.SlotCount()
    local count = 0
    for number = 1, MAX_SLOTS do
        if C_AddOns.DoesAddOnExist(SlotName(number)) then count = count + 1 end
    end
    return count
end

-- A slot not loaded yet since the last /reload, that no question waits for.
local function FreeSlot()
    local taken = {}
    for _, question in ipairs(ns.WaitingQuestions()) do
        if question.slot then taken[question.slot] = true end
    end
    for _, spare in ipairs(ns.db.spare and ns.db.spare.list or {}) do
        if spare.slot then taken[spare.slot] = true end
    end
    for number = 1, ns.db.options.slots do
        local name = SlotName(number)
        if not taken[number] and not C_AddOns.IsAddOnLoaded(name) and C_AddOns.IsAddOnLoadable(name, nil, true) then
            return number
        end
    end
end

-- How many answers may still come by themselves until the next /reload, and how many
-- there are in all.
function ns.SlotsLeft()
    local left, all = 0, 0
    for number = 1, ns.db.options.slots do
        local name = SlotName(number)
        if C_AddOns.DoesAddOnExist(name) then
            all = all + 1
            if not C_AddOns.IsAddOnLoaded(name) then left = left + 1 end
        end
    end
    return left, all
end

-- What to say when few are left; nil otherwise.
function ns.SlotsWarning()
    if not ns.On("arrive") then return nil end
    local left, all = ns.SlotsLeft()
    if all <= FEW or left > FEW then return nil end
    return left > 0 and format(ns.L.SLOTS_FEW, left) or ns.L.SLOTS_NONE
end

-- The interface loaded again: at a click of the player's only.
function ns.ReloadInterface()
    (C_UI and C_UI.Reload or ReloadUI)()
end

-- Whether answers can come by themselves now.
function ns.AnswersArrive()
    return Play("empty") ~= nil and FreeSlot() ~= nil
end

-- Gives a question about to be sent its signal and its slot.
function ns.TakeChannel(question)
    if not ns.db.options.arrive or not Play("empty") then return end
    question.signal = ns.db.nextSignal or 1
    ns.db.nextSignal = question.signal % SIGNALS + 1
    question.slot = FreeSlot()
end

-- Whether a session the player sees answers (the silent mode then leaves the questions),
-- and whether what they say there shows here.
function ns.BySession()
    return ns.db.options.answerBy == "session"
end

local function FromSession()
    return ns.BySession() and ns.On("saidInGame") and ns.On("arrive")
end

-- The signals and slots set apart for what is said there, as many as there may be:
-- { at, list = { { signal, slot, from } } }, for the photo; nil when it is not to show here.
function ns.SpareChannels()
    if not FromSession() or not Play("empty") then return nil end
    ns.db.spare = ns.db.spare or { list = {} }
    local list = ns.db.spare.list
    while #list < SPARES do
        local spare = { from = time() }
        ns.TakeChannel(spare)
        if not spare.slot then break end
        list[#list + 1] = spare
    end
    ns.db.spare.at = time()
    if #list > 0 then ns.WatchAnswers() end
    return ns.db.spare
end

-- The places set apart, made and told to the plugin in a photo (out of combat).
function ns.TellSpare()
    local spare = ns.SpareChannels()
    if spare and #spare.list > 0 and not InCombatLockdown() then ns.TakePhoto(nil) end
end

-- The text in an addon the plugin writes, read once.
function ns.ReadAddon(name)
    if not C_AddOns.DoesAddOnExist(name) or C_AddOns.IsAddOnLoaded(name) then return nil end
    ClaudeInWoWInbox = nil
    local ok, loaded = pcall(C_AddOns.LoadAddOn, name)
    local text = ClaudeInWoWInbox
    ClaudeInWoWInbox = nil
    return ok and loaded and type(text) == "string" and text or nil
end

local function SlotText(slot)
    return slot and ns.ReadAddon(SlotName(slot))
end

-- A question's answer is ready: taken from its slot, else to paste.
local function Ready(question)
    question.ready = true
    local text = SlotText(question.slot)
    if text then ns.TakeInbox(text) end
    ns.RenderClaude()
end

-- Listens to the signal of a question that waits: heard, its answer is there.
local function Listen(question)
    local signal = question.signal
    local handle = Play(format("%03d", signal))
    if not handle then return end
    C_Timer.After(HEARD, function()
        if question.answered or question.ready or question.signal ~= signal or not C_Sound.IsPlaying(handle) then return end
        if time() - question.sentAt < EARLY then
            question.signal, question.slot = nil, nil -- to paste
            ns.RenderClaude()
        else
            Ready(question)
        end
    end)
end

-- Listens to a signal set apart: heard, what was said outside the game is in its slot.
local function ListenSpare(spare)
    local handle = Play(format("%03d", spare.signal))
    if not handle then return end
    C_Timer.After(HEARD, function()
        if not C_Sound.IsPlaying(handle) then return end
        for index, other in ipairs(ns.db.spare and ns.db.spare.list or {}) do
            if other == spare then
                tremove(ns.db.spare.list, index)
                local text = time() - spare.from >= EARLY and SlotText(spare.slot) -- sooner: left by an earlier one
                if text then ns.TakeInbox(text) end
                if #ns.db.spare.list <= SHORT then C_Timer.After(2, ns.TellSpare) end -- once the answer shows
                return
            end
        end
    end)
end

-- Listens to the sound that says a question was received.
local function ListenReceived(question)
    local handle = Play(format("a%03d", question.signal))
    if not handle then return end
    C_Timer.After(HEARD, function()
        if question.received or not C_Sound.IsPlaying(handle) then return end
        question.received = time() - question.sentAt < EARLY and "unknown" or true -- an earlier question's: nothing sure
        ns.RenderClaude()
    end)
end

-- Whether a question seems to have been received by nobody.
function ns.Unheard(question)
    if question.state ~= "sent" or not question.sentAt or question.answered or question.ready then return false end
    local since = time() - question.sentAt
    if question.received == true then return false end
    if question.signal and not question.received then return since >= UNHEARD end
    return since >= LONG
end

-- Requests that are not questions (Updates.lua): { question, done }, done(text) once
-- answered, done(nil) when nobody seems to have received it.
local replies = {}

local function ListenReply(reply)
    local question = reply.question
    local handle = Play(format("%03d", question.signal))
    if not handle then return end
    C_Timer.After(HEARD, function()
        if reply.over or not C_Sound.IsPlaying(handle) then return end
        reply.over = true
        reply.done(SlotText(question.slot))
    end)
end

local function LookAtReplies()
    for index = #replies, 1, -1 do
        local reply = replies[index]
        local question = reply.question
        local since = time() - question.sentAt
        if reply.over then
            tremove(replies, index)
        elseif since >= GIVE_UP or since >= UNHEARD and question.received ~= true then
            tremove(replies, index)
            reply.over = true
            reply.done(nil)
        else
            if not question.received then ListenReceived(question) end
            ListenReply(reply)
        end
    end
    return #replies > 0
end

local ticker

local function Look()
    local waiting = false
    for _, question in ipairs(ns.WaitingQuestions()) do
        if question.signal and question.sentAt and not question.ready and time() - question.sentAt < GIVE_UP then
            waiting = true
            if not question.received then ListenReceived(question) end
            Listen(question)
            local lost = ns.Unheard(question)
            if lost ~= (question.lost or false) then
                question.lost = lost or nil
                ns.RenderClaude()
            end
        end
    end
    local spares = FromSession() and ns.db.spare and ns.db.spare.list or {}
    for index = 1, min(LISTENED, #spares) do
        waiting = true
        ListenSpare(spares[index])
    end
    waiting = LookAtReplies() or waiting
    if not waiting and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

-- A question was sent: its signal is listened to until its answer is there.
function ns.WatchAnswers()
    ticker = ticker or C_Timer.NewTicker(LOOK, Look)
end

function ns.WatchReply(question, done)
    replies[#replies + 1] = { question = question, done = done }
    ns.WatchAnswers()
end

-- After a /reload: the questions that wait still do, and the slots can be read again.
function ns.ResumeAnswers()
    local watch = FromSession() and ns.db.spare ~= nil
    for _, question in ipairs(ns.WaitingQuestions()) do
        if question.ready and time() - question.at < KEPT then Ready(question) end
        watch = watch or question.signal and not question.ready
    end
    if watch then ns.WatchAnswers() end
end

----------------------------------------------------------------------
-- The modules
----------------------------------------------------------------------

local L = ns.L

-- How many slots there should be: none while the answers do not come by themselves.
function ns.WantedSlots()
    return ns.On("arrive") and ns.db.options.slots or 0
end

-- How many are left, and the button that frees them.
local function Left(parent)
    local T = ns.Theme
    local frame = CreateFrame("Frame", nil, parent)
    frame.count = T.Text(frame, "sansMedium", 13, "text")
    frame.count:SetPoint("TOPLEFT")
    frame.tip = T.Text(frame, "sans", 12, "muted")
    frame.tip:SetText(L.SLOTS_TIP)
    frame.reload = T.Chip(frame, "Check", L.SKIN_RELOAD, ns.ReloadInterface)
    function frame:Refresh(width)
        local left, all = ns.SlotsLeft()
        self:SetShown(ns.On("arrive") and all > 0)
        if not ns.On("arrive") or all == 0 then
            self:SetSize(width, 1)
            return 1
        end
        self.count:SetWidth(width)
        self.count:SetText(format(L.SLOTS_LEFT, left, all))
        self.count:SetTextColor(T.Color(left <= FEW and "clay" or "title"))
        local y = (self.count:GetStringHeight() or 13) + 4
        self.tip:SetWidth(width)
        self.tip:ClearAllPoints()
        self.tip:SetPoint("TOPLEFT", 0, -y)
        y = y + (self.tip:GetStringHeight() or 12) + 8
        self.reload:SetShown(left < all)
        if left < all then
            self.reload:ClearAllPoints()
            self.reload:SetPoint("TOPLEFT", 0, -y)
            y = y + 28
        end
        self:SetSize(width, y)
        return y
    end
    return frame
end

local function Numbers()
    local list = {}
    for index, value in ipairs({ 10, 20, 30, 50, 100, 200 }) do list[index] = { value = value, label = tostring(value) } end
    return list
end

ns.Module({
    key = "arrive", category = "answers", order = 10, title = "OPTION_ARRIVE", tip = "OPTION_ARRIVE_TIP",
    warning = function() return ns.On("arrive") and not ns.AnswersArrive() and L.OPTION_ARRIVE_OFF end,
    settings = { {
        key = "slots", label = "OPTION_SLOTS", tip = "OPTION_SLOTS_TIP", default = 100, choices = Numbers,
        warning = function()
            local found = ns.SlotCount()
            return found ~= ns.WantedSlots() and format(L.OPTION_SLOTS_DUE, found)
        end,
    } },
    custom = Left,
})
ns.Module({
    key = "sounds", category = "answers", order = 20, fixed = true, title = "SOUNDS", tip = "SOUNDS_TIP",
    settings = {
        { key = "soundReady", label = "OPTION_SOUND_READY", tip = "OPTION_SOUND_READY_TIP", default = true },
        { key = "soundStart", label = "OPTION_SOUND_START", tip = "OPTION_SOUND_START_TIP", default = false },
    },
})
