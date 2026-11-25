-- claude-in-wow: the photo. The game writes the saved data only at a
-- reload or logout, but it saves a screenshot at once. So a photo covers the
-- screen with the game state, drawn in the addon's own font, and takes a
-- screenshot of it (in PNG for that one shot, then the player's format
-- again): the assistant app reads the data back from the picture. A question
-- sent from the Claude window travels in a photo too.
--
-- The picture, white on black from the top-left corner: each character of
-- the data in base64 is a glyph, a bar over 3 x 2 cells of 3 pixels. Row 0
-- is a header, then the data (JSON, deflated for a compact photo, the option
-- on by default: then only a band at the top goes black). The app's reader
-- (photo.mjs) describes it in full.

local addonName, ns = ...

local byte, concat, floor, format, ipairs, max, pairs = string.byte, table.concat, math.floor, string.format, ipairs, math.max, pairs
local rep, sort, sub, tostring, type = string.rep, table.sort, string.sub, tostring, type
local L = ns.L

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local FONT = "Interface\\AddOns\\" .. addonName .. "\\Media\\Photo.ttf"
local SIZE = 8          -- the font's size in pixels: a glyph is 9 x 8, cells of 3
local MARGIN = 4        -- pixels around
local HEADER_BYTES = 72
local KEEP_FRAMES = 2   -- frames the page stays once the game starts the screenshot
local MAX_ERRORS = 10
local MAX_STACK = 600
local PARTS = { character = true, location = true, group = true, professions = true, quests = true, bags = true, equipment = true, marks = true }

----------------------------------------------------------------------
-- Encoding
----------------------------------------------------------------------

local CHARS = {}
for value = 0, 63 do CHARS[value] = sub(ALPHABET, value + 1, value + 1) end

