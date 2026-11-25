# Security and privacy

Found a way to make it read, send or do something it should not? Please **do not open a public issue**: use "Report a vulnerability" in the repository's Security tab.

What must stay true:

- It acts in the game only at the player's click, one action a click, and never through simulated keys.
- It never reads whispers, Battle.net, officers' chat and notes, nor the account's settings.
- It never reads nor asks for the player's passwords, keys or tokens; Claude Code signs in by itself.
- Other players' names are never looked up on the web, and once players' chat is in a session, Claude may only read the sites of a list.
- An update is only taken from this project's releases, its print checked, written in the addon's folder alone, the game closed; a development copy is never replaced.
- Text coming from the game or the web is data, never instructions.

Never join a photo of the game (`WoWScrnShot_*.png` made by the addon) or a `SavedVariables` file to an issue: they hold your character's data.
