-- claude-in-wow: its texts, ns.L. Each language is one file of Locales, which gives
-- them by name (ns.Locale): English first, for every text, then the language shown over
-- it, for those it has. Nothing else here writes a text.
-- The language shown is the player's choice (the settings, ns.db.options.language),
-- known once the saved data is there (ns.UseLanguage, from Core.lua); until then, the
-- game's. At first it is Claude's: the game's while Claude has not answered. A text taken as a file loads would stay in the game's: read
-- them when they are shown, or in ns.OnLanguage.

local addonName, ns = ...

local ipairs, pairs, sort, type = ipairs, pairs, table.sort, type

ns.L = {}

-- The game's languages that share a file.
local SHARED = { enGB = "enUS", esMX = "esES" }

local languages, listeners, shown = {}, {}, nil

local function Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for part, inner in pairs(value) do copy[part] = Copy(inner) end
    return copy
end

-- A language's texts over those there. A list (its lines) is taken whole; a table by
-- name, text by text.
local function Lay(texts)
    for name, text in pairs(texts or {}) do
        local there = ns.L[name]
        if type(text) == "table" and type(there) == "table" and not text[1] then
            for part, value in pairs(text) do there[part] = Copy(value) end
        else
            ns.L[name] = Copy(text)
        end
    end
end

-- The game's language, as one of ours; nil when it is not translated.
local function OfGame()
    local code = GetLocale()
    code = SHARED[code] or code
    return languages[code] and code or nil
end

-- Claude's ("fr", said by the plugin with its answers), as one of ours.
local function OfClaude()
    local said = ns.db and ns.db.claudeLanguage
    if not said then return nil end
    for code in pairs(languages) do
        if code:sub(1, 2) == said then return code end
    end
end

-- The language a choice of the player's stands for.
function ns.LanguageOf(choice)
    if languages[choice] then return choice end
    if choice == "game" then return OfGame() or "enUS" end
    return OfClaude() or OfGame() or "enUS"
end

-- The language the texts are in.
function ns.Language()
    return shown
end

local function Show(code)
    shown = code
    for name in pairs(ns.L) do ns.L[name] = nil end
    Lay(languages.enUS)
    if code ~= "enUS" then Lay(languages[code]) end
    for _, fn in ipairs(listeners) do fn() end
end

-- A language's file.
function ns.Locale(code, texts)
    languages[code] = languages[code] or {}
    for name, text in pairs(texts) do languages[code][name] = text end
    Show(OfGame() or "enUS")
end

-- The player's choice, once it is known.
function ns.UseLanguage(choice)
    local code = ns.LanguageOf(choice)
    if code ~= shown then Show(code) end
end

-- Run now, and each time the texts change: for what is made of them beforehand.
function ns.OnLanguage(fn)
    listeners[#listeners + 1] = fn
    fn()
end

-- The languages there are: { { code, name (as they call themselves) } }.
function ns.Languages()
    local list = {}
    for code, texts in pairs(languages) do list[#list + 1] = { code = code, name = texts.LANGUAGE_NAME or code } end
    sort(list, function(a, b) return a.name < b.name end)
    return list
end
