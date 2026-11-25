-- claude-in-wow: its settings, in the Claude window behind the gear at its
-- top (ClaudeWindow.lua), and nowhere else: no entry in the game's AddOns
-- settings. A tab on the left for each category, and in it its modules
-- (Core\Modules.lua): a module's name and switch, then its own settings, dimmed
-- while it is off. Nothing here knows a module: each declares itself.

local addonName, ns = ...

local ipairs, max = ipairs, math.max
local L, T = ns.L, ns.Theme

local TABS = 128   -- the tabs' column
local PAD = 20
local INDENT = 14  -- a module's settings under its name
local NARROW = 330 -- under this, a menu or a slider goes under its text

----------------------------------------------------------------------
-- Rows
----------------------------------------------------------------------

-- A name, a word on it, and on the right a switch, a menu or a slider.
local function Row(parent, entry, isModule)
    local row = CreateFrame("Frame", nil, parent)
    row.option = entry
    row.label = T.Text(row, "sansMedium", isModule and 14 or 13, "text")
    row.label:SetText(L[isModule and entry.title or entry.label])
    row.tip = T.Text(row, "sans", 12, "muted")
    if isModule and entry.fixed then
        row.control = nil
    elseif entry.choices then
        row.picker = T.Picker(row, function(self) ns.ToggleMenu(self, ns.ChoiceEntries(entry.key)) end, true)
        row.picker.menuRight = true
        row.control = row.picker
    elseif entry.slider then
        row.slider = T.Slider(row, entry.slider[1], entry.slider[2], entry.slider[3], function(value) ns.SetOption(entry.key, value) end, entry.slider[4])
        row.control = row.slider
    else
        -- a limit is ticked when what it limits is off
        row.switch = T.Switch(row, function(on)
            if entry.limit then on = not on end
            ns.SetOption(entry.key, on)
        end)
        row.control = row.switch
    end

    -- Lays it out and reads the setting again: its height.
    function row:Refresh(width)
        local warning = entry.warning and entry.warning()
        self.tip:SetText(warning or entry.tip and L[entry.tip] or "")
        self.tip:SetTextColor(T.Color(warning and "clay" or "muted"))
        if self.picker then
            self.picker:SetLabel(ns.ChoiceLabel(entry.key))
        elseif self.slider then
            self.slider:SetAmount(ns.db.options[entry.key])
        elseif self.switch then
            local on = ns.db.options[entry.key]
            self.switch:SetChecked(entry.limit and not on or not entry.limit and on)
        end
        local taken = self.control and (self.control:GetWidth() or 36) + (self.slider and 60 or 16) or 0
        local below = self.control and not self.switch and width < NARROW
        local room = below and width or width - taken
        self.label:SetWidth(room)
        self.tip:SetWidth(room)
        self.label:ClearAllPoints()
        self.label:SetPoint("TOPLEFT")
        self.tip:ClearAllPoints()
        self.tip:SetPoint("TOPLEFT", self.label, "BOTTOMLEFT", 0, -4)
        local height = (self.label:GetStringHeight() or 13) + 4 + (self.tip:GetText() ~= "" and self.tip:GetStringHeight() or 0)
        if self.control then
            self.control:ClearAllPoints()
            if below then
                self.control:SetPoint("TOPLEFT", self, "TOPLEFT", self.slider and 50 or 0, -height - 8)
                height = height + 8 + (self.control:GetHeight() or 28)
            else
                self.control:SetPoint("TOPRIGHT", 0, 0)
            end
        end
        self:SetSize(width, height)
        return height
    end
    return row
end

----------------------------------------------------------------------
-- A category
----------------------------------------------------------------------

