-- claude-in-wow: the button on the minimap: Claude's spark.
--   Click: opens or closes the window (ClaudeWindow.lua).
--   Right-click, Shift+click: the addon's settings (Settings.lua).
--   Dragged: it goes round the minimap.
-- Its place: ns.db.minimap.minimapPos, an angle in degrees (0 on the right, 90 at the top).

local addonName, ns = ...

local atan2, cos, deg, max, min, rad, sin, sqrt = math.atan2, math.cos, math.deg, math.max, math.min, math.rad, math.sin, math.sqrt
local L, T = ns.L, ns.Theme

local USUAL = 225 -- degrees
local OUT = 5     -- past the minimap's edge

local button

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
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(T.ADDON_ICON)
    button.icon:SetSize(18, 18)
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
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Claude in WoW", 1, 1, 1)
        GameTooltip:AddLine(L.MINIMAP_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
end

local function Show(shown)
    ns.db.minimap = ns.db.minimap or {}
    ns.db.minimap.hide = not shown or nil
    if shown and not button then Build() end
    if not button then return end
    button:SetShown(shown)
    if shown then Place() end
end

-- Once the saved data is loaded (Main.lua).
function ns.RegisterMinimapButton()
    Show(ns.On("minimapButton"))
end

ns.Module({ key = "minimapButton", category = "window", order = 20, title = "OPTION_MINIMAP", tip = "OPTION_MINIMAP_TIP", changed = Show })
