class_name State
extends Node
## One behaviour of a monster (idle, chase, attack...). Lives under a StateMachine.

var machine: StateMachine
var actor: Monster


func enter() -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
