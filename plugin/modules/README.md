# The modules, on Claude's side

Each file tells Claude, in the silent mode and when it listens to the game, about one thing the addon's window does with its answers. The key is the addon's module's (`ns.Module` in the addon): turned off there, Claude is told so.

Edit a file and its next session follows it. To change them without touching the plugin, put files in a `modules` folder of the folder the silent mode works in (such as `Documents\claude-in-wow\modules`): one with the same name replaces the plugin's, any other is added. Short is better: it is read again at every answer.

`{{places}}` is replaced by the place names of the player's game, `{{addons}}` by the player's addons that hold data of their own, `{{game}}` by the game's folder, `{{title}}`, `{{about}}`, `{{search}}` and `{{wowhead}}` by the version played (`server/flavors.mjs`), `{{sites}}` by the `sites` line of `45-web.md`: the only ones Claude may read once players' chat is in its session. A question's own data is added by `server/questions.mjs`.
