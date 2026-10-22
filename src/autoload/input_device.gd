extends Node
## The device the player is using right now (autoload "InputDevice"): touch, keyboard and mouse,
## or a gamepad, and which family of gamepad (Xbox, PlayStation, Nintendo, any other) for its
## button names. The last real input decides; `changed` tells the HUD (touch controls or key
## prompts), the prompts (Prompts, PromptGlyph) and the menus (MenuNav: the focus frame).
##
## - A screen touch (a real one: the mouse's emulated touches don't count) is touch.
## - A key is keyboard and mouse; so is the mouse (a button, or moved far enough) after a gamepad.
##   After a touch the mouse changes nothing: on a touch screen with a mouse, the on-screen buttons
##   stay (the mouse presses them too), until a key is pressed.
## - A gamepad button, or a stick or trigger pushed past the dead zone
##   (InputPromptsDef.stick_deadzone: a drifting stick never takes over), is that gamepad.
## - The gamepad in use unplugged: back to the keyboard (touch on a phone).
## At start: touch on a phone, keyboard on a computer; a gamepad once it is used.

signal changed

enum Kind { TOUCH, KEYBOARD, GAMEPAD }

const PROMPTS: InputPromptsDef = preload("res://data/ui/input_prompts.tres")

var kind := Kind.TOUCH if OS.has_feature("mobile") else Kind.KEYBOARD
## The gamepad family in use (PadGlyphsDef.id), kept when the keyboard takes over again, so a
## page about the gamepad still names its buttons right.
var family: StringName = &""
## The pad that drove last (its device id), -1 if none yet.
var pad := -1
## Keys or a gamepad moved through a menu last (not the mouse, not a finger): the focus frame
## shows (MenuNav).
var navigating := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Real events reach the window before any node's _input (a panel may swallow one there).
	get_tree().root.window_input.connect(_read)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		family = PROMPTS.family_for(Input.get_joy_name(pads[0])).id


## Events pushed straight into the viewport (tests, TouchScroll) never pass by the window.
func _input(event: InputEvent) -> void:
	_read(event)


## Keys and gamepads (touch is the only other choice): prompts name keys and buttons.
func uses_buttons() -> bool:
	return kind != Kind.TOUCH


func uses_touch() -> bool:
	return kind == Kind.TOUCH


func uses_gamepad() -> bool:
	return kind == Kind.GAMEPAD


## The family whose button names prompts use (the last pad's, or the fallback one).
func pad_glyphs() -> PadGlyphsDef:
	return PROMPTS.pad(family)


## Switches to `new_kind` (and for a gamepad, `new_family`); tests and the input itself call it.
func use(new_kind: Kind, new_family: StringName = &"") -> void:
	var family_changed := new_family != &"" and new_family != family
	if new_family != &"":
		family = new_family
	if new_kind == kind and not family_changed:
		return
	kind = new_kind
	if kind == Kind.TOUCH:
		navigating = false
	changed.emit()


func _read(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event.device != InputEvent.DEVICE_ID_EMULATION:  # the mouse's own touches
			use(Kind.TOUCH)
	elif event is InputEventKey:
		if event.pressed:
			_navigate(true)
			use(Kind.KEYBOARD)
	elif event is InputEventMouseButton:
		if event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:  # (a touch's mouse)
			_navigate(false)
			if kind == Kind.GAMEPAD:
				use(Kind.KEYBOARD)
	elif event is InputEventMouseMotion:
		# In screen pixels: the canvas's scale must not make a twitch look big.
		var motion := event as InputEventMouseMotion
		if motion.device != InputEvent.DEVICE_ID_EMULATION and motion.screen_relative.length() >= PROMPTS.mouse_threshold:
			_navigate(false)
			if kind == Kind.GAMEPAD:
				use(Kind.KEYBOARD)
	elif event is InputEventJoypadButton:
		if event.pressed:
			_use_pad(event.device)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= PROMPTS.stick_deadzone:
			_use_pad(event.device)


func _use_pad(device: int) -> void:
	pad = device
	_navigate(true)
	use(Kind.GAMEPAD, PROMPTS.family_for(Input.get_joy_name(device)).id)


func _navigate(on: bool) -> void:
	if navigating != on:
		navigating = on
		if kind != Kind.TOUCH:
			changed.emit()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		if pad == -1:
			family = PROMPTS.family_for(Input.get_joy_name(device)).id
		return
	if device == pad and kind == Kind.GAMEPAD:
		pad = -1
		use(Kind.TOUCH if OS.has_feature("mobile") else Kind.KEYBOARD)
