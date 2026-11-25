-- claude-in-wow: reading anything the game's functions tell, as Claude asks
-- it (Inbox.lua): expressions such as
--   C_Reputation.GetFactionDataByIndex(1..40)
--   C_Traits.GetConfigInfo(C_ClassTalents.GetActiveConfigID()).treeIDs
--   C_Club.GetMemberInfo(C_Club.GetGuildClubId(), each(C_Club.GetClubMembers(C_Club.GetGuildClubId())))
-- A call of a function of the list (Functions.lua: those that only read), its
-- arguments being numbers, texts, true, false, nil, Enum values, other calls, a
-- range (a..b: one call for each number) or each(...) (one for each element of
-- a list); then, if need be, .field or [index] of what it gives. Nothing else
-- is understood: no operator, no variable, no code, and no function that acts.

local addonName, ns = ...

local format, gsub, ipairs, lower, match, pairs, pcall, select, sub, tonumber, tostring, type =
    string.format, string.gsub, ipairs, string.lower, string.match, pairs, pcall, select, string.sub, tonumber, tostring, type
local gmatch, unpack = string.gmatch, unpack or table.unpack

local MAX_CALLS = 400   -- in one asking
local MAX_NODES = 6000  -- values kept, in one asking
local MAX_LENGTH = 600  -- of an expression
local MAX_DEPTH = 5     -- calls within calls

----------------------------------------------------------------------
-- The functions
----------------------------------------------------------------------

local allowed -- "C_Name.Function" -> true

local function Allowed(name)
    if not allowed then
        allowed = {}
        for space, names in pairs(ns.FUNCTIONS) do
            for own in gmatch(names, "%S+") do allowed[space == "" and own or space .. "." .. own] = true end
        end
    end
    return allowed[name]
end

-- The function of a name of the list: nil and why when there is none.
local function Function(name)
    if not Allowed(name) then return nil, "not a function that only reads: " .. name end
    local space, own = match(name, "^([%w_]+)%.([%w_]+)$")
    local from = space and _G[space] or not space and _G
    local fn = type(from) == "table" and from[own or name]
    if type(fn) ~= "function" then return nil, "this game has no " .. name end
    return fn
end

-- What a setting's name must not hold: the account is the player's own business.
local PRIVATE = { "account", "login", "password", "token", "email", "portal" }

local function Private(name, args)
    if not match(name, "^C_CVar%.") then return false end
    local setting = lower(tostring(args[1]))
    for _, word in ipairs(PRIVATE) do
        if setting:find(word, 1, true) then return true end
    end
    return false
end

----------------------------------------------------------------------
-- What is kept of what they give
----------------------------------------------------------------------

-- Fields that say who someone is outside the game, or what officers wrote.
local LEFT_OUT = { officerNote = true, battleTag = true, accountName = true, bnetAccountId = true, bnetAccountID = true, discordInfo = true }

-- A copy fit for the photo: no secret value, no code in texts, no function.
-- budget: { left }, values it may still keep.
function ns.Plain(value, depth, budget)
    value = ns.Clean(value)
    local kind = type(value)
    if kind == "string" then return ns.StripCodes((gsub(value, "|K.-|k", "?"))) end
    if kind == "number" or kind == "boolean" then return value end
    if kind ~= "table" or depth > 7 then return nil end
    local copy = {}
    for key, item in pairs(value) do
        key = ns.Clean(key)
        if (type(key) == "string" or type(key) == "number") and not LEFT_OUT[key] then
            if budget then
                budget.left = budget.left - 1
                if budget.left < 0 then return copy end
            end
            copy[key] = ns.Plain(item, depth + 1, budget)
        end
    end
    return copy
end

----------------------------------------------------------------------
-- Reading an expression
----------------------------------------------------------------------

-- A value with several to call with, one at a time.
local function Several(list)
    return { several = list }
end

local Parse -- below

-- Moves past spaces.
local function Skip(text, at)
    return match(text, "^%s*()", at)
end

