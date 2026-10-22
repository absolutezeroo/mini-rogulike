class_name MouseControls
extends Node
## The mouse in a fight, on a computer: a click the HUD doesn't take (not on a button, the map,
## a hint) presses the action its button is bound to in data/ui/input_prompts.tres (the left one
## attacks, aimed as always at the closest enemy; the right one rolls), held as long as the
## button is. Like the touch controls it only presses input actions. Never from a finger: the
## mouse events a touch screen sends along are left alone.

## Mouse button -> the action it holds down (from the prompts' data).
var _bindings := {}
## Mouse buttons holding their action now.
var _held := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for entry in Prompts.DATA.actions:
		if entry.mouse != MOUSE_BUTTON_NONE and InputMap.has_action(entry.action):
			_bindings[int(entry.mouse)] = entry.action


func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.device == InputEvent.DEVICE_ID_EMULATION or not _bindings.has(int(click.button_index)):
		return
	var action: StringName = _bindings[int(click.button_index)]
	if click.pressed and not InputDevice.uses_touch():
		Input.action_press(action)
		_held[int(click.button_index)] = action
		get_viewport().set_input_as_handled()
	elif not click.pressed and _held.has(int(click.button_index)):
		_release(int(click.button_index))
		get_viewport().set_input_as_handled()


func _release(button: int) -> void:
	Input.action_release(_held[button])
	_held.erase(button)


func _notification(what: int) -> void:
	# Paused (a panel opened), the window left: the release would never come.
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		for button: int in _held.keys():
			_release(button)
