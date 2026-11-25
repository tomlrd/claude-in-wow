# Translating claude-in-wow

Every text of the addon is in the `addon/Locales` folder, one file a language. English
(`enUS.lua`) has them all; the other files have the same names with the translated
text. A text a language does not have is shown in English, so a translation may be
partial, and grow little by little.

| File | Language | Also used for |
|---|---|---|
| `enUS.lua` | English (the source) | enGB, and any language without a file |
| `frFR.lua` | French | |
| `deDE.lua` | German | |
| `esES.lua` | Spanish | esMX |
| `itIT.lua` | Italian | |

## Correcting or completing a language

1. Open the language's file, and change the text between the quotes.
2. A missing text: copy its line from `enUS.lua`, under the same comment, and translate it.

```lua
APPLY_MARKS = "Show on my bags (%d items)",          -- enUS.lua
APPLY_MARKS = "Afficher sur mes sacs (%d objets)",   -- frFR.lua
```

## The rules

- **Never change a name** (`APPLY_MARKS`), only its text.
- **Keep each `%s` and `%d`**: they become a name and a number. If your language needs them
  in another order, number them all: `"%2$s, %1$d"`. `%%` is a percent sign.
- In dates, `%d`, `%m`, `%H`, `%M` are the day, the month, the hour and the minutes: put them
  in your order.
- **Keep the codes** `|cff...|r`, `\n` and `\"` as they are.
- **Lists** (`HELP_LIST = { "...", "..." }`) keep their number of lines.
- Use **the game's own words** in your language (bags, quest log, guild bank, reputation...),
  and the polite form the game uses with the player.
- Short is better: buttons are small.
- `Claude`, `Claude Code`, `claude-in-wow`, `/claude`, `/wow-mcp:setup` and
  `claude auth login` are not translated.

## A new language

1. Copy `Locales/enUS.lua` to `Locales/<code>.lua` (`ptBR`, `ruRU`, `koKR`, `zhCN`, `zhTW`...) and put
   your code in `ns.Locale("<code>", {`.
2. Add `Locales\<code>.lua` to `claude-in-wow.toc`, after the others, and its `## Notes-<code>:` line.
3. Translate. The plugin's own few messages are in its `server/locales/<xx>.json`: copy `en.json`.

## Checking

In the plugin's `tests` folder (Lua 5.1 or later):

```
lua locales_test.lua <folder of the addon>
```

It fails on what would break the addon (an unknown name, a `%s` missing, a list with
another number of lines), and lists what each language has not translated yet.