local function View(parent, category)
    local view = CreateFrame("Frame", nil, parent)
    view:SetPoint("TOPLEFT")
    view.title = T.Text(view, "sansMedium", 19, "text")
    view.title:SetWordWrap(false)
    view.title:SetText(L[category.title])
    view.modules = {}
    for index, module in ipairs(ns.ModulesOf(category.key)) do
        local built = { module = module, rows = {}, head = Row(view, module, true), line = T.Line(view) }
        built.line:SetHeight(1)
        for at, setting in ipairs(module.settings or {}) do built.rows[at] = Row(view, setting) end
        built.custom = module.custom and module.custom(view)
        view.modules[index] = built
    end

    -- Lays it out at a width: its height.
    function view:Layout(full)
        local width, y = full - 2 * PAD, -PAD
        self.title:ClearAllPoints()
        self.title:SetPoint("TOPLEFT", PAD, y)
        y = y - (self.title:GetStringHeight() or 22) - 18
        local function Place(frame, indent, height, gap)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", PAD + indent, y)
            y = y - height - gap
        end
        for index, built in ipairs(self.modules) do
            built.line:SetShown(index > 1)
            if index > 1 then
                built.line:ClearAllPoints()
                built.line:SetPoint("TOPLEFT", PAD, y)
                built.line:SetWidth(width)
                y = y - 15
            end
            local on = built.module.fixed or built.module.limit or ns.On(built.module.key)
            Place(built.head, 0, built.head:Refresh(width), #built.rows > 0 and 12 or 14)
            for _, row in ipairs(built.rows) do
                row:SetAlpha(on and 1 or 0.4)
                Place(row, INDENT, row:Refresh(width - INDENT), 12)
            end
            if built.custom then Place(built.custom, INDENT, built.custom:Refresh(width - INDENT), 14) end
        end
        self:SetSize(full, -y + PAD)
        return -y + PAD
    end
    return view
end

----------------------------------------------------------------------
-- The page
----------------------------------------------------------------------

local function TabButton(page, category, index)
    local tab = CreateFrame("Button", nil, page)
    tab.category = category.key
    tab:SetSize(TABS - 16, 32)
    tab:SetPoint("TOPLEFT", 10, -14 - (index - 1) * 36)
    T.Box(tab, 8, "none")
    tab.label = T.Text(tab, "sans", 13, "secondary")
    tab.label:SetWordWrap(false)
    tab.label:SetPoint("LEFT", 12, 0)
    tab.label:SetText(L[category.title])
    tab:SetScript("OnEnter", function(self) if not self.active then T.PaintBox(self, "hover") end end)
    tab:SetScript("OnLeave", function(self) if not self.active then T.PaintBox(self, "none") end end)
    tab:SetScript("OnClick", function() page:ShowTab(category.key) end)
    return tab
end

-- The settings page, filling parent; page:Refresh() lays it out and reads the
-- settings again.
function ns.BuildSettings(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    local categories, tabs, views = ns.Categories(), {}, {}
    for index, category in ipairs(categories) do tabs[index] = TabButton(page, category, index) end
    local divider = T.Line(page)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", TABS, 0)
    divider:SetPoint("BOTTOMLEFT", TABS, 0)
    local scroll = T.Scroll(page)
    scroll:SetPoint("TOPLEFT", TABS + 1, 0)
    scroll:SetPoint("BOTTOMRIGHT")

    function page:ShowTab(key)
        ns.db.settingsTab = key
        scroll:SetVerticalScroll(0)
        ns.RenderClaude()
    end

    function page:Refresh()
        local current = categories[1]
        for _, category in ipairs(categories) do
            if category.key == ns.db.settingsTab then current = category end
        end
        for _, tab in ipairs(tabs) do
            tab.active = tab.category == current.key
            T.PaintBox(tab, tab.active and "field" or "none")
            tab.label:SetTextColor(T.Color(tab.active and "text" or "secondary"))
        end
        views[current.key] = views[current.key] or View(scroll.content, current)
        for _, category in ipairs(categories) do
            if views[category.key] then views[category.key]:SetShown(category == current) end
        end
        local width = max(scroll:GetWidth() or 0, 200)
        scroll.content:SetSize(width, views[current.key]:Layout(width))
        scroll:To(scroll:GetVerticalScroll() or 0)
    end
    return page
end

-- Shift+click on the minimap button.
function ns.OpenOptions()
    ns.OpenClaude("settings")
end

----------------------------------------------------------------------
-- About
----------------------------------------------------------------------

ns.OnLanguage(function() L.ABOUT = L.ABOUT:format(C_AddOns.GetAddOnMetadata(addonName, "Version") or "") end)
ns.Module({ key = "about", category = "about", order = 10, fixed = true, title = "ABOUT", tip = "SILENT_MODE_TIP" })
ns.Module({ key = "unofficial", category = "about", order = 20, fixed = true, title = "UNOFFICIAL", tip = "UNOFFICIAL_TIP" })
