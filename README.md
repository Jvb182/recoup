# Recoup 1.1.0

A standalone WoW Forever addon (interface 16001). Three compact 36-pixel icons with stack counts, left to right: Eat, Drink, Bandage. **Eat** selects the food with the largest stated health recovery; **Drink** selects the drink with the largest stated mana recovery; **Bandage** selects the bandage with the largest stated healing and always targets you. When a stack/item runs out, the next best item is selected automatically as bags update. Mixed food/drink can appear on both buttons. Each click uses one serving; it never consumes items automatically.

Only carried food, drink and bandages are considered; potions are excluded. Bandages are ranked separately, so food buttons never consume a bandage. Items above your level or reported unusable by the client are skipped. Ranking uses the full serving's recovery from English tooltip text, including common percentage/per-second descriptions. It is not based on rarity or well-fed buffs. Unrecognized descriptions are skipped rather than guessed. Percentage estimates use your maximum health/mana. There is no bank scan and no cooldown-based fallback.

Normal food/drink requires being out of combat and sitting still long enough to consume it. The buttons use WoW's secure item actions. Item selection and protected layout updates are deferred during combat and resume afterward. Moving an item in your bags cannot change a button into a different item: selection uses item IDs.

## Use

- Enable Recoup in the AddOns list. Restart the client after first installation if it does not appear.
- Click Eat, Drink or Bandage. Hover for the selected item's full tooltip.
- Type `/recoup move` (or `/recoup unlock`), then left-drag the temporary **Drag here** handle to move the three icons. Click **Done** to hide the handle and lock it. Position and visibility save on logout/reload.
- `/recoup` shows/hides the bar; `/recoup reset` restores its position and shows it.
- `/recoup lock` / `/recoup unlock` locks/unlocks movement.
- `/recoup refresh` retries scanning item data; `/recoup help` prints commands.
- Optional key bindings: game Key Bindings > AddOns > Recoup.

## In-game checks

1. Carry two foods and two drinks of different strengths. Confirm the strongest health/mana choices and quantities.
2. Click each, confirm one serving is consumed, and let eating/drinking finish.
3. Exhaust the best item. Confirm the next-best selection; verify moving/splitting stacks is safe.
4. Check combined food/drink and level-restricted food. Potions must never be chosen. Check that Bandage chooses the strongest usable bandage and targets you even with another unit selected.
5. Enter/leave combat, move the bar, hide/show, reload, and try optional key bindings.

Offline tests cannot certify protected click behavior or every server-specific tooltip. This build targets English tooltips; report any skipped food/drink with its exact tooltip.

API reference: [Forever client secure item actions](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_FrameXML/SecureTemplates.lua) and [tooltip API](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TooltipInfoDocumentation.lua).

## Upgrade from SnackBar

Install both folders from the ZIP. The old SnackBar folder becomes **Recoup - legacy settings loader**, with no item-use code. Enable it alongside Recoup for the first login to copy position/visibility/lock preferences. Restart the client to discover Recoup. After the migrated settings survive a reload, the legacy loader can be disabled. Old Eat/Drink key binding IDs and the `/snack` command alias are retained.

Bandages obey the game's First Aid requirements, channel interruption and Recently Bandaged restriction. The selected bandage can be clicked in combat if the game allows it, but automatic selection changes wait until combat ends. The addon does not bypass those restrictions.

## Development

Install Python dependencies with `python -m pip install -r tests/requirements.txt`. Run `python tests/run.py` for offline Lua 5.1 tests and `python tests/package.py` to build the installable ZIP. CI runs tests and packaging on Windows and Linux; each run provides a ZIP artifact. Secure clicks and server-specific item tooltips still need in-game testing.
