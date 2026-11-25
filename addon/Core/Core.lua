-- claude-in-wow: saved data and shared helpers.
--
-- ClaudeInWoWDB = {
--     version = 1,
--     characters = { ["First Last"] = { savedAt, character, location, group, professions,
--                    quests, questsNotListed, bags, bank, equipment, addons,
--                    world (World.lua), marks (Marks.lua), chat (ClaudeWindow.lua) } },
--     errors = { newest first: { message, stack, time, count, character, kind } },
--     options = each module's and each setting's own (Modules.lua),
--     claude = the Claude window's place and size (ClaudeWindow.lua),
--     minimap = its button's place (MinimapButton.lua),
-- }
-- An app outside the game reads this file: the game writes it on /reload and
-- on logout only.

local addonName, ns = ...

local format, gsub, match, tonumber, tostring = string.format, string.gsub, string.match, tonumber, tostring
local ipairs, pcall = ipairs, pcall

ns.VERSION = 1

local issecret = issecretvalue or function() return false end

-- A value safe to keep: secret values (combat) become nil.
function ns.Clean(value)
    if issecret(value) then return nil end
    return value
end

-- "|4singular:plural;" grammar codes: the form the number before it calls for.
local function Grammar(number, between, singular, plural)
    return number .. between .. (tonumber(number) == 1 and singular or plural)
end

-- "|cff...|r" colours, "|T...|t" textures and "|A...|a" atlases out of a text,
-- grammar codes resolved.
function ns.StripCodes(text)
    if type(text) ~= "string" then return text end
    text = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = gsub(text, "|c[nN][^:]*:", "")
    text = gsub(text, "|r", "")
    text = gsub(text, "|T.-|t", "")
    text = gsub(text, "|A.-|a", "")
    text = gsub(text, "(%d+)([^|%d]*)|4([^:;]*):([^;]*);", Grammar)
    text = gsub(text, "|4([^:;]*):[^;]*;", "%1")
    return text
end

function ns.LinkName(link)
    return type(link) == "string" and match(link, "|h%[(.-)%]|h") or nil
end

function ns.LinkID(link)
    return type(link) == "string" and tonumber(match(link, "item:(%-?%d+)")) or nil
end

-- The character's first and last names: Forever has no realms, each name is
-- unique in the region ("Arden Valcourt"). Nil elsewhere.
function ns.Surname()
    if not (RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() and UnitNameUnmodified) then return nil end
    local name, surname = UnitNameUnmodified("player")
    if surname and surname ~= "" then return name, surname end
    return nil
end

-- The character's key in the saved data: "First Last" on Forever,
-- else "Name - Realm".
function ns.CharacterKey()
    local name, surname = ns.Surname()
    if surname then return format("%s %s", name, surname) end

    local realm = GetRealmName()
    if realm and realm ~= "" then return format("%s - %s", tostring(UnitName("player")), realm) end
    return tostring(UnitName("player"))
end

-- Collectors fill the character's table at each snapshot (Main.lua), and a
-- fresh table for a question prepared in the game (Ask.lua).
ns.collectors = {}
function ns.AddCollector(name, collect)
    ns.collectors[#ns.collectors + 1] = { name = name, collect = collect }
end

-- Runs the collectors into target, each in its own pcall so that one failing
-- never loses the others; only the ones named in names (a set) when given.
function ns.Collect(target, names)
    for _, collector in ipairs(ns.collectors) do
        if not names or names[collector.name] then
            local ok, err = pcall(collector.collect, target)
            if not ok then
                ns.RecordError(format("claude-in-wow (%s): %s", collector.name, tostring(err)), nil, "companion")
            end
        end
    end
    return target
end

function ns.InitDB()
    local db = ClaudeInWoWDB
    if type(db) ~= "table" then
        db = {}
        ClaudeInWoWDB = db
    end

    db.version = ns.VERSION
    db.game = { flavor = ns.Game.flavor, title = ns.Game.title, version = ns.Game.version, interface = ns.Game.interface, locale = GetLocale() }
    db.characters = db.characters or {}
    db.options = db.options or {}
    ns.ModuleDefaults(db.options)
    db.errors = db.errors or {}

    ns.db = db
    ns.UseLanguage(db.options.language)
    ns.key = ns.CharacterKey()

    db.characters[ns.key] = db.characters[ns.key] or {}
    ns.char = db.characters[ns.key]
    return db
end
