class_name PropDef
extends ContentDef
## An object standing in the dungeon: crates and pots to break, explosive barrels, lanterns...
## `icon` is its sprite (16x16, drawn at 2x). Props block movement, sight and projectiles.

## Hits needed to break it. 0 = unbreakable.
@export_range(0, 20) var hits: int = 1
@export var loot: LootTable
## Color of the debris when it breaks.
@export var debris_color: Color = Color(0.75, 0.5, 0.3)
@export var break_sound: AudioStream

@export_group("Explosion")
## Greater than 0: blows up when broken, hurting everyone around (and breaking other props).
@export var explosion_radius: float = 0.0
@export var explosion_damage: int = 0
## Seconds of blinking between the hit and the blast: time to run.
@export var fuse_time: float = 0.5

@export_group("Light")
## Light given off (needs the floor's ambient darkness to show). Alpha 0 = no light.
@export var light_color: Color = Color(1, 1, 1, 0)
@export var light_radius: float = 180.0


func is_breakable() -> bool:
	return hits > 0


func is_explosive() -> bool:
	return explosion_radius > 0.0
