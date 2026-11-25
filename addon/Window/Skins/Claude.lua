-- claude-in-wow's own skin, the one at first: claude.ai's dark mode. Every colour
-- the window uses is named here; the other skins say those they change.

local addonName, ns = ...

ns.Theme.AddSkin({
    key = "claude", label = "Claude", order = 10, header = 48,
    colors = {
        page = { 0x26, 0x26, 0x24 },      -- the window
        chrome = { 0x1F, 0x1E, 0x1D },    -- menus, code blocks
        field = { 0x30, 0x30, 0x2E },     -- the box you write in
        bubble = { 0x14, 0x14, 0x13 },    -- your messages
        chip = { 0x26, 0x26, 0x24 },      -- buttons
        text = { 0xFA, 0xF9, 0xF5 },
        title = { 0xFA, 0xF9, 0xF5 },     -- titles, the settings' names
        label = { 0xC2, 0xC0, 0xB6 },     -- on buttons
        body = { 0xE4, 0xE1, 0xD6 },      -- Claude's answers, a shade under white so that bold shows
        secondary = { 0xC2, 0xC0, 0xB6 },
        muted = { 0x9C, 0x9A, 0x92 },
        border = { 0xDE, 0xDC, 0xD1, 0.15 },
        borderStrong = { 0xDE, 0xDC, 0xD1, 0.3 },
        borderHover = { 0xDE, 0xDC, 0xD1, 0.3 },
        hover = { 0xFF, 0xFF, 0xFF, 0.07 },
        none = { 0, 0, 0, 0 },
        clay = { 0xD9, 0x77, 0x57 },      -- Claude's colour: the spark
        plan = { 0xD9, 0x77, 0x57 },      -- the player's whole plan, against the addon's part (accent)
        send = { 0xC6, 0x61, 0x3F },      -- and what Claude does: send
        sendHover = { 0xD9, 0x77, 0x57 },
        white = { 0xFF, 0xFF, 0xFF },
        code = { 0xE8, 0xA8, 0x8E },      -- inline code
        gold = { 0xFF, 0xD1, 0x00 },      -- the game's own gold: places on the map
        accent = { 0x2C, 0x84, 0xDB },    -- selection: switches turned on
    },
})
