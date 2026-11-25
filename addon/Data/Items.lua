-- claude-in-wow: bags, bank and equipped items.
-- Items are added up by item ID: { [itemID] = { name, count, quality, type,
-- subType, sell (vendor price of one, copper), slot, itemLevel and stats
-- (gear), use, equip and text (what its tooltip says), bound, questItem,
-- startsQuest (a quest ID) } }. Equipped items also carry stats, use, equip
-- and text.
-- The bank can only be read while it is open, so it is noted then, with its
-- own time.

local addonName, ns = ...

local concat, floor, format, sort, sub = table.concat, math.floor, string.format, table.sort, string.sub
local ipairs, pairs, pcall, time, type = ipairs, pairs, pcall, time, type
local BagIndex = Enum.BagIndex or {}
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local Game = ns.Game
local GetItemStats = Game.ItemStats

local MAX_TEXT = 200 -- characters kept of a tooltip text

-- The tooltip's own words before an item's effects ("Utiliser :", "Équipé :").
local USE, EQUIP, PROC = ITEM_SPELL_TRIGGER_ONUSE, ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONPROC

-- Not gear: the game gives these, or nothing, as an item's slot.
local NOT_GEAR = { [""] = true, INVTYPE_NON_EQUIP = true, INVTYPE_NON_EQUIP_IGNORE = true }

local BAGS = {}
for _, name in ipairs({ "Backpack", "Bag_1", "Bag_2", "Bag_3", "Bag_4", "ReagentBag", "Keyring" }) do
    if BagIndex[name] then BAGS[#BAGS + 1] = BagIndex[name] end
end
ns.BAGS = BAGS

local BANK, WARBAND = Game.bank, Game.accountBank

local SLOTS = {
    "head", "neck", "shoulder", "shirt", "chest", "waist", "legs", "feet", "wrist", "hands",
    "finger1", "finger2", "trinket1", "trinket2", "back", "mainHand", "offHand", "ranged", "tabard",
}

-- What the game says of an item: its type, vendor price and, for gear, its
-- slot and item level. Nothing until the game has the item in its cache
-- (items in the bags are).
local function Facts(item, id)
    if not GetItemInfo then return end
    local _, _, _, level, _, itemType, subType, _, equipLoc, _, sellPrice = GetItemInfo(id)
    if not itemType then return end

    item.type = itemType
    item.subType = subType ~= itemType and subType or nil
    item.sell = sellPrice and sellPrice > 0 and sellPrice or nil
    if equipLoc and not NOT_GEAR[equipLoc] then
        item.slot = _G[equipLoc] or equipLoc -- the game's own name of the slot
        item.itemLevel = level
    end
end

-- A gear's stats in the game's words: "Agilité +5, Endurance +5".
local function Stats(link)
    local stats = link and GetItemStats and GetItemStats(link)
    if type(stats) ~= "table" then return nil end
    local parts = {}
    for key, value in pairs(stats) do
        local name = _G[key]
        if type(name) == "string" and type(value) == "number" and value ~= 0 then
            value = floor(value * 10 + 0.5) / 10
            parts[#parts + 1] = format(value > 0 and "%s +%s" or "%s %s", name, value)
        end
    end
    sort(parts)
    return #parts > 0 and concat(parts, ", ") or nil
end

-- text without prefix and the spaces after it, or nil if it does not start so.
local function After(text, prefix)
    if type(prefix) == "string" and prefix ~= "" and sub(text, 1, #prefix) == prefix then
        return (sub(text, #prefix + 1):gsub("^%s+", ""))
    end
end

-- What the tooltip says that nothing else gives: the "Use:" and "Equip:"
-- effects and the description (the quoted line), from C_TooltipInfo's data.
local function Read(item, data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return end
    local use, equip = {}, {}
    for index, line in ipairs(data.lines) do
        local text = index > 1 and type(line) == "table" and ns.Clean(line.leftText) -- the first line is the name
        if type(text) == "string" and text ~= "" then
            text = ns.StripCodes(text)
            local used, equipped = After(text, USE), After(text, EQUIP)
            if used then
                use[#use + 1] = used
            elseif equipped then
                equip[#equip + 1] = equipped
            elseif After(text, PROC) then
                equip[#equip + 1] = text
            elseif sub(text, 1, 1) == '"' or sub(text, 1, 2) == "\194\171" then -- " or «
                item.text = sub(text, 1, MAX_TEXT)
            end
        end
    end
    if #use > 0 then item.use = sub(concat(use, " / "), 1, MAX_TEXT) end
    if #equip > 0 then item.equip = sub(concat(equip, " / "), 1, MAX_TEXT) end
end

-- Stats (gear) and tooltip texts; a tooltip that fails costs only its texts.
local function Describe(item, link, gear, getData, ...)
    if gear then item.stats = Stats(link) end
    if getData then pcall(function(...) Read(item, getData(...)) end, ...) end
end

-- Contents of some containers: the items added up, and the free and total slots.
local function Scan(bags)
    local items, free, total = {}, 0, 0
    local QuestInfo = C_Container.GetContainerItemQuestInfo

    for _, bag in ipairs(bags) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        total = total + slots
        free = free + (C_Container.GetContainerNumFreeSlots(bag) or 0)

        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local id = info and info.itemID
            if id then
                local item = items[id]
                if not item then
                    item = {
                        name = info.itemName or ns.LinkName(info.hyperlink),
                        quality = info.quality,
                        count = 0,
                    }
                    Facts(item, id)
                    Describe(item, info.hyperlink, item.slot, Game.BagTooltip, bag, slot)
                    items[id] = item
                end
                item.count = item.count + (info.stackCount or 1)
                if info.isBound then item.bound = true end

                local quest = QuestInfo and QuestInfo(bag, slot)
                if quest then
                    if quest.isQuestItem then item.questItem = true end
                    if quest.questID and not quest.isActive then item.startsQuest = quest.questID end
                end
            end
        end
    end

    return { items = items, free = free, slots = total }
end

ns.AddCollector("bags", function(char)
    char.bags = Scan(BAGS)
end)

ns.AddCollector("equipment", function(char)
    local equipment = {}
    for slot, key in ipairs(SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local durability, maxDurability = GetInventoryItemDurability(slot)
            local item = {
                id = ns.LinkID(link),
                name = ns.LinkName(link),
                quality = GetInventoryItemQuality("player", slot),
                durability = durability and maxDurability and maxDurability > 0 and durability .. "/" .. maxDurability or nil,
            }
            Describe(item, link, true, Game.WornTooltip, "player", slot)
            equipment[key] = item
        end
    end
    char.equipment = equipment
end)

-- Called at the bank's opening (a moment later, once it is filled) and closing.
function ns.ScanBank()
    if not ns.char then return end

    local bank = Scan(BANK)
    if bank.slots == 0 then return end -- not open after all

    bank.savedAt = time()
    ns.char.bank = bank

    local warband = Scan(WARBAND)
    if warband.slots > 0 then -- shared by the account's characters
        warband.savedAt = bank.savedAt
        ns.db.warbandBank = warband
    end
end
