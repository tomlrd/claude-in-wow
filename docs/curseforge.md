# The CurseForge page

What goes on [authors.curseforge.com](https://authors.curseforge.com) when the project is created, and when its page changes. The pictures are in `docs/images` (and in full size where they were made).

## Before sending it

- The repository is public: the plugin is installed from it, the updates read its releases, and the Source link would be a dead link otherwise (leave Source empty until then).
- CurseForge's rules (support.curseforge.com, "Moderation Policies"): name and description in English, translations after it; links to socials or donations at the bottom; the avatar a .png of at least 400 x 400, not a game's logo nor another's art; each file with a changelog. Names "should not contain game name", yet many approved addons carry "WoW" in theirs (WIM, WoW-Pro Guides, HandyNotes: WoW Forever...).
- Never delete the project or a file to send it again while it is under review.

## The fields

| Field | What to put |
|---|---|
| Name | `Claude in WoW` |
| Summary | Ask Claude about your game from inside WoW: quests, bags, routes, dungeon strats, auras. With your own Claude plan or API key. |
| Primary category | Quests & Leveling |
| Other categories | Bags & Inventory, Chat & Communication, Data Export |
| License | All Rights Reserved |
| Source | https://github.com/tomlrd/claude-in-wow |
| Issues | https://github.com/tomlrd/claude-in-wow/issues |
| Avatar | `avatar.png` (400 x 400) |
| Images | `claude-in-wow.gif`, then 12-how, 13-silent, 02-answers, 03-route, 05-link, 09-dungeon, 14-bags, 10-aura, 04-actions, 06-why, 07-usage, 11-skins, 08-questions |

## The description

Paste below, in the Markdown editor. Each `IMAGE:` line is a picture of the project's own gallery: upload them first, then put their address in its place.

---

**Ask Claude about your game, from the game itself.** Your character, your quests, your bags, where to go and why: the answer shows in a window in the game, with links you can click, buttons, routes to follow and marks on your bags.

IMAGE: claude-in-wow.gif

> **Unofficial.** Works with Claude, by Anthropic. Not affiliated with Anthropic nor Blizzard. It needs a program on your computer besides this addon: read *How it works* below before installing.

### What you can ask

- *"Where should I go next for my quests, and in what order?"*
- *"Look where we are in the dungeon and give me the strat for the next boss, for each class of my group."*
- *"What should I do with my bags?"*
- *"Make me a ForeverAuras to follow the Scholomance key, step by step."*
- *"Is [Staff of Jordan] worth keeping?"* (Shift+click an item or a quest into your question)

### What it does

- **Answers you can click**: places, quests, items and players are links; a click shows them on the map or in their tooltip.
- **Routes to follow**: step by step, on your screen.
- **Buttons, one click each**: write the strat in /party, whisper, invite, show on the map. It only proposes: it plays nothing in your place, and nothing that loses something has a button.
- **Marks on your bags**: sell, keep, bank, auction, use, quest, destroy; the reason in each item's tooltip. Nothing is sold nor moved.
- **Auras made for you**: a list that follows your bags and quests as you play, for ForeverAuras or WeakAuras. Paste it, done.
- **It tells you how it knows**: what it read, why, what it is not sure of.
- **You see what it uses**: your plan's limits, or the cost with an API key, and the addon's own part.
- **Three looks**: Claude's, the game's own, or a flat modern one.
- Retail, the Classic versions and WoW Forever. English, French, German, Spanish, Italian.

### How it works

IMAGE: 12-how.png

Two parts that go together:

1. **This addon**, in the game: the window, what is read from the game, what is drawn.
2. **The wow-mcp plugin for [Claude Code](https://claude.com/claude-code)**, on your computer: it receives your questions, gives Claude the state of your game, and puts the answers back in the game.

Each answer uses **your own Claude plan** (Pro, Max...), or **your own API key**, paid by use. Nothing is included.

IMAGE: 13-silent.png

No Claude window needs to be open: a hidden program waits for your questions (the silent mode). Or talk to a Claude session you see: you choose, in the addon's settings.

### Installing it

1. Install [Claude Code](https://claude.com/claude-code) and sign in with your Claude account (an active plan). No plan? An API key of yours works too: step 4 tells how.
2. Install this addon.
3. In Claude Code, type `/plugin marketplace add tomlrd/claude-in-wow`, then `/plugin install wow-mcp@claude-in-wow`.
4. Type `/wow-mcp:setup`: it checks everything, offers to install Node.js when it is missing, and starts the answers.
5. Quit the game and start it again, once. A click on the spark on the minimap opens the window.

It works on Windows; on macOS it should, tell us how it goes.

### What is read, and where it goes

Read in the game: your character, quests, bags, the places and people around, your addons' list and Lua errors, and what a question needs. **Never**: whispers, Battle.net, officers' chat and notes, your account's settings. Your question goes to the plugin in a screenshot that only holds that data, read on your computer and deleted once another replaces it; Claude then gets the question and what it needs of it. Besides that, only the web is asked: the searches Claude makes, and the names of items, quests or creatures in an answer, looked up to make them links (never those of players). You may turn both off.

### Bugs, ideas, translations

On [GitHub](https://github.com/tomlrd/claude-in-wow/issues). The source is there too: all rights reserved, forks on GitHub welcome.

---

## A word for the moderators

When the project is sent for review, in the box for them:

> claude-in-wow is the in-game part of a tool that answers questions about the player's game with Claude (Anthropic's AI), through the player's own Claude Code on their computer (the wow-mcp plugin, same repository). The addon itself does nothing outside the game: like every addon, it cannot reach the network. A question leaves the game in a screenshot the player triggers, read by the plugin on the computer; answers come back in files the addon reads. The `Inbox` folder holds empty sound files on purpose: the plugin fills one to tell the game an answer is there. Nothing is automated: every action is a button the player clicks. Source: https://github.com/tomlrd/claude-in-wow
