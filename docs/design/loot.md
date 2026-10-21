# Loot, the belt, the merchant and the forge

## Loot, gold and the merchant

- **Item level**: every weapon and armor is as strong as the floor it was found or bought on
  (`ItemLevelRules`, `data/items/item_levels.tres`), and it never grows after that. A floor-2
  katana is better than a floor-1 one; to get stronger you have to loot. Each level above 1 adds
  2 damage per second to a weapon (the same for a quick rapier and a slow hammer: the slow one
  gets more per hit), 1.5 Health to a body armor and 1 to a helm. Monsters and bosses grow at the
  same pace (+32% / +33% Health per floor, `dungeon_config.tres` > Difficulty), so a hero who
  keeps his first sword falls behind. Rarity and affixes come on top. The level shows on the slot
  ("Lv 7"), first on the item card, and first in the comparison with what you wear ("+3 item
  levels, +5 damage"). The merchant sells at the floor's level; a forge keeps the weapon's level.
- **Rarity**: found equipment can come out **Magic** (blue, 1 affix), **Rare** (yellow, 2) or
  **Epic** (purple, 3), with more damage and bonuses (`ItemRarity`). Affixes (`data/affixes/`,
  `ItemAffixDef`) add stats ("Sharp", "of the Bear"...) or set enemies on fire, poison or slow
  them ("Burning", "Venomous", "Frozen"). Some act like a perk while worn (`ItemAffixDef.passives`,
  joined to the hero's `PerkSet` by `set_gear()`; their `description` shows on the item):
  **Vampiric** (heal on kill), **Shocking** (every 4th hit chains lightning), **of Embers**
  (burning enemies explode), **Shattering** (+25% on slowed enemies), **of Echoes** (skills may be
  ready again at once), **of Thorns**. Rare and Epic items on the floor shine with a beam.
  `LootRoller` makes rolled copies; the plain .tres is the Common version. Chances grow with depth
  (`dungeon_config.tres` > Loot) and with the source: elites, chests and bosses drop better.
- **Gold** drops from monsters (always from elites and bosses), chests and sometimes crates, and
  flies to you. It lasts one run. Potions and other consumables you already carry plenty of
  (4 of the same, `consumable_carry_cap`) drop as gold instead: no bag full of potions.
- **The merchant** (`data/shop/merchant.tres`, `Merchant`, `ShopPanel`) waits in a quiet room on
  some floors: walk up to him to buy equipment (better than average), potions and sometimes a
  tome, or to sell what you carry. Every item has a `value`; the price grows with rarity and depth.
  **Reroll** buys a new stock (`ShopDef.reroll_cost`, +`reroll_cost_growth` each time at the same
  merchant). **Lock** keeps an entry through rerolls; if you don't buy it, it waits at the next
  merchant at the same price (`World.kept_stock`, kept in saved runs).

## Room in the bag

The bag (`Inventory`, 16 places, `PlayerDef.inventory_size`) fills with gear fast; three things
keep it from getting in the way.

- **Stacks**: identical items share one place and one slot ("x3"), potions and runes as before,
  and now rolled gear too. Two drops are identical when their `ItemDef.stack_key()` is: the same
  .tres for plain items; for rolled equipment the same base item, rarity, item level, affixes (in
  order: they make the name) and set runes, which is exactly what a saved run keeps of it
  (`LootRoller.to_data`), so stacks come back after Continue. The bag counter ("Bag 5 / 16") and
  "bag full" count places, not items: a full bag still takes one more of a stack. Equipping,
  dropping, selling or dismantling takes one from the stack; equipping one of a stack checks
  there is a place for what was worn (it frees none). A weapon with a rune set leaves its stack.
- **Dismantle** (`DismantleRules`, `data/items/dismantle.tres`): any piece of gear in the bag
  breaks down into gold, anywhere (two taps on the item card: Dismantle, then "Sure? +12 gold").
  Gold = value x rarity (`ItemRarity.VALUE`) x `gold_share` (0.15) x (1 + `gold_per_level` (0.2)
  per item level above 1), plus 0.15 of the value of the runes set in it (they break with it).
  That is 40% of what the merchant pays for it on its own floor (`sell_ratio` 0.25 of prices
  x1.5, +20% a floor), and less deeper: carrying gear to him stays worth it, and dismantling is
  never a way to make gold. Never what is worn, potions, runes, tomes or keys.
- **Dismantle the worse**: the bag's button breaks down, after a confirmation that shows them and
  the gold, every piece **worse** than what is worn in its slot (`ItemCompare.is_worse`,
  `Player.worse_gear()`). Worse means: not a higher item level, not rarer, no rune set, no affix
  (or weapon status) doing something the worn one doesn't (Vampiric, Burning...); and then, if it
  is of a lower level or rarity, not better at its main job (damage per second for a weapon;
  Health, Armor or Damage for an armor), quicker or lighter does not save it; of the same level
  and rarity, not one stat in its favour. Nothing is worse than an empty slot.
- **Auto loot** (Options, `Settings.auto_loot`, `Player.wants()`): what walking over an item does.
  **All** takes everything (the old way). **Better only** (the default) takes gear only when it is
  not worse than what is worn (the same rule as above), and every potion, rune, tome and key.
  **By hand** takes no gear. Gold always flies to the hero, and the hidden floor's Bone Key is
  always taken. Gear left on the ground shows, while the hero stands on it, on a small board low
  on the screen (`LootPrompt`): its slot, name, how it compares, and **Take**. Better only is the
  default because on a phone stopping to tap every drop mid-fight is a chore, while taking
  everything is what filled the bag with worse gear; what it leaves is still one step away.
- **Bag full**: an item that has no room stays on the ground; a toast says so ("Your bag is full:
  ... Dismantle or drop something", at most every 4 s) and the board's button opens the bag.

## The belt

Potions, bombs and scrolls don't take room in the bag: they go on the **belt** (`Belt`),
3 slots of one kind each, stacking up to 9. Each slot has its own button on screen, so you choose
what to drink or throw. When the belt is full, the rest goes to the bag; the bag screen moves
consumables between the two ("To belt" / "To bag"). The merchant buys from the belt too.

## Runes and the forge

- **Runes** (`RuneDef`, `data/runes/`, content_db > Runes): stones carved with a glyph of one of
  the five families. Bosses always drop one (`boss_runes`), elites and up often
  (`ranked_rune_chance`, 30%), chests sometimes (`chest_rune_chance`, 20%), plain monsters rarely
  (`rune_chance`, 1%). They are not among the random items: no merchant sells them.
  - Inferno: **Ember** (hits may set enemies on fire), **Pyre** (enemies dying burning explode).
  - Frost: **Rime** (hits chill), **Shatter** (critical hits release a frost shockwave that slows).
  - Blood: **Leech** (your hits heal 10% of their damage), **Fury** (wounded you hit harder, kills heal).
  - Storm: **Spark** (every 3rd hit chains lightning), **Gale** (your roll throws a gust).
  - Arcane: **Echo** (skills may be ready again at once), **Prism** (one more projectile; with Hydra's Quiver, 2 more at most, the volley sharing its damage).
- **Sockets**: every weapon has 1 to 3, by rarity (`ItemRarity.SOCKETS`: Common and Magic 1,
  Rare 2, Epic 3). A rune works like a perk while its weapon is worn (`RuneDef.passives`, through
  `PerkSet.set_gear`); two identical runes count twice. Set runes show on the weapon's details,
  with its empty sockets, and are saved with it.
- **The forge** (`data/forge/smith.tres`, `ForgeDef`, `Forge`, `ForgePanel`): Brann the Smith,
  his anvil and glowing coals, in a quiet room of some floors (`forge_chance` 30%, +15% for each
  floor without one, never on boss floors). Walk up to him: pick a weapon (the worn one or one
  in the bag), set runes from the bag into its free sockets for free, or pick a socket and take
  its rune back out, intact, for gold (`removal_price` + `removal_price_per_depth`). A plain
  weapon becomes its own copy the first time a rune goes in. Debug panel: "Forge here", "Every rune".
