class_name DifficultyDef
extends Resource
## How hard a run is. Chosen on the title screen before playing.
## Every number is a multiplier on the normal game (1 = unchanged).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var color: Color = Color.WHITE
## Beat a run on this difficulty to unlock this one. Empty = always available.
@export var unlocked_by: DifficultyDef

@export_group("Monsters")
@export var monster_hp: float = 1.0
## Damage of everything that hurts the hero: monster attacks and skills, traps, bursts.
@export var monster_damage: float = 1.0
@export var monster_speed: float = 1.0
## Wind-ups and casts: above 1 = more time to dodge.
@export var telegraph_time: float = 1.0
## Extra monsters in every room.
@export_range(0, 5) var extra_monsters: int = 0
@export var boss_hp: float = 1.0

@export_group("Rewards and help")
## Multiplies every monster's and prop's drop chance.
@export var loot_chance: float = 1.0
## Multiplies the souls earned at the end of a run.
@export var souls: float = 1.0
## Fraction of max HP healed when reaching a new floor.
@export_range(0.0, 1.0) var heal_on_new_floor: float = 0.0
## Multiplies the floors' darkness (below 1 = darker).
@export var light: float = 1.0
