-- claude-in-wow: what the Claude window is made of: colours, fonts, boxes,
-- buttons, menus, scrolling; as the skin the player picked has them (Window\Skins,
-- one file each; another is taken at the next loading of the interface). What a
-- skin does not say is Claude's: rounded boxes, Inter, the textures of Media\Claude
-- (drawn by the plugin's tools\claude-art.mjs at twice the size they are shown at).
--   T.AddSkin({
--       key, label, order,
--       colors = { page, chrome, ... },   -- the names of Skins\Claude.lua, 0-255, alpha 0-1
--       fonts = { sans, sansMedium },     -- faces of T.FONTS in place of Claude's
--       shadow = true,                    -- under the texts
--       header = 48,                      -- the window's top bar
--       Box(frame, radius, fill, border, layer, role),  -- draws a box: frame.boxFill and
--           frame.boxBorder (textures to tint), or frame.paintBox(frame, fill, border)
--       Switch(switch) -> paint(switch, on), Slider(slider), Thumb(scroll) -> thumb,
--       Close(button),                    -- the window's close button
--       buttonTemplate, sliderTemplate, closeTemplate,    -- the game's own templates
--   })

local addonName, ns = ...

local floor, ipairs, max, min, pairs, pcall, setmetatable, sort, type = math.floor, ipairs, math.max, math.min, pairs, pcall, setmetatable, table.sort, type

local T = {}
ns.Theme = T

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
local ART = MEDIA .. "Claude\\"
T.ART = ART
local WHITE = "Interface\\Buttons\\WHITE8X8"

----------------------------------------------------------------------
-- Skins
----------------------------------------------------------------------

local skins, active = {}, nil

function T.AddSkin(skin)
    if skins.claude then setmetatable(skin.colors, { __index = skins.claude.colors }) end -- Claude's comes first
    skins[skin.key] = skin
end

-- The skins, in order.
function T.Skins()
    local list = {}
    for _, skin in pairs(skins) do list[#list + 1] = skin end
    sort(list, function(a, b) return a.order < b.order end)
    return list
end

-- The skin in use: the one picked when the interface loaded.
function T.Skin()
    if active then return active end
    local options = ns.db and ns.db.options
    if options and options.skin then active = skins[options.skin] or skins.claude end
    return active or skins.claude
end

-- The game's one-pixel line, in a frame's units.
function T.Pixel(frame)
    return PixelUtil and PixelUtil.GetNearestPixelSize(1, frame:GetEffectiveScale(), 1) or 1
end

-- A frame of the game's template, a plain one where there is none.
function T.Frame(kind, parent, template)
    if template then
        local ok, frame = pcall(CreateFrame, kind, nil, parent, template)
        if ok and frame then return frame, true end
    end
    return CreateFrame(kind, nil, parent)
end

----------------------------------------------------------------------
-- Colours
----------------------------------------------------------------------

local function Named(color)
    local colors = T.Skin().colors
    return colors[color] or colors.text
end

-- r, g, b, a (0-1) of a colour name or a { r, g, b[, a] } table (0-255).
function T.Color(color)
    local c = type(color) == "table" and color or Named(color)
    return c[1] / 255, c[2] / 255, c[3] / 255, c[4] or 1
end

-- A colour more or less see-through, for T.Color (alpha 0-1).
function T.Faded(color, alpha)
    local c = Named(color)
    return { c[1], c[2], c[3], alpha }
end

-- "|cffrrggbb" of a colour, for colour codes in a text.
function T.Code(color)
    local c = Named(color)
    return ("|cff%02x%02x%02x"):format(c[1], c[2], c[3])
end

----------------------------------------------------------------------
-- Fonts
----------------------------------------------------------------------

T.FONTS = {
    sans = MEDIA .. "Fonts\\Inter-Regular.ttf",
    sansMedium = MEDIA .. "Fonts\\Inter-Medium.ttf",
    inter = MEDIA .. "Fonts\\Inter-Regular.ttf", -- the same ones, whatever the skin
    interMedium = MEDIA .. "Fonts\\Inter-Medium.ttf",
    mono = MEDIA .. "Fonts\\FiraMono-Medium.ttf",
    monoText = MEDIA .. "Fonts\\FiraMono-Medium.ttf",
    serif = MEDIA .. "Fonts\\NotoSerif-Regular.ttf",
    serifBold = MEDIA .. "Fonts\\NotoSerif-Bold.ttf",
    game = STANDARD_TEXT_FONT, -- and the game's others
    narrow = "Fonts\\ARIALN.TTF",
    morpheus = "Fonts\\MORPHEUS.TTF",
    skurri = "Fonts\\SKURRI.TTF",
    ptSans = MEDIA .. "Fonts\\PTSansNarrow.ttf",
}

-- The game gets a font file ready only while the interface loads (see
-- Photo.lua): each is asked for now, off screen.
do
    local preload = CreateFrame("Frame")
    preload:SetPoint("TOP", UIParent, "BOTTOM", 0, -5000)
    preload:SetSize(100, 100)
    for _, file in pairs(T.FONTS) do
        local text = preload:CreateFontString()
        text:SetAllPoints()
        if pcall(text.SetFont, text, file, 12, "") then pcall(text.SetText, text, "Claude") end
    end
end

-- A font set on a font string; the game's own when the file is not ready
-- (the addon installed while the game ran).
function T.SetFont(fontString, face, size)
    local fonts = T.Skin().fonts
    face = fonts and fonts[face] or face
    local ok, set = pcall(fontString.SetFont, fontString, T.FONTS[face] or T.FONTS.sans, size, "")
    if not ok or set == false then fontString:SetFont(STANDARD_TEXT_FONT, size, "") end
end

-- A font string: face, size, colour, wrapped, top left.
function T.Text(parent, face, size, color, layer)
    local text = parent:CreateFontString(nil, layer or "OVERLAY")
    T.SetFont(text, face, size)
    if face == "sansMedium" and color == "text" then color = "title" end
    text:SetTextColor(T.Color(color))
    local shadow = T.Skin().shadow
    text:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
    if shadow then text:SetShadowColor(0, 0, 0, 1) end
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    if text.SetNonSpaceWrap then text:SetNonSpaceWrap(true) end
    return text
end

-- How wide a text is on one line.
function T.TextWidth(text)
    if text.GetUnboundedStringWidth then return text:GetUnboundedStringWidth() or 0 end
    return text:GetStringWidth() or 0
end

----------------------------------------------------------------------
-- Boxes
----------------------------------------------------------------------

-- One layer of a rounded box: four quarter discs and three bands, all white
-- and tinted. inset: from the frame's edges.
local function Layer(frame, layer, sublevel, inset, radius)
    local parts = {}
    local disc = ART .. (radius > 8 and "Circle64" or "Circle32")
    local function Corner(point, left, right, top, bottom, x, y)
        local corner = frame:CreateTexture(nil, layer, nil, sublevel)
        corner:SetTexture(disc)
        corner:SetTexCoord(left, right, top, bottom)
        corner:SetSize(radius, radius)
        corner:SetPoint(point, x, y)
        parts[#parts + 1] = corner
    end
    Corner("TOPLEFT", 0, 0.5, 0, 0.5, inset, -inset)
    Corner("TOPRIGHT", 0.5, 1, 0, 0.5, -inset, -inset)
    Corner("BOTTOMLEFT", 0, 0.5, 0.5, 1, inset, inset)
    Corner("BOTTOMRIGHT", 0.5, 1, 0.5, 1, -inset, inset)

    local function Band(fromX, fromY, toX, toY, top)
        local band = frame:CreateTexture(nil, layer, nil, sublevel)
        band:SetTexture(WHITE)
        band:SetPoint("TOPLEFT", frame, top and "TOPLEFT" or "BOTTOMLEFT", fromX, fromY)
        band:SetPoint("BOTTOMRIGHT", frame, top and "TOPRIGHT" or "BOTTOMRIGHT", toX, toY)
        parts[#parts + 1] = band
    end
    Band(inset + radius, -inset, -inset - radius, -inset - radius, true)   -- top, between the corners
    Band(inset + radius, inset + radius, -inset - radius, inset, false)   -- bottom
    local middle = frame:CreateTexture(nil, layer, nil, sublevel)
    middle:SetTexture(WHITE)
    middle:SetPoint("TOPLEFT", inset, -inset - radius)
    middle:SetPoint("BOTTOMRIGHT", -inset, inset + radius)
    parts[#parts + 1] = middle
    return parts
end

local function Paint(parts, color)
    local r, g, b, a = T.Color(color)
    for _, part in ipairs(parts) do part:SetVertexColor(r, g, b, a) end
end

-- A box filling frame, rounded with Claude's skin, with a thin border when border
-- is given; role: what it is, for the skins that draw some apart ("window", "button",
-- "send"). Its colours change with T.PaintBox.
function T.Box(frame, radius, fill, border, role)
    local skin = T.Skin()
    if skin.Box then
        skin.Box(frame, radius, fill, border, "BACKGROUND", role)
    else
        frame.boxFill = Layer(frame, "BACKGROUND", 1, border and 1 or 0, border and radius - 1 or radius)
        if border then frame.boxBorder = Layer(frame, "BACKGROUND", 0, 0, radius) end
    end
    T.PaintBox(frame, fill, border)
end

function T.PaintBox(frame, fill, border)
    if frame.paintBox then return frame.paintBox(frame, fill, border) end
    if fill and frame.boxFill then Paint(frame.boxFill, fill) end
    if border and frame.boxBorder then Paint(frame.boxBorder, border) end
end

-- A one-unit line (dividers).
function T.Line(parent, color)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(WHITE)
    line:SetVertexColor(T.Color(color or "border"))
    return line
end

----------------------------------------------------------------------
-- Icons and buttons
----------------------------------------------------------------------

-- The game's own picture for an icon whose file came with a later version:
-- the game only finds files that were there when it started.
local STAND_INS = { Gear = "Interface\\WorldMap\\Gear_64Grey" }

-- A line icon (Close, Plus, ArrowUp, Camera, NewChat, Copy, Check, Bag,
-- MapPin, Clipboard, Gear, Trash, Chevron), tinted.
function T.Icon(parent, name, size, color, layer)
    local icon = parent:CreateTexture(nil, layer or "ARTWORK")
    if icon:SetTexture(ART .. name) == false and STAND_INS[name] then icon:SetTexture(STAND_INS[name]) end
    icon:SetSize(size, size)
    icon:SetVertexColor(T.Color(color or "muted"))
    return icon
end

-- An icon shown in a texture: one of ours by its name, tinted, or one of the game's by its
-- number, as it is.
function T.SetIcon(texture, icon, color)
    texture.own = type(icon) == "number" or nil
    if texture.own then
        texture:SetTexture(icon)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        texture:SetVertexColor(1, 1, 1)
    else
        texture:SetTexture(ART .. icon)
        texture:SetTexCoord(0, 1, 0, 1)
        if color then texture:SetVertexColor(T.Color(color)) end
    end
end

-- Our icons one can choose from.
T.ICONS = { "ArrowUp", "Bag", "MapPin", "Clipboard", "Check", "Copy", "Gear", "NewChat", "Camera", "Plus", "Trash" }

-- The addon's logo: Claude's spark, from the texture closest to twice its size, with World
-- of Warcraft's icon (the game's own file) in front of it, shown and hidden with it.
function T.Logo(parent, size, color, layer)
    local icon = parent:CreateTexture(nil, layer or "ARTWORK")
    icon:SetTexture(ART .. (size <= 16 and "Logo32" or size <= 32 and "Logo64" or "Logo128"))
    icon:SetSize(size, size)
    icon:SetVertexColor(T.Color(color or "clay"))
    local game = parent:CreateTexture(nil, "OVERLAY")
    game:SetSize(size * 0.6, size * 0.6)
    game:SetPoint("CENTER", icon, "CENTER")
    game:SetTexture("Interface\\FriendsFrame\\Battlenet-WoWicon")
    icon.game = game
    hooksecurefunc(icon, "Show", function() game:Show() end)
    hooksecurefunc(icon, "Hide", function() game:Hide() end)
    hooksecurefunc(icon, "SetShown", function(_, shown) game:SetShown(shown) end)
    return icon
end

-- The same in one picture, for where the game takes one file (the AddOns list).
T.ADDON_ICON = ART .. "LogoWoW"

local function Tooltip(self)
    if not self.tooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self.tooltip, 1, 1, 1)
    GameTooltip:Show()
end

-- A quiet button: an icon that lights up under the mouse, a soft square
-- behind it; outlined when bordered (the "+" of the box you write in).
function T.IconButton(parent, iconName, size, tooltip, onClick, bordered)
    local skin = T.Skin()
    if skin.Close and iconName == "Close" and size >= 16 then -- the window's
        local button, made = T.Frame("Button", parent, skin.closeTemplate)
        if made then
            skin.Close(button)
            button.tooltip = tooltip
            button:SetScript("OnEnter", Tooltip)
            button:SetScript("OnLeave", GameTooltip_Hide)
            button:SetScript("OnClick", onClick)
            return button
        end
    end
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size + 12, size + 12)
    T.Box(button, 8, "none", bordered and "border" or nil)
    button.icon = T.Icon(button, iconName, size, "muted")
    button.icon:SetPoint("CENTER")
    button.tooltip = tooltip
    button:SetScript("OnEnter", function(self)
        T.PaintBox(self, "hover")
        self.icon:SetVertexColor(T.Color("text"))
        Tooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        T.PaintBox(self, "none")
        self.icon:SetVertexColor(T.Color("muted"))
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", onClick)
    return button
end

-- A pill, its knob on the right and the accent colour when on.
local function Pill(switch)
    switch:SetSize(36, 20)
    T.Box(switch, 10, "field", "borderStrong")
    local knob = switch:CreateTexture(nil, "ARTWORK")
    knob:SetTexture(ART .. "Circle32")
    knob:SetSize(14, 14)
    return function(self, on)
        T.PaintBox(self, on and "accent" or "field", on and "accent" or "borderStrong")
        knob:ClearAllPoints()
        knob:SetPoint(on and "RIGHT" or "LEFT", on and -3 or 3, 0)
        knob:SetVertexColor(T.Color(on and "white" or "secondary"))
    end
end

-- A switch, as claude.ai's settings have, or the skin's check box. onChange(on)
-- after a click.
function T.Switch(parent, onChange)
    local switch = CreateFrame("Button", nil, parent)
    local paint = (T.Skin().Switch or Pill)(switch)
    function switch:SetChecked(on)
        self.checked = on and true or false
        paint(self, self.checked)
    end
    switch:SetScript("OnClick", function(self)
        self:SetChecked(not self.checked)
        onChange(self.checked)
    end)
    switch:SetChecked(false)
    return switch
end

-- A line, a round knob, the accent colour up to it.
local function RoundSlider(slider)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(WHITE)
    track:SetVertexColor(T.Color("borderStrong"))
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(4)
    local knob = slider:CreateTexture(nil, "OVERLAY")
    knob:SetTexture(ART .. "Circle32")
    knob:SetVertexColor(T.Color("white"))
    knob:SetSize(14, 14)
    slider:SetThumbTexture(knob)
    local done = slider:CreateTexture(nil, "ARTWORK")
    done:SetTexture(WHITE)
    done:SetVertexColor(T.Color("accent"))
    done:SetPoint("LEFT")
    done:SetPoint("RIGHT", knob, "CENTER")
    done:SetHeight(4)
end

-- A slider, the value on its left, with its unit (percent). onChange(value) while
-- the player moves it.
function T.Slider(parent, from, to, step, onChange, unit)
    local skin = T.Skin()
    local slider, made = T.Frame("Slider", parent, skin.sliderTemplate)
    slider:SetSize(120, 20)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(from, to)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    if made then
        slider:SetHeight(17) -- the template's own pieces
    else
        (skin.Slider or RoundSlider)(slider)
    end
    slider.label = T.Text(slider, "sans", 12, "secondary")
    slider.label:SetPoint("RIGHT", slider, "LEFT", -10, 0)
    function slider:Display(value)
        self.amount = value
        self.label:SetText(value .. (unit or " %"))
    end
    function slider:SetAmount(value)
        self:Display(value)
        self:SetValue(value)
    end
    slider:SetScript("OnValueChanged", function(self, value, byPlayer)
        value = floor(value / step + 0.5) * step
        if not byPlayer or value == self.amount then return end
        self:Display(value)
        onChange(value)
    end)
    return slider
end

-- A box to write in, one line or several (a longer text scrolls). hint: what it shows
-- empty. onChange(text) as the player types. SetValue puts a text in it, unless the
-- player is writing there.
function T.Edit(parent, several, hint, onChange)
    local frame = CreateFrame("Frame", nil, parent)
    T.Box(frame, 8, "field", "border")
    frame:EnableMouse(true)
    local area = CreateFrame("ScrollFrame", nil, frame)
    area:SetPoint("TOPLEFT", 8, -7)
    area:SetPoint("BOTTOMRIGHT", -8, 5)
    local edit = CreateFrame("EditBox", nil, area)
    edit:SetMultiLine(several and true or false)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(several and 600 or 60)
    T.SetFont(edit, "sans", 13)
    edit:SetTextColor(T.Color("text"))
    edit:SetSize(200, 16)
    area:SetScrollChild(edit)
    area:SetScript("OnSizeChanged", function(_, width)
        if width and width > 40 then edit:SetWidth(width) end -- never without a width
    end)
    frame.hint = T.Text(frame, "sans", 13, "muted")
    frame.hint:SetWordWrap(false)
    frame.hint:SetPoint("TOPLEFT", area, "TOPLEFT")
    frame.hint:SetText(hint)
    frame.edit = edit
    local function Mouse() edit:SetFocus() end
    frame:SetScript("OnMouseDown", Mouse)
    area:SetScript("OnMouseDown", Mouse)
    edit:SetScript("OnCursorChanged", function(_, _, y, _, height)
        local offset, view = area:GetVerticalScroll(), area:GetHeight()
        y = -y
        if y < offset then
            area:SetVerticalScroll(y)
        elseif y + height > offset + view then
            area:SetVerticalScroll(y + height - view)
        end
    end)
    edit:SetScript("OnTextChanged", function(self, byPlayer)
        local text = self:GetText() or ""
        frame.hint:SetShown(text == "")
        if byPlayer then onChange(strtrim((text:gsub("||", "|")))) end -- an edit box doubles the "|" it is given
    end)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self)
        if several and IsShiftKeyDown() then self:Insert("\n") else self:ClearFocus() end
    end)
    edit:SetScript("OnEditFocusGained", function() T.PaintBox(frame, nil, "borderHover") end)
    edit:SetScript("OnEditFocusLost", function(self)
        T.PaintBox(frame, nil, "border")
        self:HighlightText(0, 0)
    end)
    function frame:SetValue(text)
        if edit:HasFocus() or edit:GetText() == text then return end
        edit:SetText(text)
        edit:SetCursorPosition(0)
        self.hint:SetShown(text == "")
    end
    function frame:Focus() edit:SetFocus() end
    return frame
end

-- A chip: a rounded outline with an icon and a few words, as claude.ai's
-- suggestions under the box you write in; outlined in Claude's colour for
-- the step Claude leads to (primary).
function T.Chip(parent, iconName, label, onClick, primary)
    local chip, made = T.Frame("Button", parent, T.Skin().buttonTemplate)
    local border = primary and "clay" or "border"
    if not made then T.Box(chip, 8, "chip", border, "button") end -- the template has its own pictures
    chip.icon = T.Icon(chip, iconName, 14, primary and "clay" or "label", "OVERLAY")
    chip.icon:SetPoint("LEFT", 9, 0)
    chip.label = T.Text(chip, "sans", 12, "label")
    chip.label:SetWordWrap(false)
    chip.label:SetPoint("LEFT", chip.icon, "RIGHT", 6, 0)
    function chip:SetLabel(text)
        self.label:SetText(text)
        local badge = self.badge and self.badge:GetText() or ""
        self:SetSize((self.bare and 11 or 9 + 14 + 6) + T.TextWidth(self.label) + (badge ~= "" and 9 + T.TextWidth(self.badge) or 0) + 11, 28)
    end
    -- A word on the right, in a colour: what kind of button it is. Before SetLabel.
    function chip:SetBadge(text, color)
        if not self.badge then
            self.badge = T.Text(self, "sansMedium", 10, "muted")
            self.badge:SetWordWrap(false)
            self.badge:SetPoint("LEFT", self.label, "RIGHT", 9, 0)
        end
        self.badge:SetText(text or "")
        self.badge:SetTextColor(T.Color(color or "muted"))
    end
    -- One of ours, one of the game's (a number), or none. Before SetLabel.
    function chip:SetIcon(icon)
        local bare = icon == nil or nil
        if bare ~= self.bare then
            self.bare = bare
            self.icon:SetShown(not bare)
            self.label:ClearAllPoints()
            if bare then self.label:SetPoint("LEFT", 11, 0) else self.label:SetPoint("LEFT", self.icon, "RIGHT", 6, 0) end
        end
        if icon then T.SetIcon(self.icon, icon, primary and "clay" or "label") end
    end
    chip:SetLabel(label)
    if primary then chip.label:SetTextColor(T.Color("text")) end
    chip:SetScript("OnEnter", function(self)
        T.PaintBox(self, "field", primary and "clay" or "borderHover")
        self.label:SetTextColor(T.Color("text"))
        if not self.icon.own then self.icon:SetVertexColor(T.Color(primary and "clay" or "text")) end
    end)
    chip:SetScript("OnLeave", function(self)
        T.PaintBox(self, "chip", border)
        self.label:SetTextColor(T.Color(primary and "text" or "label"))
        if not self.icon.own then self.icon:SetVertexColor(T.Color(primary and "clay" or "label")) end
    end)
    chip:SetScript("OnClick", onClick)
    return chip
end

-- A picker: the choice in use and a small arrow, a menu of the others on a
-- click; outlined when bordered.
function T.Picker(parent, onClick, bordered, tooltip)
    local picker = CreateFrame("Button", nil, parent)
    T.Box(picker, 8, bordered and "field" or "none", bordered and "border" or nil)
    picker.label = T.Text(picker, "sans", 12, "label")
    picker.label:SetWordWrap(false)
    picker.label:SetPoint("LEFT", 10, 0)
    picker.arrow = T.Icon(picker, "Chevron", 10, "muted")
    picker.arrow:SetPoint("LEFT", picker.label, "RIGHT", 6, -1)
    picker.tooltip = tooltip
    function picker:SetLabel(text)
        self.label:SetText(text)
        self:SetSize(10 + T.TextWidth(self.label) + 6 + 10 + 9, 28)
    end
    picker:SetScript("OnEnter", function(self)
        T.PaintBox(self, "hover", bordered and "borderHover" or nil)
        self.label:SetTextColor(T.Color("text"))
        Tooltip(self)
    end)
    picker:SetScript("OnLeave", function(self)
        T.PaintBox(self, bordered and "field" or "none", bordered and "border" or nil)
        self.label:SetTextColor(T.Color("label"))
        GameTooltip:Hide()
    end)
    picker:SetScript("OnClick", onClick)
    return picker
end

-- A menu: rows of an icon, a label and, under it, a word on it. Filled each
-- time it opens: entries = { { label, detail, icon, run } }.
function T.Menu(parent)
    local menu = CreateFrame("Frame", nil, parent)
    menu:SetFrameStrata("DIALOG")
    menu:SetClampedToScreen(true)
    T.Box(menu, 10, "chrome", "borderStrong")
    menu.items = {}

    local function Item(index)
        local item = menu.items[index]
        if item then return item end
        item = CreateFrame("Button", nil, menu)
        T.Box(item, 6, "none")
        item.icon = T.Icon(item, "Check", 16, "secondary")
        item.icon:SetPoint("LEFT", 10, 0)
        item.label = T.Text(item, "sans", 13, "text")
        item.label:SetWordWrap(false)
        item.detail = T.Text(item, "sans", 11, "muted")
        item.detail:SetWordWrap(false)
        item.detail:SetPoint("TOPLEFT", 36, -25)
        item:SetScript("OnEnter", function(self) T.PaintBox(self, "hover") end)
        item:SetScript("OnLeave", function(self) T.PaintBox(self, "none") end)
        item:SetScript("OnClick", function(self)
            menu:Hide()
            self.run()
        end)
        menu.items[index] = item
        return item
    end

    -- Opens it under a button (over it when above), or closes it.
    function menu:Toggle(anchor, entries, above)
        if self:IsShown() and self.anchor == anchor then
            self:Hide()
            return
        end
        self.anchor = anchor
        local y, width = -6, 188
        for index, entry in ipairs(entries) do
            local item = Item(index)
            local height = entry.detail and 46 or 32
            item.run = entry.run
            item.icon:SetShown(entry.icon ~= nil)
            if entry.icon then T.SetIcon(item.icon, entry.icon, "secondary") end
            item.label:SetText(entry.label)
            item.label:ClearAllPoints()
            if entry.detail then
                item.label:SetPoint("TOPLEFT", 36, -7)
            else
                item.label:SetPoint("LEFT", 36, 0)
            end
            item.detail:SetText(entry.detail or "")
            item:SetHeight(height)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", 6, y)
            item:SetPoint("TOPRIGHT", -6, y)
            T.PaintBox(item, "none")
            item:Show()
            y = y - height
            width = max(width, T.TextWidth(item.label) + 56, T.TextWidth(item.detail) + 56)
        end
        for index = #entries + 1, #self.items do self.items[index]:Hide() end
        self:SetSize(width + 12, -y + 6)
        self:ClearAllPoints()
        local side = anchor.menuRight and "RIGHT" or "LEFT"
        if above then
            self:SetPoint("BOTTOM" .. side, anchor, "TOP" .. side, 0, 6)
        else
            self:SetPoint("TOP" .. side, anchor, "BOTTOM" .. side, 0, -6)
        end
        self:Show()
    end

    pcall(menu.RegisterEvent, menu, "GLOBAL_MOUSE_DOWN") -- a click elsewhere closes it
    menu:SetScript("OnEvent", function(self)
        if self:IsShown() and not self:IsMouseOver() and not self.anchor:IsMouseOver() then self:Hide() end
    end)
    menu:Hide()
    return menu
end

-- A scrolling area: its content, the wheel, a thin mark on the right for
-- where it is. The content's height set, To(offset) puts it there.
function T.Scroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetClipsChildren(true)
    scroll.content = CreateFrame("Frame", nil, scroll)
    scroll.content:SetSize(1, 1)
    scroll:SetScrollChild(scroll.content)
    local thumb = T.Skin().Thumb and T.Skin().Thumb(scroll)
    if not thumb then
        thumb = T.Line(scroll, "borderStrong")
        thumb:SetDrawLayer("OVERLAY")
        thumb:SetWidth(3)
    end

    -- how far it can go
    function scroll:Range()
        return max(0, (self.content:GetHeight() or 0) - (self:GetHeight() or 0))
    end

    function scroll:To(offset)
        local range = self:Range()
        offset = min(max(0, offset), range)
        self:SetVerticalScroll(offset)
        local view, total = self:GetHeight() or 0, self.content:GetHeight() or 0
        thumb:SetShown(range > 0 and view > 0)
        if range <= 0 or view <= 0 then return end
        local height = max(24, view * view / total)
        thumb:SetHeight(height)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", -4, -(view - height) * (offset / range))
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta) self:To(self:GetVerticalScroll() - delta * 60) end)
    return scroll
end
