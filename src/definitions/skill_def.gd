class_name SkillDef
extends Resource
## An active ability on a cooldown. Usable by the player and by monsters.
## A skill is just a list of effects, so new skills rarely need new code.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Very short text drawn on the skill button.
@export var short_label: String = "SK"
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export var cooldown: float = 6.0
@export var effects: Array[Effect] = []
@export var sound: AudioStream

@export_group("Monster AI")
## Monsters only use the skill when their target is between these distances.
@export var ai_min_range: float = 0.0
@export var ai_max_range: float = 240.0
## Monsters only use the skill below this fraction of their HP (1 = any time).
@export_range(0.0, 1.0) var ai_below_hp_ratio: float = 1.0
## Monsters: telegraph time before the skill goes off (glow, cast animation). 0 = instant.
@export var cast_time: float = 0.0
## Monsters: red circle drawn around the caster while casting (0 = none).
@export var telegraph_radius: float = 0.0


func activate(user: Actor, aim: Vector2) -> void:
	Sfx.play_at(sound, user.global_position)
	for effect in effects:
		effect.apply(user, aim)
