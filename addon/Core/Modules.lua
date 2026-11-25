-- claude-in-wow: its modules. A module is a feature in a file of its own
-- (Modules\), which declares itself, with its settings; its texts, here by their
-- names, are in Locales\enUS.lua and the other languages' files:
--   ns.Module({
--       key = "hello",              -- its switch, ns.db.options.hello
--       category = "conversation",  -- its tab in the settings (ns.Category)
--       order = 10,                 -- its place there
--       group = "GROUP_TEXT",       -- a heading over it and those of the same group next to it, when the tab has some
--       title = "HELLO", tip = "HELLO_TIP",
--       default = true,             -- on at first (true when not said)
--       fixed = false,              -- true: always on, no switch
--       warning = function() end,   -- a text in place of the tip, when something is amiss
--       changed = function(on) end, -- switched in the settings
--       settings = {                -- each in ns.db.options by its key
--           { key = "helloLoud", label = "HELLO_LOUD", tip = "HELLO_LOUD_TIP", default = false },         -- a switch
--           { key = "helloSize", ..., default = 100, slider = { 20, 200, 5[, " px"] } },                  -- a slider
--           { key = "helloKind", ..., default = "a", choices = function() return { { value, label, detail } } end }, -- a menu
--       },                          -- each may have changed(value) and warning()
--       custom = function(parent) end, -- anything else under them: { Refresh(self, width) -> height }
--   })
-- and does nothing while ns.On("hello") is false. What modules share:
--   ns.Decorate(key, function(text, keep, answer) ... end): draws names in
--     Claude's answers (Window\Markdown.lua), while the module is on.
--   ns.LinkKind("kind", { enter, click }): its links "|Hciwkind:...|h".

local addonName, ns = ...

local ipairs, pairs, sort = ipairs, pairs, table.sort
local L = ns.L

----------------------------------------------------------------------
-- Categories and modules
----------------------------------------------------------------------

local categories, modules, settings = {}, {}, {}

-- A tab of the settings: key, title (a text's key), order.
function ns.Category(category)
    categories[#categories + 1] = category
end

function ns.Categories()
    sort(categories, function(a, b) return a.order < b.order end)
    return categories
end

function ns.Module(module)
    modules[#modules + 1] = module
    for _, setting in ipairs(module.settings or {}) do settings[setting.key] = setting end
    return module
end

-- A category's modules, in order.
function ns.ModulesOf(category)
    local list = {}
    for _, module in ipairs(modules) do
        if module.category == category then list[#list + 1] = module end
    end
    sort(list, function(a, b) return (a.order or 100) < (b.order or 100) end)
    return list
end

-- Whether a module (or a setting that is a switch) is on.
function ns.On(key)
    local options = ns.db and ns.db.options
    return options and options[key] and true or false
end

-- The modules the player turned off, by key.
function ns.ModulesOff()
    local list = {}
    for _, module in ipairs(modules) do
        if not module.fixed and not ns.On(module.key) then list[#list + 1] = module.key end
    end
    sort(list)
    return #list > 0 and list or nil
end

-- The settings not chosen yet (Core.lua, once the saved data is there).
function ns.ModuleDefaults(options)
    for _, module in ipairs(modules) do
        if not module.fixed and options[module.key] == nil then options[module.key] = module.default ~= false end
        for _, setting in ipairs(module.settings or {}) do
            if options[setting.key] == nil then options[setting.key] = setting.default end
        end
    end
end

-- A setting changed by the player.
function ns.SetOption(key, value)
    ns.db.options[key] = value
    local setting = settings[key]
    if setting and setting.changed then setting.changed(value) end
    for _, module in ipairs(modules) do
        if module.key == key and not module.fixed and module.changed then module.changed(value) end
    end
    ns.RenderClaude()
end

-- A setting with choices: what it shows, and its menu, the one in use ticked.
function ns.ChoiceLabel(key)
    local setting, value = settings[key], ns.db.options[key]
    if setting.shown then return setting.shown(value) end
    for _, choice in ipairs(setting.choices()) do
        if choice.value == value then return choice.label end
    end
    return ""
end

function ns.ChoiceEntries(key)
    local entries = {}
    for index, choice in ipairs(settings[key].choices()) do
        entries[index] = {
            icon = choice.value == ns.db.options[key] and "Check" or nil, label = choice.label, detail = choice.detail,
            run = function() ns.SetOption(key, choice.value) end,
        }
    end
    return entries
end

----------------------------------------------------------------------
-- What modules share
----------------------------------------------------------------------

ns.decorators = {} -- { key, draw }, in the order they came
function ns.Decorate(key, draw)
    ns.decorators[#ns.decorators + 1] = { key = key, draw = draw }
end

ns.linkKinds = {}
function ns.LinkKind(kind, handlers)
    ns.linkKinds[kind] = handlers
end

----------------------------------------------------------------------
-- The settings' tabs
----------------------------------------------------------------------

ns.Category({ key = "claude", title = "TAB_CLAUDE", order = 10 })
ns.Category({ key = "questions", title = "TAB_QUESTIONS", order = 20 })
ns.Category({ key = "answers", title = "TAB_ANSWERS", order = 30 })
ns.Category({ key = "conversation", title = "TAB_CONVERSATION", order = 40 })
-- What the player may take from Claude: a module with limit = true is on at
-- first, and shows there as "Do not ...", unticked.
ns.Category({ key = "limits", title = "TAB_LIMITS", order = 45 })
ns.Category({ key = "window", title = "TAB_WINDOW", order = 60 })
ns.Category({ key = "about", title = "TAB_ABOUT", order = 70 })
