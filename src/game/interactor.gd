class_name Interactor
extends Node
## Gives the Interact button to the nearest Interactable in the hero's reach (the merchant, the
## forge, an encounter, a pact's stele...), and uses it when the "interact" action is pressed
## (the HUD's button, E / F, the right trigger). Nothing in reach, a menu open: no button.

## The thing the button would use changed (null: nothing in reach).
signal focus_changed(target: Interactable)
## The hero used `target`.
signal used(target: Interactable)

var player: Player
## Whether the button is off (a menu is open, the trial of the Threshold...).
var is_blocked := func() -> bool: return false
## What the button would use now (null: nothing).
var focus: Interactable

var _was_down := false
## The last focus_changed said something was in reach.
var _has_focus := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _physics_process(_delta: float) -> void:
	_set_focus(_nearest())
	# A press, not a hold: the action going down (a touch, a key, a trigger).
	var down := Input.is_action_pressed(&"interact")
	if down and not _was_down:
		interact()
	_was_down = down


## Uses what is in reach. False if nothing is.
func interact() -> bool:
	if not is_instance_valid(focus) or player == null or not focus.can_use(player):
		return false
	var target := focus
	target.use(player)
	used.emit(target)
	return true


func _nearest() -> Interactable:
	if player == null or not is_instance_valid(player) or player.is_dead or not player.is_inside_tree() or is_blocked.call():
		return null
	var best: Interactable = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(Interactable.GROUP):
		var thing := node as Interactable
		if thing == null or not thing.can_use(player):
			continue
		var distance := thing.global_position.distance_to(player.global_position)
		if distance < best_distance:
			best = thing
			best_distance = distance
	return best


func _set_focus(target: Interactable) -> void:
	var current: Interactable = focus if is_instance_valid(focus) else null  # (gone with its floor)
	if target == current and (target != null) == _has_focus:
		return
	if current:
		current.focused = false
	focus = target
	_has_focus = target != null
	if target:
		target.focused = true
	focus_changed.emit(target)
