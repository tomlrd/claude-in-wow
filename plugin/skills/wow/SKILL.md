---
name: wow
description: Helps with the player's World of Warcraft game (Retail, the Classic versions, Forever) from their own install - character snapshot, quests (where to go, who gives them, what drops), NPCs, items, gathering spots, auction house prices, addons, their settings and Lua errors - plus the web. Use for any question about their WoW character, a quest, an NPC, an item, making gold, where to farm, an addon or interface problem, or a Lua error.
---

# World of Warcraft, from the player's own install

The player may have several versions installed, each in its own folder of the game's: `_retail_`, `_classic_` (Mists of Pandaria Classic), `_classic_era_`, `_anniversary_` (Burning Crusade Classic), `_forever_`, test realms. The tools read the one played last (`game_state` says which, with its data); a question sent from the game is answered with that game's. **World of Warcraft Forever** is Blizzard's classic-era content on a modern client (game type "camelot", the retail API): zones, quests and dungeons follow Classic, with its own additions (Rives Claires, Shen'dralas, quests above 90000); characters have first and last names, there are no realms, and the French client still shows some zone names in English.

Unofficial: not affiliated with Anthropic nor Blizzard.

When the `wow-mcp` tools are not there at all, Node.js, which they run on, is probably missing: check with `node --version`, tell the player, and have them type `/wow-mcp:setup`, which offers to install it.

The `wow-mcp` tools read the game folder. They never act in the game. Everything needs the claude-in-wow addon only; `quest_info`, `npc_info`, `item_info`, `gathering` and `prices` read the player's own addons, for a player who has them and wants to talk about what they hold.

## Where the answers are

