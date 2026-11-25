-- claude-in-wow skin: flat near-black boxes, a black one-pixel line around, blue
-- under the mouse, PT Sans Narrow with a shadow.

local addonName, ns = ...

local ipairs = ipairs
local T = ns.Theme

local WHITE = "Interface\\Buttons\\WHITE8X8"

local function Flat(frame, layer, sublevel)
    local texture = frame:CreateTexture(nil, layer, nil, sublevel)
    texture:SetTexture(WHITE)
    return texture
end

local function Box(frame, _, _, border, layer)
    local fill = Flat(frame, layer, 1)
    fill:SetAllPoints()
    frame.boxFill = { fill }
    if not border then return end
    local pixel = T.Pixel(frame)
    local lines = {}
    for index, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local line = Flat(frame, layer, 2)
        line:SetPoint(side[1])
        line:SetPoint(side[2])
        if index < 3 then line:SetHeight(pixel) else line:SetWidth(pixel) end
        lines[index] = line
    end
    frame.boxBorder = lines
end

-- A square check box, filled with the blue when on.
local function Switch(switch)
    switch:SetSize(18, 18)
    T.Box(switch, 0, "field", "border")
    local check = Flat(switch, "ARTWORK")
    check:SetPoint("TOPLEFT", 3, -3)
    check:SetPoint("BOTTOMRIGHT", -3, 3)
    check:SetVertexColor(T.Color("accent"))
    switch:SetScript("OnEnter", function(self) T.PaintBox(self, nil, "borderHover") end)
    switch:SetScript("OnLeave", function(self) T.PaintBox(self, nil, "border") end)
    return function(_, on) check:SetShown(on) end
end

-- A bordered groove, a blue block on it.
local function Slider(slider)
    local groove = CreateFrame("Frame", nil, slider)
    groove:SetPoint("TOPLEFT", 0, -4)
    groove:SetPoint("BOTTOMRIGHT", 0, 4)
    groove:SetFrameLevel(slider:GetFrameLevel())
    T.Box(groove, 0, "field", "border")
    local knob = Flat(slider, "OVERLAY")
    knob:SetVertexColor(T.Color("accent"))
    knob:SetSize(10, 12)
    slider:SetThumbTexture(knob)
end

local function Thumb(scroll)
    local thumb = CreateFrame("Frame", nil, scroll)
    thumb:SetWidth(6)
    thumb:SetFrameLevel(scroll:GetFrameLevel() + 20)
    T.Box(thumb, 0, "accent", "border")
    return thumb
end

T.AddSkin({
    key = "modern", label = "SKIN_MODERN", order = 30, header = 40, shadow = true,
    fonts = { sans = "ptSans", sansMedium = "ptSans" },
    colors = {
        page = { 15, 15, 15 },
        chrome = { 20, 20, 20 },
        field = { 26, 26, 26 },
        bubble = { 26, 26, 26 },
        chip = { 26, 26, 26 },
        text = { 255, 255, 255 },
        title = { 255, 255, 255 },
        label = { 230, 230, 230 },
        body = { 235, 235, 235 },
        secondary = { 200, 200, 200 },
        muted = { 150, 150, 150 },
        border = { 0, 0, 0 },
        borderStrong = { 0, 0, 0 },
        borderHover = { 23, 132, 209 },
        hover = { 23, 132, 209, 0.25 },
        clay = { 23, 132, 209 },
        send = { 23, 132, 209 },
        sendHover = { 64, 160, 230 },
        code = { 120, 190, 240 },
        accent = { 23, 132, 209 },
    },
    Box = Box, Switch = Switch, Slider = Slider, Thumb = Thumb,
})
