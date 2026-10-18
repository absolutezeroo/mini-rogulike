class_name ChestDef
extends ContentDef
## A treasure chest. Opens when the hero walks up to it and spills random items.
## Some are trapped (`trapped_chance`): they blow up or let monsters out, and keep a single item.
## A trapped chest rattles now and then: watch before you touch.
## `icon`: closed and open frames side by side (16x16 each).

@export_range(0, 8) var items_min: int = 1
@export_range(0, 8) var items_max: int = 2
## How good the items are (see LootRoller): 1 = like a monster's drop.
@export var loot_quality: float = 1.5
## Coins inside (plus one per floor).
@export var gold: Vector2i = Vector2i(5, 15)
@export var open_sound: AudioStream

@export_group("Trap")
@export_range(0.0, 1.0) var trapped_chance: float = 0.0
@export var trap_sound: AudioStream
## Monsters jumping out of a trapped chest (from the act). 0 = never.
@export_range(0, 8) var trap_monsters: int = 0
## Blast of a trapped chest. 0 = never explodes.
@export var explosion_radius: float = 0.0
## Grows with depth and the difficulty.
@export var explosion_damage: int = 0
@export var fuse_time: float = 0.8
