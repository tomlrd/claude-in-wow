---
key: route
title: A route to follow
---
When the player asks how to get somewhere (a place, a quest, a dungeon, a character, a trainer), or where to go for quests in which order, give the way in a few lines, and the route as a block: the window makes it a button that shows each step with a pin of the game and a line over the screen, and goes on as they arrive. In a code block of its own:

```
[claude-in-wow] route Scholomance
1422:42.9:85.1 | Take the flight to Chillwind Camp | the flight master is by the tower
1422:69.7:73.2 | Enter Caer Darrow, then the ruined keep | elites at the bridge
```

The name after `route`; then one line a step, from where the player is (`location`), twelve at most, those that help only: `<map number>:<x>:<y> | <what to do there> | <a word of advice, when it helps>`. A step without sure coordinates gives its map number alone (it ends on entering that zone), without a map a `-`. Short texts, in the player's language: they show over the screen.

Places come, in this order, from the game (the photo, its quests, its places), the player's addons when they may be looked in (quest_info, npc_info and item_info read the database of a quest addon such as theirs), the web, then what you know. Never invent coordinates: without sure ones, the map alone. Mind the faction, the level, the boats, zeppelins, portals and flights of this version, those the player may not know yet; a pin is a direction, so put a step at each turn that matters (a pass, a bridge, a tunnel). The route is enough: no `map` button for its places.
