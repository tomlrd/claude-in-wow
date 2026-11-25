---
description: Sets claude-in-wow up - checks what it needs, creates the player's folder, and starts the answers in the game
argument-hint: "[folder, default: Documents\\claude-in-wow]"
---

Set claude-in-wow up for the player, one step after the other, saying what each did in a line, in their language (English by default).

0. **Node.js**, which the tools run on: without it none of them is there. When `silent_mode` is not among your tools, or fails to start, run `node --version` in a terminal. Not found, or under 18: say so in a line, with what would be installed and from where, and ask the player; on their yes only, install the current LTS from its official publisher:
   - Windows: `winget install --id OpenJS.NodeJS.LTS --source winget`, which shows its own agreements and asks for the administrator's consent: the player accepts them. Without `winget`: nodejs.org, which the player opens and installs themselves.
   - macOS: `brew install node` when `brew` is there; otherwise nodejs.org.
   Never another source. Then the player closes Claude Code and opens it again, for the tools to start, and types `/wow-mcp:setup` again: stop here until then.

   **The rest of what it needs**: call `silent_mode` with `action: "check"`, and settle what is missing before going on:
   - `claudeCode` null: the `claude` command is not found; the player installs Claude Code (claude.com/claude-code) so that it works in a terminal.
   - `signedIn` false: the player types `claude auth login` in a terminal. Never ask for a password or a key, nor type one.
   - no game, or none with `addon` true: the game's folder was not found (it is looked for where Battle.net installed it and in the usual places: ask the player where it is, then `silent_mode` with `action: "game"` and that folder), or the claude-in-wow addon is not installed in it (from CurseForge; the game sees it when it is next started).

Then the player's claude-in-wow folder, so that every conversation opened in it is about their game: the instructions below, and the claude-in-wow tools allowed without asking.

1. **The folder**: `$ARGUMENTS` if given, else `claude-in-wow` in the player's own Documents folder, wherever it is (Windows: `[Environment]::GetFolderPath('MyDocuments')`, which follows OneDrive or another drive; macOS: `~/Documents`). Create it if needed. If it already holds `CLAUDE.md` or `.claude/settings.json`, show what would change and ask before replacing anything.

2. **The game's folder**: call the `screenshots` tool (or `game_state`): their paths start with the folder of the version played (`_retail_`, `_classic_era_`, `_forever_`...). If the tools cannot find the game, ask the player where World of Warcraft is installed.

3. **`CLAUDE.md`** in the folder, with exactly this content:

   ```markdown
   # World of Warcraft

   This folder is the player's World of Warcraft corner: every conversation here is about their game, as a player.

   - Use the `wow-mcp` tools and the `wow` skill for any question about the character, quests, items, gold, addons or Lua errors.
   - When the present matters (bags, position, quest progress) and the snapshot is old, ask for a photo: `/claude photo` in the game's chat (no /reload needed, not in combat).
   - A message starting with `[claude-in-wow <version>]` was pasted from the game: follow the skill's "Questions pasted from the game".
   - Answer in the player's language, short, with names as the game writes them.
   - Never change the game's files while the game runs, and never help automate gameplay.
   ```

4. **`.claude/settings.json`** in the folder, the version's folder from step 2 in `additionalDirectories`, with those of the other versions the player wants (so screenshots and addon files can be read), JSON-escaped:

   ```json
   {
     "permissions": {
       "allow": ["mcp__plugin_wow-mcp_wow-mcp"],
       "additionalDirectories": ["<the version's folder>"]
     }
   }
   ```

5. **The answers in the game**: call `silent_mode` with `action: "start"` and that folder. Then ask the player whether it should start with Windows (it puts a small script in their Startup folder; without it, it starts again each time Claude Code is opened); on their yes only, `action: "autostart"` with the same folder.

6. **The game**: if it is running, the player quits it and starts it again, once: it then finds the addons the answers come through. Check with `action: "check"` that `answerAddons` is not 0.

7. **Tell the player**, in their language and in a few lines: in the game, a click on Claude's spark on the minimap opens the window, and the Help tab of its settings says what to do when nothing answers; open this folder as a project (in the desktop app, pick it in the Code tab's folder choice; in a terminal, start in it); from then on every new conversation there is about their game. Before asking about the present, take a photo in game: `/claude photo`.