| Question | Tool |
| --- | --- |
| Who, where, level, money, gear, group | `game_state` (snapshot from the claude-in-wow addon, written at every reload or logout, or at a photo: check its age and `snapshot.by`) |
| The character's quest log and progress | `quests` |
| A quest: giver, where, objectives, drops, chain, done or not | `quest_info` (Questie's database, Forever quests included, French names) |
| An NPC or creature: where, level, rank, its quests | `npc_info` |
| An item: who drops or sells it, where, the quests it is for (in the log, handed in), what its tooltip says, price | `item_info` |
| Where to mine, pick herbs, fish | `gathering` (the nodes the player's GatherMate2 has seen) |
| What an item sells for, how much sells per day | `prices` (TradeSkillMaster's data, Forever EU and the Horde auction house) |
| Where is my X, how many Y; what to do with my bags | `find_item`, `inventory` (bags, bank as last opened, equipment, account bank; tooltip texts and the player's marks) |
| An addon missing, not loading, a dependency | `addons` (`problems_only`) |
| An addon's settings or data | `saved_variables` (outline first, then `path`) |
| Something broken | `lua_errors` (the game hides them; the path names the addon; `kind: "blocked"` is taint) |
| "Look at this" | `screenshots`, then open the path with the Read tool |
| "Listen to the game": answer the questions sent from the game's Claude window | `listen`, then `answer_to_game` (see "Listening to the game") |
| What the photo lacks, for a question from the game: guild, friends, talents, spells, reputations, recipes, auctions, trainer, merchant, anything the game's functions tell | propose it as a question the player clicks, with `game_functions` to find what to read (`modules/50-questions.md`) |
| "Silent mode": answers with no conversation open | `silent_mode` (see "The silent mode") |

When the present matters (position, quest progress, bags) and the snapshot is old, ask the player for a **photo**: `/claude` in the chat. The addon draws the game state over the screen for an instant and saves it as a screenshot; the tools read it back at once, no `/reload` needed (not in combat). A `/reload` works too. The tools never send the picture itself, only the data in it.

## Questions pasted from the game

The addon has a Claude window in the game (opened by Claude's spark on the minimap). The player writes a question there, or picks "Sort my bags" or "My quests". The question travels in a photo with the game state (see "Listening to the game" below); when no photo can be taken (in combat), or if the player prefers, the window gives the question with its data to copy, and the player pastes it here. `/claude <question>`, `/claude sacs` do the same. A pasted message starts with `[claude-in-wow <version>] <kind>`, then `Question:` and the data, in the client's language. That data was read when the player asked: it is newer than the snapshot, so prefer it, and use the tools for what it lacks (who gives or takes a quest, what an item is for, auction prices, the bank's contents as last opened). A question sent in a photo shows in `game_state` as `question`: when the player says they asked in the game, or just "?", answer it.

- `bags`: sort the bags (`modules/70-bags.md`).
- `free`: the player's own question, with the character, place, professions and quest log.

The player may copy your answer back into the window, which shows it the way the Claude app does. It reads paragraphs, `#` headings, `-` and `1.` lists, `>` quotes, `**bold**`, `*italics*` (dimmer), `` `code` `` and code blocks; a table shows as one line per row. No images, no HTML, no web links: they show as their text only. A marks block in a code block gets a button there that puts the marks on the bags.

How to write such an answer (links to the game, questions and buttons proposed, the marks of the bags) is in the plugin's `modules` folder, next to this skill's `skills` folder: read its files once, before the first answer to a question from the game. They are the same the silent mode gives Claude.

## Listening to the game

When the player asks you to listen to the game ("écoute le jeu"), questions sent from the game's window reach you without them typing here:

1. Call `listen`; run the `command` it returns with the Bash tool in the background (`run_in_background`), say in one line that you are listening, and end your turn.
2. When the command exits, you are woken with its output: the question (its kind, `free` or `bags`, and its text). The game state it was asked in is in the photo, newer than the snapshot: `game_state`, `quests`, `inventory` and the other tools read it. Answer as for a pasted question, `bags` as `modules/70-bags.md` says.
3. Call `answer_to_game` with your answer exactly as you write it to the player (Markdown and marks block included), and `question` set to the `after` the output gave: it shows in the game's window by itself when the question asks for that (`delivered` in the result), and goes into the clipboard in any case, marked with the question it answers, with a sound, for the player to paste it in the window with Ctrl+V. The window refuses an answer marked for another question, or one already pasted. Write the answer first, then call it, then write the answer as your message.
4. Then run the command the result gives (`next`) in the background again, and end your turn. Say nothing more about it than one line under the answer.

While you listen, the player may also talk to you here, typed or dictated: answer as usual, and call `answer_to_game` with your answer as `text` and what they said, in their words, as `asked`, for both to show in the game's window (but for what is only about listening). Your listening goes on: do not start it again. Nothing is left to do when the result says it could not show by itself: say so in one line.

Who answers is the player's setting in the addon (tab Claude): the silent mode, or a session they see. While the silent mode runs, you get only the questions sent with the second: no need to stop it.

When the answer does not show by itself, the paste is the only way in: no /reload (the player turned that down), no simulated keys. If the output says it stopped listening, say so in one line and wait for the player. When the player asks you to stop, stop the background command. Each answer costs the player's usage like any message.

## The silent mode

When the player wants answers with no conversation open ("mode silencieux"), call `silent_mode` with `action: "start"` and `folder` set to this conversation's working folder (its CLAUDE.md and memory then apply to the answers). A hidden program then does what listening does, each answer by Claude Code without a window (with these tools alone and the modules as its instructions, which keeps answers cheap), copied with a sound; it keeps running when this conversation ends, until `action: "stop"`; after the computer restarts, it starts again when a Claude session opens these tools, or with Windows if the player asked for that (`action: "autostart"`, taken away by `"no_autostart"`; never unasked). `action: "check"` says what is missing when nothing answers. While it runs, a listening session gets only the questions sent with the setting "Who answers" on a session they see. All the conversations (tabs) of the window go to one Claude session, resumed from question to question and kept across restarts. Questions that overlap are answered at the same time, each beside the session in a run that is not saved, with a recap of the last questions; the session is told of them at its next question. The session is renewed by itself, with that recap, after an hour without a question or when it is very large (going on with it would use more), and when the player picks another model. The answer shows in the game's window by itself, with a sound made by the game, when the player's setting for that is on and the addon's files for it are there (a program of the plugin writes in the files made for that, the addon's `Inbox` folder and the `claude-in-wow_S001`... addons, as many as the player picks in the settings, never you); else it is pasted. Each answer tells the window the model that gave it and the tokens it took. The window has it all, nothing to set here: the model and its effort (buttons by the one that sends, also in the settings), and in the settings the renewal, answers at once or in turn, the sounds, sending by photo, and starting a new session (which forgets the rest). `action: "status"` says whether it runs, since when, how many answers, the session with its size and model, and its last log lines (a failed answer says why there).

When you answer in the silent mode yourself (the message starts with `[claude-in-wow, silent mode]`), your reply goes as it is into the game's window: write only the answer, with links to the game, and call neither `listen` nor `answer_to_game`.

## The web

- **Wowhead**, the version's own database: `https://www.wowhead.com/fr/quest=ID` for Retail, `/mop-classic`, `/tbc`, `/classic`, `/forever` before the language for the others (also `npc=`, `item=`, `zone=`; English without `/fr`). It has quest text, rewards and comments, but no coordinates.
- The interface's code, for addon questions: the public `Gethe/wow-ui-source` repository, a branch for each version (`live`, `classic`, `classic_era`, `classic_anniversary`, `forever`).

## The game folder

The tools find it; for anything they don't cover, read the files directly (Read, Grep), never change them while the game runs.

In a version's folder (such as `_retail_`):

- `Interface\AddOns\<Addon>\`: each addon's code and `.toc` (a version loads its own first: `_Mainline`, `_Mists`, `_TBC`, `_Vanilla`, `_Forever`...).
- `WTF\Account\<ACCOUNT>\SavedVariables\<Addon>.lua`: account-wide saved data; `...\<ACCOUNT>\<realm number>\<First-Last>\SavedVariables\` per character, and `AddOns.txt` (which addons are enabled).
- Useful data addons: Questie and QuestieDB (quests, NPCs, items, objects; `QuestieConfig.char[name].complete` = quests done), ForeverDungeonJournal (dungeon quests and bosses, French), AtlasLoot (loot tables), ItemQuesterForever (`turnedIn`), ChatLootsForever (French item name to ID), TradeSkillMaster (`TradeSkillMaster_AppHelper\AppData.lua`: prices), RareScanner, DBM.
- `Screenshots`, `Logs`.

## Answering

- Answer in the player's language, with names as the game writes them (French on a French client: the tools give French names when Questie has them).
- Coordinates are in percent of the zone map (x from the left, y from the top); "inside the instance" has no map position.
- Say where an answer comes from when it matters (the snapshot's age, prices' date, Questie vs Wowhead), and when you are not sure it is true of the version played.
- Settings may only be changed with the game closed; describe the change, or edit the file only once the player has quit.
- Never help automate gameplay (bots, scripted input, key-press programs): Blizzard forbids it. Give advice the player acts on.
