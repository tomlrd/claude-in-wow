-- claude-in-wow: the button that opens the window, the addon's logo: on the minimap, or
-- anywhere on the screen (the player's choice, ns.db.options.openButton).
--   Click: opens or closes the window (ClaudeWindow.lua).
--   Right-click, Shift+click: the addon's settings (Settings.lua).
--   Dragged: on the minimap it goes round it; on the screen, where it is let go.
-- Its place: ns.db.minimap.minimapPos, an angle in degrees (0 on the right, 90 at the top);
-- ns.db.screenButton = { x, y }, from the middle of the screen.
-- On the screen it is drawn as the skin draws its boxes (Window/Skins).

local addonName, ns = ...

local atan2, cos, deg, floor, max, min, rad, sin, sqrt = math.atan2, math.cos, math.deg, math.floor, math.max, math.min, math.rad, math.sin, math.sqrt
local L, T = ns.L, ns.Theme

local USUAL = 225 -- degrees
local OUT = 5     -- past the minimap's edge
local SIZE = 36   -- the one on the screen
local SCREEN_X, SCREEN_Y = 420, 160 -- its first place, right of the middle

local button, screen

local function Place()
    local angle = rad(ns.db.minimap.minimapPos or USUAL)
    local x, y = cos(angle), sin(angle)
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then -- along its sides
        x, y = max(-1, min(1, x * sqrt(2))), max(-1, min(1, y * sqrt(2)))
    end
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x * (Minimap:GetWidth() / 2 + OUT), y * (Minimap:GetHeight() / 2 + OUT))
end

-- The angle the cursor is at, from the middle of the minimap.
local function Follow()
    local middleX, middleY = Minimap:GetCenter()
    local x, y = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    ns.db.minimap.minimapPos = deg(atan2(y / scale - middleY, x / scale - middleX)) % 360
    Place()
end

local function Click(_, which)
    if which == "RightButton" or IsShiftKeyDown() then
        ns.OpenOptions()
    else
        ns.ToggleClaude()
    end
end

local function Tip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Claude in WoW", 1, 1, 1)
    GameTooltip:AddLine(L.MINIMAP_TIP, nil, nil, nil, true)
    GameTooltip:Show()
end

local function Build()
    button = CreateFrame("Button", "ClaudeInWoWMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local back = button:CreateTexture(nil, "BACKGROUND")
    back:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    back:SetSize(24, 24)
    back:SetPoint("CENTER")
    button.icon = T.Logo(button, 20)
    button.icon:SetPoint("CENTER")
    local ring = button:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetSize(50, 50)
    ring:SetPoint("TOPLEFT")

    button:SetScript("OnClick", Click)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", Follow)
    end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", Tip)
    button:SetScript("OnLeave", GameTooltip_Hide)
end

local function PlaceScreen()
    local at = ns.db.screenButton or {}
    screen:ClearAllPoints()
    screen:SetPoint("CENTER", UIParent, "CENTER", at.x or SCREEN_X, at.y or SCREEN_Y)
end

-- The one on the screen: a box of the skin, the logo in it.
local function BuildScreen()
    screen = CreateFrame("Button", "ClaudeInWoWScreenButton", UIParent)
    screen:SetSize(SIZE, SIZE)
    screen:SetFrameStrata("MEDIUM")
    screen:SetMovable(true)
    screen:SetClampedToScreen(true)
    screen:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    screen:RegisterForDrag("LeftButton")
    T.Box(screen, 10, "chrome", "border", "button")
    screen.icon = T.Logo(screen, SIZE - 12, nil, "OVERLAY")
    screen.icon:SetPoint("CENTER")
    screen:SetScript("OnClick", Click)
    screen:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:StartMoving()
    end)
    screen:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        local middleX, middleY = UIParent:GetCenter()
        if x and middleX then ns.db.screenButton = { x = floor(x - middleX + 0.5), y = floor(y - middleY + 0.5) } end
        PlaceScreen()
    end)
    screen:SetScript("OnEnter", function(self)
        T.PaintBox(self, "field", "borderHover")
        Tip(self)
    end)
    screen:SetScript("OnLeave", function(self)
        T.PaintBox(self, "chrome", "border")
        GameTooltip:Hide()
    end)
end

local function Show(shown)
    ns.db.minimap = ns.db.minimap or {}
    ns.db.minimap.hide = not shown or nil
    local onScreen = shown and ns.db.options.openButton == "screen"
    local onMinimap = shown and not onScreen
    if onMinimap and not button then Build() end
    if onScreen and not screen then BuildScreen() end
    if button then
        button:SetShown(onMinimap)
        if onMinimap then Place() end
    end
    if screen then
        screen:SetShown(onScreen)
        if onScreen then PlaceScreen() end
    end
end

-- Once the saved data is loaded (Main.lua).
function ns.RegisterMinimapButton()
    Show(ns.On("minimapButton"))
end

local function Places()
    return { { value = "minimap", label = L.OPEN_BUTTON_MINIMAP }, { value = "screen", label = L.OPEN_BUTTON_SCREEN } }
end

ns.Module({
    key = "minimapButton", category = "window", order = 20, title = "OPTION_MINIMAP", tip = "OPTION_MINIMAP_TIP", changed = Show,
    settings = { { key = "openButton", label = "OPEN_BUTTON", default = "minimap", choices = Places, changed = function() Show(ns.On("minimapButton")) end } },
})
