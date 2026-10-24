class_name LightSource
extends Node2D
## A light in the floor's stepped light (LightField): a lantern, a campfire, the hero's torch,
## a glowing shot, a flash. It lights its own tile at `level`, the next ones one level less...
## Lights that stay put are worked out once (around corners, blocked by walls); moving ones
## (`moves`) every frame. Hide it to put it out.

const GROUP := &"light_sources"

## Bumped whenever a light that stays put appears, goes out or changes: the field redoes them.
static var revision := 0
## Every light in the tree, in the order they came in (the group's): the field walks it for the
## moving ones every frame without asking the tree for the group (docs/performance.md).
static var in_tree: Array[LightSource] = []

@export var color: Color = Color(1, 0.85, 0.6):
	set(value):
		color = value
		_changed()
@export_range(0, 15) var level: int = 10:
	set(value):
		level = value
		_changed()
## Counted above the floor's own light (flashes show even in daylight).
@export var relative := false
## Follows something around (the hero, a shot): redone every frame.
@export var moves := false


## Counted in the field's still lights right now (lit, in the tree, not moving).
var _counted := false


func _enter_tree() -> void:
	add_to_group(GROUP)
	in_tree.append(self)
	_changed()


func _exit_tree() -> void:
	in_tree.erase(self)
	_changed(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_changed()


## Its level on a floor whose own light is `ambient`.
func level_over(ambient: int) -> int:
	return mini(LightField.MAX_LEVEL, level + ambient) if relative else level


func is_lit() -> bool:
	return level > 0 and is_visible_in_tree()


## A still light that is, or was, shining: the field must redo them (an unlit one changes nothing).
func _changed(leaving := false) -> void:
	if moves:
		return
	var lit := not leaving and is_inside_tree() and is_lit()
	if lit or _counted:
		revision += 1
	_counted = lit
