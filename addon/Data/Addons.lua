-- claude-in-wow: the installed addons, loaded or not, and why not.

local addonName, ns = ...

ns.AddCollector("addons", function(char)
    local list = {}
    local player = UnitName("player")

    for index = 1, C_AddOns.GetNumAddOns() do
        local name, title, _, _, reason = C_AddOns.GetAddOnInfo(index)
        if name and not (name:sub(1, #addonName + 2) == addonName .. "_S" and name:find("^%d+$", #addonName + 3)) then -- the slots (Inbox.lua)
            local state = C_AddOns.GetAddOnEnableState(name, player)
            list[#list + 1] = {
                name = name,
                title = ns.StripCodes(title),
                version = C_AddOns.GetAddOnMetadata(name, "Version"),
                enabled = (state or 0) > 0,
                loaded = C_AddOns.IsAddOnLoaded(index) or false,
                reason = (reason and reason ~= "") and reason or nil, -- why it did not load
            }
        end
    end

    char.addons = list
end)
