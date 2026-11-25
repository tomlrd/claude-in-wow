-- claude-in-wow: Claude's spark on the minimap, through LibDBIcon so that
-- minimap button collectors (MinimapButtonButton) take it like the others.
--   Click: opens or closes the Claude window (ClaudeWindow.lua).
--   Right-click: a photo of the game (Photo.lua).
--   Shift+click: the addon's settings (Settings.lua).
-- Its place on the minimap: ns.db.minimap (LibDBIcon's own fields).

local addonName, ns = ...

local L, T = ns.L, ns.Theme
local NAME = "ClaudeInWoW"

local function Icon()
    return LibStub and LibStub("LibDBIcon-1.0", true)
end

-- Once the saved data is loaded (Main.lua).
function ns.RegisterMinimapButton()
    local broker = LibStub and LibStub("LibDataBroker-1.1", true)
    local icon = Icon()
    if not (broker and icon) or icon:IsRegistered(NAME) then return end
    ns.db.minimap = ns.db.minimap or {}
    ns.db.minimap.hide = not ns.On("minimapButton") or nil

    local object = broker:NewDataObject(NAME, {
        type = "launcher",
        label = "Claude",
        text = "Claude",
        icon = T.LOGO_CLAY,
        OnClick = function(_, button)
            if button == "RightButton" then
                ns.TakePhoto()
            elseif IsShiftKeyDown() then
                ns.OpenOptions()
            else
                ns.ToggleClaude()
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Claude", 1, 1, 1)
            tooltip:AddLine(L.MINIMAP_TIP, nil, nil, nil, true)
        end,
    })
    icon:Register(NAME, object, ns.db.minimap)
end

local function Show(shown)
    ns.db.minimap = ns.db.minimap or {}
    ns.db.minimap.hide = not shown or nil
    local icon = Icon()
    if not icon then return end
    if shown then icon:Show(NAME) else icon:Hide(NAME) end
end

ns.Module({ key = "minimapButton", category = "window", order = 20, title = "OPTION_MINIMAP", tip = "OPTION_MINIMAP_TIP", changed = Show })
