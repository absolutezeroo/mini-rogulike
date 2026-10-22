class_name PlayerDef
extends Resource
## Starting setup and progression of the player character.

@export var display_name: String = "Hero"
@export var frames: SpriteFrames
@export var frames_offset: Vector2 = Vector2(0, -9)
@export var color: Color = Color("4fd1c5")
@export var radius: float = 11.0
@export var base_stats: StatBlock

@export_group("Starting kit")
@export var starting_equipment: Array[EquipmentDef] = []
@export var starting_items: Array[ItemDef] = []
## Skills the hero always has (the roll), on the first buttons. The weapon adds its own
## skills and a tome can teach one more (see Player.SKILL_COUNT).
@export var innate_skills: Array[SkillDef] = []
## Places added to every compartment of the bag (each has its own: BagCategoryDef.capacity in
## data/items/bag_categories.tres). 0: the compartments as they are.
@export_range(0, 40) var bag_bonus: int = 0

@export_group("Charged attack")
## Seconds the attack button must be held before the weapon's charge starts filling: a tap is
## always a plain attack (Player, AttackCharge).
@export_range(0.05, 0.6, 0.01) var charge_delay: float = 0.22
## Played when the charge is full.
@export var charge_full_sound: AudioStream

@export_group("Leveling")
@export var xp_base: int = 20
@export var xp_growth: float = 1.5
## Added to the base stats on every level up.
@export var level_bonus: StatBlock


func xp_to_next_level(level: int) -> int:
	return roundi(xp_base * pow(xp_growth, level - 1))
