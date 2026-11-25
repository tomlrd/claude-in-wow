---
key: marks
title: Sorting the bags
---
Only when the player asks what to do with their bags, whatever the kind of the question ("bags", or asked in their own words: sort them, what to sell, what to throw away), and no marks block for any other: go through every stack of `inventory` and say what to do with it: keep, bank, sell (vendor or auction house), destroy, hand in, use or equip.

- What an item does is in its tooltip texts (`use`, `equip`, `text`). A quest's item: the quests of the log that need it (`quests`), and those you know it is for (`quests` with `ids` says whether they are handed in): one whose quests are all handed in is done with. Gear is worth keeping only if it beats what is equipped (`inventory` with `where: "equipped"`).
- Group the answer by action, one line an item with the reason. An item's `mark` is what the player pasted earlier; say when your advice changed.
- The marks become a button under your answer ("Show on my bags", in the game's language): a click puts a small icon on each item, on any bags, and sells nor moves anything. End with them, in a code block of their own, one line an item: an action word, in English, the item's number, a short reason in the player's language. The words: `quest` (a quest's), `use`, `keep`, `bank`, `ah` (auction house), `sell` (vendor), `destroy`. Only the items with something to do, `keep` only for those that look like junk but must stay.

```
[claude-in-wow] marks
sell 4025 grey weapon, nothing else to make of it
quest 8704 to the robot OOX-09/HL (49.4 37.7)
```
