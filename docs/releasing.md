# Developing and releasing

## Every day

1. `git switch -c my-change`
2. Change things in `addon` or `plugin`.
3. `npm run play`: puts the addon in your games. Then `/reload`, or start the game again when it says so (a new file).
4. The plugin: add this folder once as a marketplace (`/plugin marketplace add <this folder>`, `/plugin install wow-mcp@claude-in-wow`): Claude Code reads it where it is. A change is seen at the next start of the silent mode (say "relance le mode silencieux" to Claude).
5. `npm test`, commit, push the branch, open a pull request.

`npm run play` installs a development copy: the updates told in the game never replace it.

## On your computer

No key is needed to work on it. A `.env` file, which git never takes, may hold:

| Name | What |
|---|---|
| `LUA` | the Lua the tests use, when it is not found by itself (a program and its first arguments) |

[`.env.example`](../.env.example) is there to copy. CurseForge's key is never in it: it only goes in the repository's secrets.

## A new version

1. `npm run new-version -- 1.1.0 1.1.0` (the addon's, then the plugin's if it changed). It says what is missing.
2. What is new, in `CHANGES` of each `addon/Locales` (`"= 1.1.0",` then its lines, at the top, as many in each language), and in `CHANGELOG.md` (`## 1.1.0`). Players read them: only what is added, better or put right for them, never how it is made.
3. When the new plugin needs the new addon: `needsAddon` in `package.json`.
4. `npm test`, commit, merge to `main`.
5. `git tag v1.1.0` then `git push origin v1.1.0`.

The tag does the rest (`.github/workflows/release.yml`): the tests, the zips, the release on GitHub with `release.json` (which the players' plugins read to tell them), and the zip on CurseForge. When a step fails, nothing after it is done: put it right, delete the tag (`git push --delete origin v1.1.0`, `git tag -d v1.1.0`) and set it again.

The players' plugins see the release within a day. Those who took the plugin from GitHub get it through `claude plugin update`.

## Setting CurseForge up, once

1. Create the project on [authors.curseforge.com](https://authors.curseforge.com) (its moderators look at it first). Name: `claude-in-wow`; license: GPL v3; source: this repository.
2. Its number is in "About project". In the repository's settings, *Secrets and variables*, *Actions*, *Variables*: `CF_PROJECT_ID`.
3. A key from CurseForge's *API tokens* page. Same place, *Secrets*: `CF_API_TOKEN`. Never anywhere else, nor in a file.
4. The next tag sends the zip there. Without these two, the step says so and does nothing.

`CURSEFORGE` in `plugin/server/updates.mjs` and `tools/package.mjs` hold the project's page: change them if its address is another.