-- A literal: number, range, text, true, false, nil, Enum value. Nil: none here.
-- value, next position.
local function Literal(text, at)
    local from, to, after = match(text, "^(%-?%d+)%s*%.%.%s*(%-?%d+)()", at)
    if from then
        from, to = tonumber(from), tonumber(to)
        if to - from >= MAX_CALLS then error("a range too long", 0) end
        local list = {}
        for number = from, to do list[#list + 1] = number end
        return Several(list), after
    end
    local number
    number, after = match(text, "^(%-?%d+%.?%d*)()", at)
    if number then return tonumber(number), after end
    local words
    words, after = match(text, '^"([^"]*)"()', at)
    if not words then words, after = match(text, "^'([^']*)'()", at) end
    if words then return words, after end
    words, after = match(text, "^(%a+)()", at)
    if words == "true" or words == "false" then return words == "true", after end
    if words == "nil" then return nil, after end
    local kind, name
    kind, name, after = match(text, "^Enum%.([%w_]+)%.([%w_]+)()", at)
    if kind then
        local value = type(Enum) == "table" and type(Enum[kind]) == "table" and Enum[kind][name]
        if type(value) ~= "number" then error("no Enum." .. kind .. "." .. name, 0) end
        return value, after
    end
    return nil, nil
end

-- The .field and [index] after a call, followed in a value.
local function Follow(text, at, value)
    while true do
        local field, after = match(text, "^%s*%.([%a_][%w_]*)()", at)
        if not field then
            field, after = match(text, "^%s*%[%s*(%d+)%s*%]()", at)
            field = tonumber(field)
        end
        if not field then return value, at end
        value = ns.Clean(value)
        if type(value) == "table" then value = value[field] else value = nil end
        at = after
    end
end

local function Pack(...)
    return { n = select("#", ...), ... }
end

-- Calls a function with arguments, one of which may be several.
local function Call(run, name, fn, args, count)
    local each
    for index = 1, count do
        if type(args[index]) == "table" and args[index].several then
            if each then error("one range or each at a time", 0) end
            each = index
        end
    end
    local function Once()
        run.calls = run.calls + 1
        if run.calls > MAX_CALLS then error("too many calls", 0) end
        if Private(name, args) then error("about the account", 0) end
        local got = Pack(pcall(fn, unpack(args, 1, count)))
        if not got[1] then error(name .. ": " .. tostring(got[2]), 0) end
        local results = {}
        for index = 2, got.n do results[index - 1] = got[index] end
        return results, got.n - 1
    end
    if not each then return Once() end
    local all = {}
    for index, value in ipairs(args[each].several) do
        args[each] = value
        local results, number = Once()
        all[index] = number > 1 and results or results[1]
    end
    return { all }, 1
end

-- A call: name(arguments), what follows it, the next position.
local function Calling(run, text, at, depth)
    local name, after = match(text, "^([%a_][%w_]*%.?[%w_]*)%s*%(()", at)
    if not name then error("not understood: " .. sub(text, at, at + 30), 0) end
    if depth > MAX_DEPTH then error("too deep", 0) end
    local args, count = {}, 0
    at = Skip(text, after)
    if sub(text, at, at) == ")" then
        at = at + 1
    else
        while true do
            local value
            value, at = Parse(run, text, at, depth + 1)
            count = count + 1
            args[count] = value
            at = Skip(text, at)
            local mark = sub(text, at, at)
            at = at + 1
            if mark == ")" then break end
            if mark ~= "," then error("not understood: " .. sub(text, at - 1, at + 30), 0) end
        end
    end
    if name == "each" then
        local list = args[1]
        if count ~= 1 or type(list) ~= "table" or list.several then error("each takes a list", 0) end
        local values = {}
        for index, value in ipairs(list) do values[index] = value end
        return Several(values), at
    end
    local fn, why = Function(name)
    if not fn then error(why, 0) end
    local results, number = Call(run, name, fn, args, count)
    -- as an argument, or followed by a field: its first value
    local first, stop = Follow(text, at, results[1])
    if depth > 0 or stop > at then return first, stop end
    return number > 1 and results or results[1], stop
end

function Parse(run, text, at, depth)
    at = Skip(text, at)
    local value, after = Literal(text, at)
    if after then return value, after end
    return Calling(run, text, at, depth)
end

-- Reads expressions, in order: { { read = the expression, value or error } }.
function ns.ReadAll(expressions)
    local run, list, budget = { calls = 0 }, {}, { left = MAX_NODES }
    for index, text in ipairs(expressions) do
        local entry = { read = text }
        list[index] = entry
        if #text > MAX_LENGTH then
            entry.error = "too long"
        else
            local ok, value, after = pcall(Calling, run, text, Skip(text, 1), 0)
            if ok and match(text, "%S", after) then ok, value = false, "not understood: " .. sub(text, after, after + 30) end
            if ok then
                ok, value = pcall(ns.Plain, value, 1, budget)
                if budget.left < 0 then entry.cut = true end
            end
            if ok then
                if value == nil then entry.nothing = true else entry.value = value end
            else
                entry.error = tostring(value)
            end
        end
    end
    return list
end
