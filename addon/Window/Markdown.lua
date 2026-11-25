-- claude-in-wow: Claude's answers as the Claude window shows them. A small
-- reader of the Markdown Claude writes: paragraphs, headings, lists, quotes,
-- rules, code blocks, and tables as one line per row; inside a line, bold,
-- italics, code and links. A line of game text has one font: bold is drawn
-- brighter, italics dimmer, code in Claude's code colour.
-- Links to the game, which Claude writes for answers pasted here, become the
-- game's own colours and icons, clickable (ClaudeWindow.lua handles them):
--   [name](quest:ID)            a quest, in its difficulty colour
--   [name](item:ID)             an item, its icon and quality colour
--   [x, y](map:UIMAPID:X:Y)     a place: a pin on the map
--   [name](zone:UIMAPID)        a zone: its map
--   [name](npc:ID)              a creature or a character, brighter

local addonName, ns = ...

local concat, floor, format, gmatch, gsub, ipairs, lower, match, pcall, tonumber, tostring =
    table.concat, math.floor, string.format, string.gmatch, string.gsub, ipairs, string.lower, string.match, pcall, tonumber, tostring
local T = ns.Theme

-- Plain text made safe for a font string: "|" is the game's escape character.
function ns.PlainText(text)
    return (gsub(text or "", "|", "||"))
end

----------------------------------------------------------------------
-- Links to the game
----------------------------------------------------------------------

local QUEST_ICON = "|TInterface\\GossipFrame\\AvailableQuestIcon:14:14:0:-1|t "
local QUEST_READY_ICON = "|TInterface\\GossipFrame\\ActiveQuestIcon:14:14:0:-1|t "
local QUEST_DONE_ICON = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:-1|t "

