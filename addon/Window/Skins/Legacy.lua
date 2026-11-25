-- claude-in-wow skin: the game's own look. Its metal window on its stone, its red
-- buttons, check boxes and sliders (the templates of the version played, so each has
-- its own art), its tooltips' border around boxes and menus, its gold line under the
-- mouse, its font and its colours.

local addonName, ns = ...

local ipairs, pairs, pcall, unpack = ipairs, pairs, pcall, unpack or table.unpack
local T = ns.Theme

local WHITE = "Interface\\Buttons\\WHITE8X8"
local ROCK = "Interface\\FrameGeneral\\UI-Background-Rock"
local LIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local EDGE, INSET = 14, 3

-- The tooltips' border, cut as the game cuts it (Backdrop.lua): a corner's or a
-- side's four points in the picture.
local PIECES = {
    TOPLEFT = { 0.5078125, 0.0625, 0.5078125, 0.9375, 0.6171875, 0.0625, 0.6171875, 0.9375 },
    TOPRIGHT = { 0.6328125, 0.0625, 0.6328125, 0.9375, 0.7421875, 0.0625, 0.7421875, 0.9375 },
    BOTTOMLEFT = { 0.7578125, 0.0625, 0.7578125, 0.9375, 0.8671875, 0.0625, 0.8671875, 0.9375 },
    BOTTOMRIGHT = { 0.8828125, 0.0625, 0.8828125, 0.9375, 0.9921875, 0.0625, 0.9921875, 0.9375 },
    TOP = { 0.2578125, 0.9375, 0.3671875, 0.9375, 0.2578125, 0.0625, 0.3671875, 0.0625 },
    BOTTOM = { 0.3828125, 0.9375, 0.4921875, 0.9375, 0.3828125, 0.0625, 0.4921875, 0.0625 },
    LEFT = { 0.0078125, 0.0625, 0.0078125, 0.9375, 0.1171875, 0.0625, 0.1171875, 0.9375 },
    RIGHT = { 0.1328125, 0.0625, 0.1328125, 0.9375, 0.2421875, 0.0625, 0.2421875, 0.9375 },
}

