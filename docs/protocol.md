# How the addon and the plugin talk

An addon reads no file and reaches no network while the game runs. Everything below works around that with what the game allows.

## From the game to the plugin: a photo

`addon/Modules/Photo.lua` draws the data over the screen for an instant, in squares, and takes a screenshot; `plugin/server/photo.mjs` reads it back from the PNG in the `Screenshots` folder. It is JSON, deflated when the player has not turned that off:

| Key | What |
|---|---|
| `version`, `game`, `key`, `savedAt` | the addon's version, the game's, the character, when (unix seconds) |
| `character`, `errors`, `warbandBank` | the game state, as the saved data holds it |
| `question` | `{ id, kind, text, at, tab, read, signal, slot, got, model, effort, newSession, options }`, when a question was asked |
| `spare` | places set apart for what is said outside the game (below) |

`question.options`: how to answer (`language`, `renew`, `remember`, `slots`...), `off`: the modules turned off, `blocks`: the newer blocks this addon knows, `by`: who answers (`silent` or `session`).

## From the plugin to the game: a sound and an addon

- **A signal**: `Inbox\NNN.wav` are empty when the game starts. The plugin fills one; played, an empty one is over at once, a filled one is still playing a moment later. `Inbox\aNNN.wav` says the same way that a question was received. They are listened to every second, only while something is due.
- **A slot**: each `claude-in-wow_SNNN` is an addon loaded on demand, of one Lua file. The plugin writes the answer there, the addon loads it. Each is read once until the next `/reload`.

Without them (the sound off, no slot left) the answer is in the clipboard, for the player to paste.

## Updates

A photo whose question is of kind `update` (`update: { check, from }`) asks the plugin, not Claude, to look for one or to update. The answer, in the question's slot, and what is out, in the addon `claude-in-wow_News` read at each login or reload, are the same text: `[claude-in-wow update]`, then `name=value` lines (`addon`, `plugin`, `pluginNow`, `waits`, `addonState`, `pluginState`, `checked`, `notes.<language>`). What is out is read from `release.json`, in the releases that `tools/package.mjs` prepares.

## An answer

```
[claude-in-wow réponse <at> session= n= s= m= c= t= r= d= p= l=]

<Markdown>
```

`at` is the question's; then the session, the question's number in it, seconds, model, thousands of tokens held, tokens taken and those from the cache, their detail, the plan's windows, the language. An unknown mark is ignored.

What the player said in a session of Claude, not in the game, comes as `[claude-in-wow dit <at>]`, their words, then the same mark and the answer. The addon sets five places apart for it (`spare: { at, list: [{ signal, slot }] }`, in each photo and in the saved data); the plugin takes them in order, each once.

## Blocks in an answer

In a code block of their own, starting with `[claude-in-wow] <kind>`: `questions`, `buttons`, `marks`, `string <name>`, `route <name>`, `why`. What each holds is in `plugin/modules`, where Claude is told; the addon reads them in `addon/Modules`. A new kind goes in `options.blocks` (addon) and `NEWER` (`plugin/server/questions.mjs`), so that an older addon is never sent it.
