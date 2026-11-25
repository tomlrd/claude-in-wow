-- claude-in-wow: how the conversation reads, as the player sets it (the settings'
-- tab on the window): the margins around it, the font and the size of Claude's
-- answers and of your questions, with an example, as the conversation is hidden
-- behind the settings. ClaudeWindow.lua draws with ns.AnswerLook and ns.QuestionLook.

local addonName, ns = ...

local floor, ipairs, max, min = math.floor, ipairs, math.max, math.min
local L, T = ns.L, ns.Theme

local SIZES = { 9, 24, 1, " pt" }
local BUBBLE_X, BUBBLE_Y = 16, 11 -- around your message
local BUBBLE_WIDTH = 0.8          -- of the conversation's, at most

-- The fonts to choose from (label: a name, or a text's): their text's and their titles' (Theme.lua).
local FONTS = {
    { value = "skin", label = "LOOK_SKIN", text = "sans", titles = "sansMedium" },
    { value = "interFont", label = "LOOK_INTER", text = "inter", titles = "interMedium" },
    { value = "serif", label = "Noto Serif", text = "serif", titles = "serifBold" },
    { value = "mono", label = "Fira Mono", text = "monoText", titles = "monoText" },
    { value = "game", label = "LOOK_GAME", text = "game", titles = "game" },
    { value = "narrow", label = "Arial Narrow", text = "narrow", titles = "narrow" },
    { value = "morpheus", label = "Morpheus", text = "morpheus", titles = "morpheus" },
    { value = "skurri", label = "Skurri", text = "skurri", titles = "skurri" },
    { value = "ptSans", label = "PT Sans Narrow", text = "ptSans", titles = "ptSans" },
}

local function Font(value)
    for _, font in ipairs(FONTS) do
        if font.value == value then return font end
    end
    return FONTS[1]
end

-- The text's font, the titles', the size.
function ns.AnswerLook()
    local font = Font(ns.db.options.answerFont)
    return font.text, font.titles, ns.db.options.answerSize
end

function ns.QuestionLook()
    local font = Font(ns.db.options.questionFont)
    return font.text, font.titles, ns.db.options.questionSize
end

-- The margins around the conversation: on its sides, at its ends.
function ns.ConversationMargins()
    return ns.db.options.marginSides, ns.db.options.marginEnds
end

-- A text set in a font string of this width; its height.
function ns.FillText(text, face, size, color, width, content)
    T.SetFont(text, face, size)
    text:SetTextColor(T.Color(color))
    text:SetSpacing(face == "mono" and 2 or 4)
    text:SetWidth(width)
    text:SetText(content)
    return text:GetStringHeight() or size
end

-- Your message in its bubble, on the right of a frame this wide: its height.
function ns.NewBubble(parent)
    local bubble = CreateFrame("Frame", nil, parent)
    T.Box(bubble, 14, "bubble")
    bubble.text = T.Text(bubble, "sans", 14, "body")
    bubble.text:SetPoint("TOPLEFT", BUBBLE_X, -BUBBLE_Y)
    function bubble:Fill(content, width)
        local face, _, size = ns.QuestionLook()
        local sides = ns.ConversationMargins()
        local most = max(60, floor((width - 2 * sides) * BUBBLE_WIDTH)) - 2 * BUBBLE_X
        local text = self.text
        ns.FillText(text, face, size, "body", most, content)
        local textWidth = min(T.TextWidth(text) + 2, most)
        text:SetWidth(textWidth)
        local height = (text:GetStringHeight() or size) + 2 * BUBBLE_Y
        self:ClearAllPoints()
        self:SetPoint("TOPRIGHT", self:GetParent(), "TOPRIGHT", -sides, 0)
        self:SetSize(textWidth + 2 * BUBBLE_X, height)
        return height
    end
    return bubble
end

-- An example: a question and its answer, in the margins.
local function Example(parent)
    local frame = CreateFrame("Frame", nil, parent)
    T.Box(frame, 10, "none", "border")
    local inner = CreateFrame("Frame", nil, frame)
    local bubble = ns.NewBubble(inner)
    local answer = T.Text(inner, "sans", 14, "body")
    function frame:Refresh(width)
        local sides, ends = ns.ConversationMargins()
        local height = bubble:Fill(L.LOOK_QUESTION, width)
        local face, _, size = ns.AnswerLook()
        answer:ClearAllPoints()
        answer:SetPoint("TOPLEFT", sides, -height - 16)
        height = height + 16 + ns.FillText(answer, face, size, "body", max(60, width - 2 * sides), L.LOOK_ANSWER)
        inner:SetPoint("TOPLEFT", 0, -ends)
        inner:SetPoint("TOPRIGHT", 0, -ends)
        inner:SetHeight(height)
        self:SetSize(width, height + 2 * ends)
        return height + 2 * ends
    end
    return frame
end

local function FontName(value)
    local label = Font(value).label
    return L[label] or label
end

local function Fonts()
    local list = {}
    for index, font in ipairs(FONTS) do list[index] = { value = font.value, label = FontName(font.value) } end
    return list
end

ns.Module({
    key = "look", category = "window", order = 11, fixed = true, title = "LOOK", tip = "LOOK_TIP", custom = Example,
    settings = {
        { key = "marginSides", label = "LOOK_SIDES", default = 18, slider = { 0, 80, 2, " px" } },
        { key = "marginEnds", label = "LOOK_ENDS", default = 8, slider = { 0, 60, 2, " px" } },
        { key = "answerFont", label = "LOOK_ANSWER_FONT", default = "skin", choices = Fonts, shown = FontName },
        { key = "answerSize", label = "LOOK_ANSWER_SIZE", default = 14, slider = SIZES },
        { key = "questionFont", label = "LOOK_QUESTION_FONT", default = "skin", choices = Fonts, shown = FontName },
        { key = "questionSize", label = "LOOK_QUESTION_SIZE", default = 14, slider = SIZES },
    },
})
