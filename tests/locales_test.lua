-- Checks the addon's languages (Locales): no unknown name, each %s and %d there, lists as
-- long as the English ones; every text the addon uses is in English; and what each
-- language has not translated yet.
-- lua locales_test.lua <addon folder> [a language, to list what it lacks]

local folder, shown = arg and arg[1] or ..., arg and arg[2]
local LANGUAGES = { "frFR", "deDE", "esES", "itIT" }
local failed, passed = 0, 0

local function Read(code)
    local found
    local ns = { Locale = function(_, texts) found = texts end }
    assert(loadfile(folder .. "/Locales/" .. code .. ".lua"))("claude-in-wow", ns)
    return found
end

local function Fail(code, name, why)
    failed = failed + 1
    print(("FAIL %s %s: %s"):format(code, name, why))
end

-- What a text is filled with, sorted: "%2$s" counts as "%s".
local function Fills(text)
    local list = {}
    for fill in text:gsub("%%%%", ""):gmatch("%%%d?%$?[%d%.]*(%a)") do list[#list + 1] = fill end
    table.sort(list)
    return table.concat(list, " ")
end

local function Check(code, name, english, text)
    if type(text) ~= type(english) then return Fail(code, name, "a " .. type(text) .. " for a " .. type(english)) end
    if name:find("_WORDS$") then return end -- the words of a command: each language adds its own
    if type(text) == "table" then
        if #text ~= #english then return Fail(code, name, #text .. " lines for " .. #english) end
        for part, value in pairs(text) do
            if english[part] == nil then Fail(code, name .. "." .. tostring(part), "not in English") else Check(code, name .. "." .. tostring(part), english[part], value) end
        end
    elseif type(text) == "string" and Fills(text) ~= Fills(english) then
        return Fail(code, name, ("filled with \"%s\" for \"%s\""):format(Fills(text), Fills(english)))
    end
    passed = passed + 1
end

local ENGLISH = Read("enUS")
local total = 0
for _ in pairs(ENGLISH) do total = total + 1 end
for _, code in ipairs(LANGUAGES) do
    local texts, lacks = Read(code), {}
    for name, text in pairs(texts) do
        if ENGLISH[name] == nil then Fail(code, name, "not in English") else Check(code, name, ENGLISH[name], text) end
    end
    for name in pairs(ENGLISH) do
        if texts[name] == nil then lacks[#lacks + 1] = name end
    end
    table.sort(lacks)
    print(("%s: %d of %d texts, %d in English"):format(code, total - #lacks, total, #lacks))
    if shown == code then print("  " .. table.concat(lacks, " ")) end
end

-- every text asked for by its name in the code
local asked = {}
for line in io.lines(folder .. "/claude-in-wow.toc") do
    local file = line:match("^([%w\\%.]+%.lua)%s*$")
    if file and not file:find("^Libs") and not file:find("^Locales") then
        local handle = assert(io.open(folder .. "/" .. file:gsub("\\", "/")))
        local code = handle:read("*a")
        handle:close()
        code = code:gsub("%-%-[^\n]*", "")
        for name in code:gmatch("%f[%w_]L%.([A-Z][A-Z0-9_]*)") do asked[name] = file end
        for name in code:gmatch('%f[%w_]title = "([A-Z][A-Z0-9_]+)"') do asked[name] = file end
        for name in code:gmatch('%f[%w_]tip = "([A-Z][A-Z0-9_]+)"') do asked[name] = file end
        for name in code:gmatch('%f[%w_]label = "([A-Z][A-Z0-9_]+)"') do asked[name] = file end
    end
end
for name, file in pairs(asked) do
    if ENGLISH[name] == nil then Fail("enUS", name, "used in " .. file .. ", not there") else passed = passed + 1 end
end
print(passed .. " passed, " .. failed .. " failed")