-- Base64 without padding: the header gives the length.
local function Base64(text)
    local out = {}
    for index = 1, #text, 3 do
        local a, b, c = byte(text, index, index + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        out[#out + 1] = CHARS[floor(n / 262144)] .. CHARS[floor(n / 4096) % 64] .. CHARS[floor(n / 64) % 64] .. CHARS[n % 64]
    end
    return concat(out)
end

local function Adler32(text)
    local a, b = 1, 0
    for index = 1, #text do
        a = (a + byte(text, index)) % 65521
        b = (b + a) % 65521
    end
    return b * 65536 + a
end

local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function Escape(char)
    return ESCAPES[char] or format("\\u%04x", byte(char))
end

-- JSON of a saved-data value: a table with keys 1..n (or empty) is an array,
-- any other an object; what JSON cannot hold becomes null.
local function Json(value, out)
    local kind = type(value)
    if kind == "string" then
        out[#out + 1] = '"' .. value:gsub('[%c"\\]', Escape) .. '"'
    elseif kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            out[#out + 1] = "null"
        elseif value == floor(value) and value > -1e15 and value < 1e15 then
            out[#out + 1] = format("%.0f", value) -- "%d" stops at 2^31 in some Lua builds
        else
            out[#out + 1] = format("%.14g", value)
        end
    elseif kind == "boolean" then
        out[#out + 1] = tostring(value)
    elseif kind == "table" then
        local count = 0
        for _ in pairs(value) do count = count + 1 end
        if count == #value then
            out[#out + 1] = "["
            for index = 1, count do
                if index > 1 then out[#out + 1] = "," end
                Json(value[index], out)
            end
            out[#out + 1] = "]"
        else
            local keys = {}
            for key in pairs(value) do keys[#keys + 1] = tostring(key) end
            sort(keys)
            out[#out + 1] = "{"
            for index, key in ipairs(keys) do
                if index > 1 then out[#out + 1] = "," end
                local item = value[key]
                if item == nil then item = value[tonumber(key)] end
                Json(key, out)
                out[#out + 1] = ":"
                Json(item, out)
            end
            out[#out + 1] = "}"
        end
    else
        out[#out + 1] = "null"
    end
end

-- The game state now, as the snapshot notes it (the addons' list aside:
-- it only changes at a reload), with the last Lua errors, and the question
-- sent from the Claude window when there is one ({ id, kind, text, at, read }).
local function PhotoData(question)
    local char = ns.Collect({}, PARTS)
    char.bank = ns.char and ns.char.bank

    local errors = {}
    for index, entry in ipairs(ns.db and ns.db.errors or {}) do
        if index > MAX_ERRORS then break end
        errors[index] = {
            message = entry.message, time = entry.time, count = entry.count, kind = entry.kind, character = entry.character,
            stack = entry.stack and sub(entry.stack, 1, MAX_STACK) or nil,
        }
    end

    local out = {}
    Json({
        version = ns.VERSION,
        game = ns.db and ns.db.game,
        key = ns.key,
        savedAt = time(),
        character = char,
        errors = errors,
        warbandBank = ns.db and ns.db.warbandBank,
        question = question,
        spare = ns.SpareChannels(),
    }, out)
    return concat(out)
end

----------------------------------------------------------------------
-- The picture
----------------------------------------------------------------------

local frame, lines, state

-- The game gets a font file ready while the interface loads: one first asked
-- for later is not, and setting it fails. So the photo's font is asked for
-- now, off screen.
do
    local preload = CreateFrame("Frame")
    preload:SetPoint("TOP", UIParent, "BOTTOM", 0, -5000)
    preload:SetSize(100, 100)
    local text = preload:CreateFontString()
    text:SetAllPoints()
    if pcall(text.SetFont, text, FONT, SIZE, "MONOCHROME") then pcall(text.SetText, text, "/A") end
end

local function Line(index)
    local line = lines[index]
    if not line then
        line = frame:CreateFontString(nil, "OVERLAY")
        line:SetFont(FONT, SIZE, "MONOCHROME")
        line:SetTextColor(1, 1, 1, 1)
        line:SetShadowOffset(0, 0)
        line:SetShadowColor(0, 0, 0, 0)
        line:SetJustifyH("LEFT")
        line:SetJustifyV("TOP")
        line:SetWordWrap(false)
        lines[index] = line
    end
    return line
end

-- Parentless, so it shows with the interface hidden too (Alt+Z), on top of
-- everything; scaled so that one unit is one pixel of the screen.
local function Build()
    frame = CreateFrame("Frame")
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(10000)
    frame:SetAllPoints(UIParent)
    frame.black = frame:CreateTexture(nil, "BACKGROUND")
    frame.black:SetColorTexture(0, 0, 0, 1)
    lines = {}
    frame:Hide()
end

-- Sizes in pixels, the font measured: nil when it is not there.
local function Measure()
    local width, height = GetPhysicalScreenSize()
    frame:SetScale(768 / height)
    local probe = Line(1)
    pcall(probe.SetFont, probe, FONT, SIZE, "MONOCHROME") -- again, in case it was not ready before
    local ok = pcall(probe.SetText, probe, rep("/A", 20)) -- fails without the font
    local advance = ok and (probe:GetStringWidth() or 0) / 40 or 0
    if advance < 2 then return nil end
    local pitch = max(SIZE, math.ceil((probe:GetStringHeight() or 0) - 0.01))
    local perRow = floor((width - 2 * MARGIN) / advance / 4) * 4
    local rows = floor((height - 2 * MARGIN) / pitch) - 1 -- under the header
    if perRow < HEADER_BYTES / 3 * 4 or rows < 1 then return nil end -- a screen too small for the header
    return { width = width, height = height, pitch = pitch, perRow = perRow, rows = rows }
end

-- The data cut into pages, each a screen.
local function Pages(data, size)
    local perPage = floor(size.perRow * size.rows / 4) * 3
    local pages = {}
    for start = 1, max(#data, 1), perPage do pages[#pages + 1] = sub(data, start, start + perPage - 1) end
    return pages
end

-- A page: its header and rows, on black behind them only (a compact photo)
-- or on the whole screen.
local function Draw(size, id, page, pages, chunk, encoding, compact)
    local encoded = Base64(chunk)
    local rows = math.ceil(#encoded / size.perRow)
    local header = format("CIW1 %.0f %d %d %d %d %d %.0f %d %s %d %d", id, page, pages, size.perRow, rows, #chunk, Adler32(chunk),
        size.pitch, encoding, size.width, size.height)
    header = header .. rep(" ", HEADER_BYTES - #header)

    frame.black:ClearAllPoints()
    frame.black:SetPoint("TOPLEFT")
    frame.black:SetPoint("TOPRIGHT")
    if compact then
        frame.black:SetHeight(2 * MARGIN + (rows + 1) * size.pitch)
    else
        frame.black:SetPoint("BOTTOM")
    end

    local texts = { Base64(header) }
    for row = 1, rows do texts[#texts + 1] = sub(encoded, (row - 1) * size.perRow + 1, row * size.perRow) end

    for index, text in ipairs(texts) do
        local line = Line(index)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, -(MARGIN + (index - 1) * size.pitch))
        line:SetText(text)
        line:Show()
    end
    for index = #texts + 1, #lines do lines[index]:Hide() end
end

----------------------------------------------------------------------
-- Taking it
----------------------------------------------------------------------

local events = CreateFrame("Frame")

local function Say(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff4ec9b0claude-in-wow|r " .. text)
end

-- The photo done or failed: said in the chat, and told to whoever asked for
-- it (done(ok)).
local function Finish(message, ok)
    if not state then return end
    local done = state.done
    frame:Hide()
    frame:SetScript("OnUpdate", nil)
    events:UnregisterAllEvents()
    SetCVar("screenshotFormat", state.shotFormat)
    state = nil
    Say(message)
    if done then done(ok) end
end

-- Shows a page and takes its screenshot once it has been drawn. The game says
-- SCREENSHOT_STARTED just before it grabs the screen: the page goes a few
-- frames later, not once the file is written (half a second for a PNG).
-- Without that event, it stays until the file is there.
local function Shoot()
    local s = state
    Draw(s.size, s.id, s.page, #s.pages, s.pages[s.page], s.encoding, s.compact)
    frame:Show()
    s.drawn, s.started = 0, nil
    frame:SetScript("OnUpdate", function(self)
        s.drawn = s.drawn + 1
        if s.drawn == 2 then
            Screenshot()
        elseif s.started and s.drawn >= s.started + KEEP_FRAMES then
            self:SetScript("OnUpdate", nil)
            self:Hide()
        end
    end)
    local page = s.page
    C_Timer.After(10, function()
        if state == s and s.page == page then Finish(L.PHOTO_FAILED) end
    end)
end

events:SetScript("OnEvent", function(_, event)
    local s = state
    if not s then return end
    if event == "SCREENSHOT_STARTED" then
        s.started = s.drawn
    elseif event == "SCREENSHOT_FAILED" then
        Finish(L.PHOTO_FAILED)
    elseif s.page < #s.pages then
        -- the next page a second later: screenshots are named by the second
        frame:Hide()
        s.page = s.page + 1
        C_Timer.After(1.1, function() if state == s then Shoot() end end)
    elseif s.question then
        Finish(L.QUESTION_SENT, true)
    else
        Finish(#s.pages > 1 and format(L.PHOTO_TAKEN_PAGES, #s.pages) or L.PHOTO_TAKEN, true)
    end
end)

-- Takes a photo, with a question from the Claude window in it when given;
-- done(ok) is called once it is taken or has failed. False when it cannot
-- be taken now (in combat, another one under way, the font missing).
function ns.TakePhoto(question, done)
    if state then return false end
    if InCombatLockdown() then
        Say(L.PHOTO_COMBAT)
        return false
    end
    if not frame then Build() end

    local size = Measure()
    if not size then
        Say(L.PHOTO_NO_FONT)
        return false
    end

    -- compact: the JSON deflated, about a third of its size
    local data, encoding = PhotoData(question), "json"
    local compact = ns.db.options.compactPhoto and LibStub and LibStub("LibDeflate", true)
    if compact then
        data, encoding = compact:CompressDeflate(data, { level = 5 }), "deflate"
    end

    GameTooltip:Hide()
    state = {
        size = size, id = time(), page = 1, pages = Pages(data, size), encoding = encoding, compact = compact and true,
        shotFormat = GetCVar("screenshotFormat"), question = question, done = done,
    }
    SetCVar("screenshotFormat", "png")
    events:RegisterEvent("SCREENSHOT_SUCCEEDED")
    events:RegisterEvent("SCREENSHOT_FAILED")
    pcall(events.RegisterEvent, events, "SCREENSHOT_STARTED") -- not in every game version
    Shoot()
    return true
end

----------------------------------------------------------------------
-- The module
----------------------------------------------------------------------

ns.Module({
    key = "photo", category = "questions", order = 10, fixed = true, title = "PHOTO_MODULE", tip = "PHOTO_MODULE_TIP",
    settings = {
        { key = "sendByPhoto", label = "OPTION_PHOTO", tip = "OPTION_PHOTO_TIP", default = true },
        { key = "compactPhoto", label = "OPTION_COMPACT", tip = "OPTION_COMPACT_TIP", default = true },
    },
})
