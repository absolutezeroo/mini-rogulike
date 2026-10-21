class_name WyrmTrait
extends MonsterTrait
## A long dragon: the monster is its head; a body of segments follows the path the head took
## (WyrmBody), wings flap on its sides, a pointed tail ends it. The body burns at a touch but
## only the head can be hurt.

@export var wing: Texture2D
## The segments, from the head back (repeated in turn when there are more segments).
@export var segments: Array[Texture2D] = []
@export var tail: Texture2D
@export_range(1, 16) var segment_count: int = 6
## World pixels between two segments along the path.
@export var spacing: float = 34.0
## Touching the body: this much damage (grows with depth like the dungeon's own).
@export var contact_damage: float = 6.0
@export var contact_knockback: float = 260.0


func on_spawn(monster: Monster) -> void:
	var body := WyrmBody.new()
	body.setup(monster, self)
	monster.add_child(body)


func describe() -> String:
	return tr("Its long body burns at a touch: only the head can be hurt")