-- The map pin, Claude's line icon in the game's gold.
function ns.PinIcon()
    local r, g, b = T.Color("gold")
    return format("|T%sMapPin:14:14:0:-1:32:32:0:32:0:32:%d:%d:%d|t ", T.ART, floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local function Hex(r, g, b)
    return format("|cff%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local LINKS = {}

-- A quest's title as the game writes it; nil until the game has it: it is asked
-- for, and the window draws again once it comes (QUEST_DATA_LOAD_RESULT).
local function QuestTitle(id)
    local title = ns.Game.QuestTitle(id)
    if title then return title end
    if ns.claudeQuestsDue and ns.claudeQuestsDue[id] == nil then -- asked once
        ns.claudeQuestsDue[id] = ns.Game.LoadQuest(id)
    end
    return nil
end

-- A quest takes the game's title; in the log, its level's colour and the "ready"
-- icon when complete; once handed in, dimmed and ticked.
function LINKS.quest(rest, label)
    local id = tonumber(match(rest, "^(%d+)"))
    if not id then return nil end
    label = QuestTitle(id) or label
    if ns.Game.QuestHandedIn(id) then
        return format("%s|Hciwquest:%d|h%s%s|h|r", T.Code("muted"), id, QUEST_DONE_ICON, label)
    end
    local color, icon = "|cffffff00", QUEST_ICON
    local index = ns.Game.QuestIndex(id)
    local info = index and ns.Game.QuestLine(index)
    if info and info.level and GetQuestDifficultyColor then
        local c = GetQuestDifficultyColor(info.level)
        if c then color = Hex(c.r, c.g, c.b) end
    end
    if index and ns.Game.QuestComplete(id) then icon = QUEST_READY_ICON end
    return format("%s|Hciwquest:%d|h%s%s|h|r", color, id, icon, label)
end

-- Items not in the game's cache yet are asked for; the window draws again
-- once they come (ITEM_DATA_LOAD_RESULT).
function LINKS.item(rest, label)
    local id = tonumber(match(rest, "^(%d+)"))
    if not id then return nil end
    local quality = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id)
    if not quality and C_Item and C_Item.RequestLoadItemDataByID then
        if ns.claudeItemsDue then ns.claudeItemsDue[id] = true end
        C_Item.RequestLoadItemDataByID(id)
    end
    local colors = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    return format("%s|Hciwitem:%d|h%s%s|h|r", colors and colors.hex or "|cffffffff", id,
        icon and format("|T%s:16:16:0:-2:64:64:5:59:5:59|t ", icon) or "", label)
end

function LINKS.map(rest, label)
    local map, x, y = match(rest, "^(%d+):([%d%.]+):([%d%.]+)$")
    if not map then return nil end
    return format("%s|Hciwmap:%s:%s:%s|h%s%s|h|r", T.Code("gold"), map, x, y, ns.PinIcon(), label)
end

function LINKS.zone(rest, label)
    local map = match(rest, "^(%d+)")
    if not map then return nil end
    return ns.ZoneLink(tonumber(map), label) or format("%s|Hciwzone:%s|h%s|h|r", T.Code("gold"), map, label)
end

function LINKS.npc(rest, label)
    local id = match(rest, "^(%d+)")
    if not id then return T.Code("white") .. label .. "|r" end
    return format("%s|Hciwnpc:%s|h%s|h|r", T.Code("white"), id, label)
end

----------------------------------------------------------------------
-- A line
----------------------------------------------------------------------

-- One line's inline marks as the game's colour codes and links. Code and
-- links are set aside first, so that bold and italics leave them alone; then
-- the modules draw the names they know (ns.Decorate). answer: the whole of it.
function ns.MarkdownInline(text, answer)
    text = gsub(ns.PlainText(text), "’", "'") -- as the game writes its names
    local kept = {}
    local function Keep(value)
        kept[#kept + 1] = value
        return "\1" .. #kept .. "\2"
    end
    text = gsub(text, "`([^`]+)`", function(code) return Keep(T.Code("code") .. code .. "|r") end)
    text = gsub(text, "%[([^%]]+)%]%(([^%)]*)%)", function(label, target)
        local kind, rest = match(target, "^(%a+):(.+)$")
        local make = kind and ns.On("gameLinks") and LINKS[lower(kind)]
        local link = make and make(rest, label)
        return link and Keep(link) or label
    end)
    for _, decorator in ipairs(ns.decorators) do
        if ns.On(decorator.key) then
            local ok, drawn = pcall(decorator.draw, text, Keep, answer)
            if ok and drawn then
                text = drawn
            elseif not ok then
                ns.RecordError("claude-in-wow (" .. decorator.key .. "): " .. tostring(drawn), nil, "companion")
            end
        end
    end
    text = gsub(text, "%*%*(.-)%*%*", T.Code("white") .. "%1|r")
    text = gsub(text, "%*([^%*%s][^%*]-)%*", T.Code("secondary") .. "%1|r")
    for _ = 1, 2 do -- twice: a link's label may hold code set aside before it
        text = gsub(text, "\1(%d+)\2", function(index) return kept[tonumber(index)] end)
    end
    return text
end

local function Trim(text)
    return match(text, "^%s*(.-)%s*$")
end

-- A table row "| a | b |" as "a · b"; nil for a separator row.
local function Row(line)
    if match(line, "^[%s|:%-]+$") then return nil end
    local cells = {}
    for cell in gmatch(Trim(line):gsub("^|", ""):gsub("|$", "") .. "|", "([^|]*)|") do
        cells[#cells + 1] = Trim(cell)
    end
    return concat(cells, "  ·  ")
end

-- The blocks of an answer: { kind = "para"|"heading"|"bullet"|"number"|
-- "quote"|"row"|"code"|"rule", text, level, depth, number }.
function ns.Markdown(text)
    local blocks, paragraph, code = {}, nil, nil
    local function Add(block)
        if paragraph then
            blocks[#blocks + 1] = { kind = "para", text = concat(paragraph, " ") }
            paragraph = nil
        end
        if block then blocks[#blocks + 1] = block end
    end

    for line in gmatch((text or "") .. "\n", "([^\n]*)\n") do
        line = gsub(line, "\r$", "")
        local last = blocks[#blocks]
        if code then
            if match(line, "^%s*```") then
                blocks[#blocks + 1] = { kind = "code", text = concat(code, "\n") }
                code = nil
            else
                code[#code + 1] = line
            end
        elseif match(line, "^%s*```") then
            Add()
            code = {}
        elseif match(line, "^%s*$") then
            Add()
        elseif match(line, "^%s*#+%s") then
            local hashes, rest = match(line, "^%s*(#+)%s+(.-)[%s#]*$")
            Add({ kind = "heading", level = #hashes, text = rest })
        elseif #gsub(line, "%s", "") >= 3 and (match(line, "^[%s%-]+$") or match(line, "^[%s%*]+$") or match(line, "^[%s_]+$")) then
            Add({ kind = "rule" })
        elseif match(line, "^%s*[%-%*%+]%s+") then
            local indent, rest = match(line, "^(%s*)[%-%*%+]%s+(.*)$")
            Add({ kind = "bullet", depth = floor(#indent / 2), text = rest })
        elseif match(line, "^%s*%d+[%.%)]%s+") then
            local indent, number, rest = match(line, "^(%s*)(%d+)[%.%)]%s+(.*)$")
            Add({ kind = "number", depth = floor(#indent / 2), number = number, text = rest })
        elseif match(line, "^%s*>") then
            Add({ kind = "quote", text = match(line, "^%s*>%s?(.*)$") })
        elseif match(line, "^%s*|") then
            local row = Row(line)
            Add(row and { kind = "row", text = row } or nil)
        elseif not paragraph and last and (last.kind == "bullet" or last.kind == "number") and match(line, "^%s+%S") then
            last.text = last.text .. " " .. Trim(line) -- a list item going on
        else
            paragraph = paragraph or {}
            paragraph[#paragraph + 1] = Trim(line)
        end
    end
    if code then blocks[#blocks + 1] = { kind = "code", text = concat(code, "\n") } end
    Add()
    return blocks
end

ns.Module({ key = "gameLinks", category = "conversation", group = "GROUP_ANSWERS", order = 10, title = "GAME_LINKS", tip = "GAME_LINKS_TIP" })
