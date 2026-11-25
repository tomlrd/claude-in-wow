-- claude-in-wow: Lua errors and blocked actions, kept for the assistant.
-- The game hides Lua errors by default; this keeps the last ones, with their
-- stack, without changing how the game shows them.

local addonName, ns = ...

local GetTime, debugstack, geterrorhandler, seterrorhandler = GetTime, debugstack, geterrorhandler, seterrorhandler
local ipairs, sub, time, tinsert, tostring, tremove = ipairs, string.sub, time, table.insert, tostring, table.remove

local MAX_ERRORS = 30
local MAX_TEXT = 1500

local pending = {} -- errors before the saved data is loaded

local function Record(message, stack, kind)
    message = sub(tostring(message), 1, MAX_TEXT)
    local list = ns.db and ns.db.errors or pending
    local now = GetTime()

    for _, entry in ipairs(list) do
        if entry.message == message then
            if entry.seenAt ~= now then -- the same error reported twice in one moment counts once
                entry.count = (entry.count or 1) + 1
                entry.time, entry.seenAt = time(), now
            end
            return
        end
    end

    tinsert(list, 1, {
        message = message,
        stack = stack and sub(stack, 1, MAX_TEXT) or nil,
        time = time(),
        seenAt = now,
        count = 1,
        kind = kind or "error",
        character = ns.key,
    })

    while #list > MAX_ERRORS do
        tremove(list)
    end
end

ns.RecordError = Record

-- Wraps the current error handler; again at login if another addon replaced
-- it since (BugGrabber and the like), so that both keep working.
function ns.WatchErrors()
    local current = geterrorhandler()
    if current == ns.errorHandler then return end

    local handler
    handler = function(message, ...)
        pcall(Record, message, debugstack and debugstack(2) or nil)
        if current then
            return current(message, ...)
        end
    end

    ns.errorHandler = handler
    seterrorhandler(handler)
end

-- Errors seen before the saved data was there, newest first.
function ns.MergePendingErrors()
    for index = #pending, 1, -1 do
        local entry = pending[index]
        entry.character = ns.key
        tinsert(ns.db.errors, 1, entry)
    end
    pending = {}

    while #ns.db.errors > MAX_ERRORS do
        tremove(ns.db.errors)
    end
end

function ns.BlockedAction(addon, func)
    Record(ns.L.BLOCKED:format(tostring(addon), tostring(func)), nil, "blocked")
end

ns.WatchErrors()
