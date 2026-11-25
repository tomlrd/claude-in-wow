-- claude-in-wow: a small button on the bags. A click takes a photo of the
-- game (Photo.lua), a Shift+click prepares the question about the bags in the
-- Claude window (Ask.lua), a Ctrl+click opens that window for the answer and
-- its marks (Marks.lua). It sits on the game's own bags, left of the close button.

local addonName, ns = ...

local ipairs = ipairs
local L = ns.L

local ICON = "Interface\\Icons\\INV_Misc_Book_09" -- the addon's own icon (.toc)

local buttons = {}

local function MakeButton(parent, size)
    local button = CreateFrame("Button", nil, parent)
    buttons[#buttons + 1] = button
    button:SetShown(ns.On("bagButton"))
    button:SetSize(size, size)
    button:SetFrameLevel(parent:GetFrameLevel() + 5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetHighlightTexture(ICON)
    local highlight = button:GetHighlightTexture()
    highlight:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    highlight:SetBlendMode("ADD")

    button:SetScript("OnClick", function()
        if IsShiftKeyDown() then
            ns.Ask("bags")
        elseif IsControlKeyDown() then
            ns.PasteMarks()
        else
            ns.TakePhoto()
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine(L.BAGS_BUTTON, 1, 1, 1)
        GameTooltip:AddLine(L.BAGS_BUTTON_TIP, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

-- The game's bags: the combined bags, or the backpack alone.
local function OnGameBags()
    for _, name in ipairs({ "ContainerFrameCombinedBags", "ContainerFrame1" }) do
        local bags = _G[name]
        if bags then
            local button = MakeButton(bags, 18)
            local close = bags.CloseButton or _G[name .. "CloseButton"]
            if close then
                button:SetPoint("RIGHT", close, "LEFT", -2, 0)
            else
                button:SetPoint("TOPRIGHT", bags, "TOPRIGHT", -28, -6)
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", OnGameBags)

ns.Module({
    key = "bagButton", category = "bags", order = 20, title = "BAG_BUTTON_MODULE", tip = "BAG_BUTTON_MODULE_TIP",
    changed = function(on) for _, button in ipairs(buttons) do button:SetShown(on) end end,
})
