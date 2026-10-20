class_name OathDef
extends Resource
## An oath: a way to start a run, sworn before it begins ("X, but Y"). Opened at the end of a
## branch of the Tree of Souls (SoulNodeDef.oath). Not in the daily run (everyone starts the same).

@export var id: StringName
@export var display_name: String
## The rule, in plain words: what you get and what it costs.
@export_multiline var description: String
@export var icon: Texture2D
@export var color: Color = Color.WHITE
## The weapon the run starts with (null: the usual one).
@export var starting_weapon: WeaponDef

@export_group("The hero")
## Added to the hero's starting stats.
@export var bonuses: StatBlock
## Multiplies the hero's starting max Health and move speed.
@export var max_hp_scale: float = 1.0
@export var move_speed_scale: float = 1.0
## Added to the critical hit multiplier (Combat.CRIT_MULTIPLIER x1.75 + this).
@export var crit_damage_bonus: float = 0.0

@export_group("The run")
@export var gold_scale: float = 1.0
@export var loot_quality_scale: float = 1.0
@export var shop_price_scale: float = 1.0
