class_name TapGate
extends RefCounted
## "Tap or press to continue", the one way: the act and curse cards, a fragment of the past, a
## cinematic, the story and someone speaking all read their presses through a gate.
##
## - A press is a touch, a mouse click (left, right or middle: never the wheel, whose steps
##   come as pressed buttons, so scrolling skips nothing), a key (not its echo) or a gamepad
##   button; or only the accept actions (`keys = Keys.ACCEPT`: Enter, Space, A, and any action
##   in `accept_actions`), or no key at all (`Keys.NONE`: the screen reads its keys itself).
## - One finger is one press: a phone sends a touch and the click it emulates from it. The first
##   one is taken, its twin a few frames later is swallowed (`read()` says SWALLOW: the screen
##   marks it handled and does nothing), and so is the finger's release. Swallowing goes on after
##   the screen hid itself (`read(event, false)`), so the tap that closed a panel never reaches
##   a HUD button under it.
## - A grace after `open()` (`grace_frames`): the thumb that opened the screen is not a skip.

enum Keys { ANY, ACCEPT, NONE }

## What read() says of an event.
enum { IGNORE, TAKE, SWALLOW }

## Presses fewer frames apart than this are one (the touch and the click made of it come in
## the same frame; a deliberate double tap is slower).
const GAP_FRAMES := 3

## Which keys and gamepad buttons count: any, only the accept action, none.
var keys := Keys.ANY
## The actions a key or button must press with Keys.ACCEPT.
var accept_actions: Array[StringName] = [&"ui_accept"]
## Frames after open() during which nothing is taken.
var grace_frames := 0
var _opened_at := -1000
var _last_take := -1000
## A finger or button taken and not let go yet: its release is swallowed too.
var _holding := false


func _init(key_mode: Keys = Keys.ANY, grace: int = 0) -> void:
	keys = key_mode
	grace_frames = grace


## The screen just showed: the grace starts now.
func open() -> void:
	_opened_at = Engine.get_process_frames()


## IGNORE (not a press, or not now), TAKE (a press for the screen: act on it and mark it
## handled), SWALLOW (the twin or the release of a press taken: mark it handled, do nothing).
## `active` false (the screen is hidden or busy): only swallows.
func read(event: InputEvent, active: bool = true) -> int:
	var now := Engine.get_process_frames()
	if _is_pointer(event) and not event.is_pressed():
		if not _holding:
			return IGNORE
		# The emulated twin (the click a touch makes, or the touch a click makes:
		# project.godot emulates both ways) comes first: wait for the real one.
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_holding = false
		return SWALLOW
	if not _counts(event):
		return IGNORE
	if now - _last_take < GAP_FRAMES:
		return SWALLOW
	if not active or now - _opened_at < grace_frames:
		return IGNORE
	_last_take = now
	_holding = _is_pointer(event)
	return TAKE


## A press of a finger, a mouse button (not the wheel), a key or a gamepad button (by `key_mode`).
static func is_press(event: InputEvent, key_mode: Keys = Keys.ANY) -> bool:
	if event is InputEventScreenTouch:
		return event.is_pressed()
	if event is InputEventMouseButton:
		return event.is_pressed() and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	if event is InputEventKey or event is InputEventJoypadButton:
		if not event.is_pressed() or event.is_echo():
			return false
		match key_mode:
			Keys.ANY:
				return true
			Keys.ACCEPT:
				return event.is_action_pressed(&"ui_accept")
	return false


func _counts(event: InputEvent) -> bool:
	if keys != Keys.ACCEPT or not (event is InputEventKey or event is InputEventJoypadButton):
		return is_press(event, keys)
	return event.is_pressed() and not event.is_echo() and accept_actions.any(func(action: StringName) -> bool: return event.is_action_pressed(action))


static func _is_pointer(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	return event is InputEventScreenTouch
