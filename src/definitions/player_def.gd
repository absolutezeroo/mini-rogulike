class_name PlayerDef
extends Resource
## Starting setup and progression of the player character.

@export var display_name: String = "Hero"
@export var color: Color = Color("4fd1c5")
@export var radius: float = 11.0
@export var base_stats: StatBlock

@export_group("Starting kit")
@export var starting_equipment: Array[EquipmentDef] = []
@export var starting_items: Array[ItemDef] = []
## Up to 3 skills, mapped to the skill buttons in order.
@export var skills: Array[SkillDef] = []
@export_range(4, 40) var inventory_size: int = 16

@export_group("Leveling")
@export var xp_base: int = 20
@export var xp_growth: float = 1.5
## Added to the base stats on every level up.
@export var level_bonus: StatBlock


func xp_to_next_level(level: int) -> int:
	return roundi(xp_base * pow(xp_growth, level - 1))
