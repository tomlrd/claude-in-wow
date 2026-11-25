# Contributing to claude-in-wow

## Working together

1. Open an issue first for anything larger than a fix, so that nobody works for nothing.
2. Fork, make a branch, and open a pull request to `main`: nothing goes there otherwise. The tests run by themselves. By sending it, you agree that it becomes part of claude-in-wow under its [license](LICENSE).
3. One subject a pull request. Small ones are read sooner.

To try it in your game: `npm run play`. Everything on developing and releasing: [docs/releasing.md](docs/releasing.md).

## Where things are

`addon` is what goes in the game, `plugin` what runs on the computer (`server`: its program; `modules`: what Claude is told; `skills`, `commands`), `tests`, `tools`, `docs`. How the two parts talk: [docs/protocol.md](docs/protocol.md). In `addon`:

| Folder | What |
| --- | --- |
| `Core` | Texts, saved data, the modules' registry, Lua errors, start-up |
| `Data` | What is read from the game: character, quests, items, addons, and any function that only reads |
| `Window` | The Claude window: look (`Theme.lua`), Markdown, the conversation, the settings' page |
| `Modules` | One file per feature: this is where most changes go |
| `Inbox`, `Media`, `Libs` | Sound files for incoming answers, textures and fonts, embedded libraries |

## Adding a module

1. Make `Modules\MyModule.lua`, starting with `local addonName, ns = ...`.
2. Add its texts to `Locales\enUS.lua`, the source, and to the other languages when you speak them ([TRANSLATING.md](TRANSLATING.md)).
3. Declare it: `ns.Module({ key, category, order, title, tip, settings, changed, custom })`. `Core\Modules.lua` describes each field at its top. Its switch and its settings then show in the settings by themselves, in the tab of its category (`ns.Category` adds one).
4. Do nothing while it is off: test `ns.On("myModule")`, or undo what you did in `changed(on)`.
5. Add the file to `claude-in-wow.toc`, after `Window\ClaudeWindow.lua`. The game only sees a new file when it is next started.

To add something a question can be answered with, use `ns.Topic` (`Modules\Chat.lua`). To draw names in Claude's answers, use `ns.Decorate` and `ns.LinkKind`: `Modules\Places.lua` and `Modules\Players.lua` are the examples to follow.

## Claude's side

What Claude is told of a module (how to write what it draws, when to propose it) is a small text file of `plugin/modules`, named after the module's key. A player can change one or add some without touching the plugin: a `modules` folder in the folder the silent mode works in, where a file of the same name replaces the plugin's. Short is better, it is read again at each answer.

## The versions of the game

`Core\Compat.lua` (`ns.Game`) gives the quest log, the reputations, the spells, the bags and the rest the same way on every version: Retail, Mists, Titan, Anniversary, Era and Forever. Never call a function that only some have: add it there. `tests/versions_test.lua` runs the addon on each, with only the functions Blizzard documents for it.

## Rules

- What is new (`CHANGES`, `CHANGELOG.md`, the releases) only says what changed for the player: what is added, better or put right. Never how it is made: no code, files, tests, tools nor versions nobody had.
- Code and comments in English, texts shown to the player in `Locales` only.
- No polling: use events and hooks. The only timer is the one that waits for an answer, while one is due.
- Nothing plays in the player's place: a click is one action, and nothing that loses something (selling, destroying, mail, trade, auctions) has a button.
- The addon needs no other addon, and is made for none in particular.
- The settings stay in the Claude window: no entry in the game's AddOns options.
- A function is only added to `Data\Functions.lua` by the plugin's `tools/functions.mjs`, never by hand.

## Testing

```
npm test
```

runs everything: the texts, each version of the game and each language, the addon, the plugin. It needs [Node.js](https://nodejs.org) 18 or newer and Lua 5.2 (set `LUA` to the one to use when it is not found). The game is a stand-in, so it also has to be tried in the game.

The plugin's tests use the clipboard's commands and real programs: run them alone, and run them again if several fail at once.

Unofficial: claude-in-wow is not affiliated with Anthropic nor Blizzard.
