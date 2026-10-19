class_name FloorEventDef
extends ContentDef
## A floor that is not like the others: haunted, a treasure vault, a swarm, pitch dark...
## Announced when you arrive. Some normal floors get one (DungeonConfig.floor_event_chance),
## never the first floor nor boss floors. Listed in content_db.tres > Floor Events.
## `display_name` is the banner, `description` the line in the log, `color` both.

@export_group("Monsters")
## Multiplies how many monsters each room gets.
@export var monster_count: float = 1.0
@export var monster_hp: float = 1.0
@export var monster_damage: float = 1.0
## Added to the chance for each monster to be an elite.
@export_range(0.0, 1.0) var elite_chance_bonus: float = 0.0

@export_group("Floor")
## Its own look over the biome's (screen grade, glow, mist, particles...); the biome's sounds stay.
@export var atmosphere: AmbienceDef
## Multiplies the floor's light color (a red moon tints everything).
@export var ambient_tint: Color = Color.WHITE
## Multiplies the darkness (below 1 = darker).
@export var light: float = 1.0
@export_range(0, 10) var extra_chests: int = 0
@export_range(0, 10) var extra_hazards: int = 0
@export_range(0, 4) var extra_encounters: int = 0
## The merchant is always there.
@export var merchant: bool = false

@export_group("Rewards")
## Multiplies all the gold that drops.
@export var gold: float = 1.0
## Multiplies the quality of everything that drops (see LootRoller).
@export var loot_quality: float = 1.0