local function Border(frame, layer)
    local parts = {}
    local function Piece(name)
        local piece = frame:CreateTexture(nil, layer, nil, 3)
        piece:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
        piece:SetTexCoord(unpack(PIECES[name]))
        parts[#parts + 1] = piece
        return piece
    end
    local corners = {}
    for _, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local corner = Piece(point)
        corner:SetSize(EDGE, EDGE)
        corner:SetPoint(point)
        corners[point] = corner
    end
    for side, ends in pairs({
        TOP = { "TOPLEFT", "TOPRIGHT", "TOPRIGHT", "BOTTOMLEFT" }, BOTTOM = { "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT", "BOTTOMLEFT" },
        LEFT = { "TOPLEFT", "BOTTOMLEFT", "BOTTOMLEFT", "TOPRIGHT" }, RIGHT = { "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "TOPRIGHT" },
    }) do
        local piece = Piece(side)
        piece:SetPoint("TOPLEFT", corners[ends[1]], ends[2])
        piece:SetPoint("BOTTOMRIGHT", corners[ends[3]], ends[4])
    end
    return parts
end

-- The window: the metal frame around the stone, which the opacity fades.
local function Window(frame, layer)
    local rock = frame:CreateTexture(nil, layer, nil, 1)
    rock:SetTexture(ROCK, "REPEAT", "REPEAT")
    rock:SetHorizTile(true)
    rock:SetVertTile(true)
    rock:SetPoint("TOPLEFT", 3, -3)
    rock:SetPoint("BOTTOMRIGHT", -3, 3)
    local metal = CreateFrame("Frame", nil, frame)
    metal:SetAllPoints()
    metal:SetFrameLevel(frame:GetFrameLevel() + 1)
    local done = NineSliceUtil and pcall(NineSliceUtil.ApplyLayoutByName, metal, "ButtonFrameTemplateNoPortrait")
    if not done then Border(frame, "BORDER") end
    frame.paintBox = function(_, fill)
        local _, _, _, alpha = T.Color(fill or "page")
        rock:SetAlpha(alpha)
    end
end

-- A row or a tab: the game's gold light, under the mouse or on the one shown.
local function Light(frame, layer)
    local light = frame:CreateTexture(nil, layer, nil, 1)
    light:SetTexture(LIGHT)
    light:SetBlendMode("ADD")
    light:SetAllPoints()
    frame.paintBox = function(_, fill)
        local _, _, _, alpha = T.Color(fill or "none")
        light:SetShown(alpha > 0)
        light:SetAlpha(fill == "field" and 0.8 or 0.4)
    end
end

local function Box(frame, _, _, border, layer, role)
    if role == "window" then return Window(frame, layer) end
    if not border and role ~= "send" then return Light(frame, layer) end
    local fill = frame:CreateTexture(nil, layer, nil, 1)
    fill:SetTexture(WHITE)
    fill:SetPoint("TOPLEFT", INSET, -INSET)
    fill:SetPoint("BOTTOMRIGHT", -INSET, INSET)
    frame.boxFill, frame.boxBorder = { fill }, Border(frame, layer)
end

-- The game's check box.
local function Switch(switch)
    switch:SetSize(26, 26)
    local function Picture(file, layer)
        local picture = switch:CreateTexture(nil, layer)
        picture:SetTexture("Interface\\Buttons\\UI-CheckBox-" .. file)
        picture:SetAllPoints()
        return picture
    end
    Picture("Up", "BACKGROUND")
    Picture("Highlight", "HIGHLIGHT"):SetBlendMode("ADD")
    local check = Picture("Check", "OVERLAY")
    return function(_, on) check:SetShown(on) end
end

-- The game's slider, where its template is missing.
local function Slider(slider)
    local groove = CreateFrame("Frame", nil, slider)
    groove:SetAllPoints()
    groove:SetFrameLevel(slider:GetFrameLevel())
    T.Box(groove, 0, "field", "border")
    local knob = slider:CreateTexture(nil, "OVERLAY")
    knob:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    knob:SetSize(32, 32)
    slider:SetThumbTexture(knob)
end

-- The game's thin scroll bar.
local function Thumb(scroll)
    local thumb = CreateFrame("Frame", nil, scroll)
    thumb:SetWidth(8)
    thumb:SetFrameLevel(scroll:GetFrameLevel() + 20)
    local parts = {}
    for index, name in ipairs({ "top", "bottom", "middle" }) do
        local part = thumb:CreateTexture(nil, "ARTWORK")
        local atlas = "minimal-scrollbar-small-thumb-" .. name
        if not part.SetAtlas or not C_Texture or not C_Texture.GetAtlasInfo or not C_Texture.GetAtlasInfo(atlas) then return nil end
        part:SetAtlas(atlas, true)
        parts[index] = part
    end
    parts[1]:SetPoint("TOPLEFT")
    parts[2]:SetPoint("BOTTOMLEFT")
    parts[3]:SetPoint("TOPLEFT", parts[1], "BOTTOMLEFT")
    parts[3]:SetPoint("BOTTOMRIGHT", parts[2], "TOPRIGHT")
    return thumb
end

T.AddSkin({
    key = "legacy", label = "Legacy", order = 20, header = 24, shadow = true, noDivider = true, closeX = 1,
    fonts = { sans = "game", sansMedium = "game" },
    buttonTemplate = "UIPanelButtonTemplate", sliderTemplate = "UISliderTemplate", closeTemplate = "UIPanelCloseButtonNoScripts",
    Close = function(button) button:SetSize(24, 24) end,
    colors = {
        page = { 255, 255, 255 },
        chrome = { 23, 23, 48, 0.95 }, -- the tooltips'
        field = { 0, 0, 0, 0.6 },
        bubble = { 23, 23, 48, 0.9 },
        chip = { 70, 10, 5 },
        text = { 255, 255, 255 },
        title = { 255, 209, 0 },
        label = { 255, 209, 0 },
        body = { 255, 255, 255 },
        secondary = { 220, 220, 220 },
        muted = { 160, 160, 160 },
        border = { 190, 190, 190 },
        borderStrong = { 220, 220, 220 },
        borderHover = { 255, 209, 0 },
        hover = { 255, 209, 0, 0.2 },
        clay = { 255, 209, 0 },
        plan = { 255, 209, 0 },
        send = { 120, 15, 8 },
        sendHover = { 175, 25, 14 },
        code = { 255, 160, 90 },
        accent = { 51, 148, 255 },
    },
    Box = Box, Switch = Switch, Slider = Slider, Thumb = Thumb,
})
