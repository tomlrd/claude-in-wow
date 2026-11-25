-- claude-in-wow: the bags' slots on the screen, whoever draws the bags. For a click on
-- an item to use it, a slot is made from the game's own template and bears its bag's
-- and its slot's numbers; so it is known by the template's parts, and what it holds by
-- those numbers, provided the icon it shows is that item's.
--   ns.FindBagSlots()      looks at every frame: at a moment that asks for it only
--   ns.EachBagSlot(fn)     fn(slot, itemID or nil) for each slot found
--   ns.WatchBagSlots(wanted, changed): finds them as the bags open while wanted(),
--     and calls changed() once the slots have changed

local addonName, ns = ...

local ipairs, pairs, pcall, setmetatable, type = ipairs, pairs, pcall, setmetatable, type

local REST = 5 -- seconds between two looks at every frame

local slots = setmetatable({}, { __mode = "k" })
local wanted, changed
local soon, lookedAt = false, nil

local function Soon()
    if soon or not changed then return end
    soon = true
    C_Timer.After(0, function() -- once the bags are done drawing
        soon = false
        changed()
    end)
end

-- Made from the game's bag slot template: its parts are there, in every version.
local function IsSlot(frame)
    return type(frame) == "table" and frame.NewItemTexture and frame.BattlepayItemTexture and frame.flash
        and type(frame.GetID) == "function" and type(frame.CreateTexture) == "function"
end

local function Keep(frame)
    slots[frame] = true
    pcall(hooksecurefunc, frame, "SetID", Soon) -- the same slot shown for another place
    pcall(frame.HookScript, frame, "OnShow", Soon)
end

function ns.FindBagSlots()
    if not EnumerateFrames then return end
    lookedAt = GetTime()
    local frame = EnumerateFrames()
    while frame do
        local forbidden = frame.IsForbidden and frame:IsForbidden()
        if not forbidden and not slots[frame] and IsSlot(frame) then Keep(frame) end
        frame = EnumerateFrames(frame)
    end
end

-- Whether the icon a slot shows is the item's.
local function Shows(frame, bag, slot)
    local icon = frame.icon or frame.Icon
    local shown = icon and icon.GetTexture and icon:GetTexture()
    local info = C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag, slot)
    local file = type(info) == "table" and info.iconFileID
    return type(shown) ~= "number" or type(file) ~= "number" or shown == file
end

-- What a slot holds: the bag's number is its own, or its parent's.
local function Held(frame)
    local slot, parent = frame:GetID(), frame.GetParent and frame:GetParent()
    if type(slot) ~= "number" or slot < 1 then return nil end
    local bags = { frame.GetBagID and frame:GetBagID() or false, parent and parent.GetID and parent:GetID() or false }
    for _, bag in ipairs(bags) do
        local id = type(bag) == "number" and C_Container.GetContainerItemID(bag, slot)
        if id and Shows(frame, bag, slot) then return id end
    end
end

function ns.EachBagSlot(fn)
    for frame in pairs(slots) do
        local ok, id = pcall(Held, frame)
        fn(frame, ok and id or nil)
    end
end

-- The bags open: their slots may be new.
local function Opened()
    if not wanted() then return end
    if not lookedAt or GetTime() - lookedAt >= REST then ns.FindBagSlots() end
    Soon()
end

-- An item's tooltip: a slot not known yet tells of bags not looked at.
local function Hovered(tooltip)
    local owner = wanted() and tooltip.GetOwner and tooltip:GetOwner()
    if owner and not (owner.IsForbidden and owner:IsForbidden()) and not slots[owner] and IsSlot(owner) then
        ns.FindBagSlots()
        Soon()
    end
end

function ns.WatchBagSlots(isWanted, onChanged)
    wanted, changed = isWanted, onChanged
    for _, name in ipairs({ "ToggleAllBags", "OpenAllBags", "ToggleBackpack", "OpenBackpack", "ToggleBag", "OpenBag" }) do
        if type(_G[name]) == "function" then pcall(hooksecurefunc, name, Opened) end
    end
    ns.Game.OnItemTooltip(Hovered)
    C_Timer.After(2, Opened) -- the bags an addon makes at login
end
