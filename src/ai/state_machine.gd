class_name StateMachine
extends Node
## Runs one State at a time. Every child State node is a possible state,
## reachable by its node name: transition_to(&"Chase").

@export var initial_state: State

var current: State


func _ready() -> void:
	var monster := owner as Monster
	for child in get_children():
		if child is State:
			child.machine = self
			child.actor = monster
	current = initial_state
	if current:
		current.enter()


## Thinks nothing while the debug panel's No AI is on (Monster.ai_frozen()): the state waits as it
## was, and goes on once it is off.
func _physics_process(delta: float) -> void:
	if current and not current.actor.is_dead and not current.actor.is_falling and not current.actor.ai_frozen():
		current.physics_update(delta)


func transition_to(state_name: StringName) -> void:
	var next := get_node_or_null(NodePath(state_name)) as State
	if next == null:
		push_error("Unknown state: %s" % state_name)
		return
	if current:
		current.exit()
	current = next
	current.enter()
