class_name PcTests
extends TestSuite
## The game on a computer and with a gamepad (docs/design/interface.md, "Devices"). Unit part
## (run by the unit suite): the device in use (InputDevice) from keys, gamepad buttons and sticks
## (the dead zone), touches and the mouse; the prompts' words and glyphs per device and gamepad
## family; the input map; the settings; the canvas's scale (PixelGrid). Title part (title
## suite): the title's panels with keys only, and their layout at every screen size. Game part
## (game suite): the HUD per device, the mouse in a fight, pausing, every in-run panel with keys
## and a gamepad, and the HUD's layout at every screen size.

## Screens the layouts must hold at: computers (16:9, 16:10, 21:9, 4:3) and phones.
const SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(2560, 1440),
	Vector2i(1280, 800), Vector2i(3440, 1440), Vector2i(1024, 768), Vector2i(2340, 1080), Vector2i(1540, 720),
]


# --- Helpers ------------------------------------------------------------------------------

func _key(code: Key, pressed: bool = true, alt: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.alt_pressed = alt
	Input.parse_input_event(event)


## A key pressed and let go, a frame each.
func _tap_key(code: Key) -> void:
	_key(code, true)
	await _frames(1)
	_key(code, false)
	await _frames(1)


func _pad_button(button: JoyButton, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap_pad(button: JoyButton) -> void:
	_pad_button(button, true)
	await _frames(1)
	_pad_button(button, false)
	await _frames(1)


func _pad_axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _screen_touch(at: Vector2, pressed: bool, emulated: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = pressed
	if emulated:
		event.device = InputEvent.DEVICE_ID_EMULATION
	Input.parse_input_event(event)


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _keys_mode() -> void:
	InputDevice.use(InputDevice.Kind.KEYBOARD)
	InputDevice.navigating = true


## Sets the window to `size` and waits for the layouts to follow.
func _window(size: Vector2i) -> void:
	get_tree().root.size = size
	await _frames(3)


## Back to the test runner's window (headless: 64x64).
func _restore_window(size: Vector2i) -> void:
	get_tree().root.size = size
	await _frames(2)


func _rect_of(node: Node) -> Rect2:
	if node is Control:
		var control := node as Control
		return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)
	if node is ActionButton:
		var button := node as ActionButton
		var scale := button.get_global_transform_with_canvas().get_scale().x
		var radius := button.radius * scale
		var center := button.get_global_transform_with_canvas().origin
		return Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	return Rect2()


## Layout problems of `widgets` (name -> node) on the screen: one out of the viewport, two
## overlapping. Empty when the layout holds.
func _layout_problems(widgets: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(1.0)
	var rects := {}
	for widget_name: String in widgets:
		var node: Node = widgets[widget_name]
		if node == null or not is_instance_valid(node) or not (node as CanvasItem).is_visible_in_tree():
			continue
		var rect := _rect_of(node)
		if not rect.has_area():
			continue
		rects[widget_name] = rect
		if not screen.encloses(rect):
			problems.append("%s out of the screen (%s in %s)" % [widget_name, rect, screen.size])
	var names: Array = rects.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = rects[names[i]]
			var b: Rect2 = rects[names[j]]
			if a.intersects(b) and a.intersection(b).get_area() > 4.0:
				problems.append("%s overlaps %s" % [names[i], names[j]])
	return problems


## Every visible control of a panel inside the screen (a list's rows may scroll out of their
## box: only the box counts).
func _panel_outside(root: Control) -> Array[String]:
	var problems: Array[String] = []
	var screen := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(1.0)
	var nodes: Array[Node] = [root]
	while not nodes.is_empty():
		var node: Node = nodes.pop_back()
		if node is CanvasItem and not (node as CanvasItem).visible:
			continue
		if node is Control:
			var rect := _rect_of(node)
			if rect.has_area() and not screen.encloses(rect):
				problems.append("%s %s" % [root.get_path_to(node), rect])
		if node is ScrollContainer:
			continue
		nodes.append_array(node.get_children())
	return problems


## Keys only: the menu on top holds the focus, the arrows move it inside it (and keep it there,
## wrapping at its edges). `panel`: what was opened (the menu or what holds it).
func _check_keys_reach(panel: Control, what: String, move: bool = true) -> void:
	_keys_mode()
	await _frames(3)
	var top := MenuNav.top_menu()
	check(top != null and (top == panel or panel.is_ancestor_of(top) or top.is_ancestor_of(panel)), "%s: its menu is the one on top" % what)
	if top == null:
		return
	var focus := _focus()
	check(focus != null and top.is_ancestor_of(focus), "%s: the keys start on one of its buttons (%s)" % [what, focus.name if focus else "none"])
	if not move:
		return
	var count := MenuNav.focusables(top).size()
	var seen := {}
	for code: Key in [KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_DOWN, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_DOWN, KEY_DOWN, KEY_RIGHT, KEY_RIGHT, KEY_RIGHT]:
		await _tap_key(code)
		var now := _focus()
		if now == null or not top.is_ancestor_of(now):
			check(false, "%s: the arrows keep the focus inside (lost after %s)" % [what, OS.get_keycode_string(code)])
			return
		seen[now] = true
	check(count < 2 or seen.size() >= 2, "%s: the arrows move between its %d buttons" % [what, count])


# --- Unit ---------------------------------------------------------------------------------

func run_unit() -> void:
	var before := InputDevice.kind
	_test_input_map()
	await _test_device_switching()
	_test_prompts()
	_test_texts_per_device()
	_test_font_glyphs()
	await _test_settings()
	await _test_canvas_scale()
	await _test_menu_nav_unit()
	InputDevice.use(before)


## The input map has what the prompts name, and the pause never sits on a fight's button.
func _test_input_map() -> void:
	for entry in Prompts.DATA.actions:
		for action in entry.actions():
			check(InputMap.has_action(action), "the input map has %s (input_prompts.tres)" % action)
		check(not entry.display_name.is_empty(), "%s has a name for the Controls page" % entry.action)
	var events := InputMap.action_get_events(&"pause")
	var keys := events.filter(func(e: InputEvent) -> bool: return e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_ESCAPE)
	var start := events.filter(func(e: InputEvent) -> bool: return e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_START)
	check(not keys.is_empty() and not start.is_empty(), "Escape and Start pause")
	var b_pauses := events.any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == JOY_BUTTON_B)
	check(not b_pauses, "a gamepad's B (a skill) never pauses")
	check(InputMap.action_get_events(&"ui_focus_next").is_empty(), "Tab is the bag, not the GUI's next focus")
	for action: StringName in [&"move_up", &"attack", &"skill_1", &"skill_2", &"skill_3", &"skill_4", &"quick_item", &"belt_2", &"belt_3", &"interact", &"offers", &"inventory", &"map", &"pause"]:
		var on_pad := InputMap.action_get_events(action).any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton or e is InputEventJoypadMotion)
		var on_keys := InputMap.action_get_events(action).any(func(e: InputEvent) -> bool: return e is InputEventKey)
		check(on_pad and on_keys, "%s works on keys and on a gamepad" % action)


## The device in use follows the last real input (events reach the game on the next frame).
func _test_device_switching() -> void:
	var changes := [0]
	var count := func() -> void: changes[0] += 1
	InputDevice.changed.connect(count)
	InputDevice.use(InputDevice.Kind.TOUCH)
	_key(KEY_W)
	await _frames(1)
	_key(KEY_W, false)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.KEYBOARD and InputDevice.uses_buttons(), "a key: the keyboard is in use")
	check(changes[0] >= 1, "...and the change is signalled")
	var rest := InputEventMouseMotion.new()
	rest.position = Vector2(10, 10)
	Input.parse_input_event(rest)
	await _frames(1)
	_pad_axis(JOY_AXIS_LEFT_X, 0.3)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.KEYBOARD, "a stick leaning less than its dead zone (drift) changes nothing")
	_pad_axis(JOY_AXIS_LEFT_X, 0.9)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.GAMEPAD, "a stick pushed past its dead zone: the gamepad")
	_pad_axis(JOY_AXIS_LEFT_X, 0.0)
	await _frames(1)
	_key(KEY_SPACE)
	await _frames(1)
	_key(KEY_SPACE, false)
	await _frames(1)
	await _tap_pad(JOY_BUTTON_A)
	check(InputDevice.kind == InputDevice.Kind.GAMEPAD and InputDevice.navigating, "a gamepad button: the gamepad, steering menus")
	var nudge := InputEventMouseMotion.new()
	nudge.relative = Vector2(1, 1)
	nudge.screen_relative = Vector2(1, 1)
	nudge.position = Vector2(11, 11)
	Input.parse_input_event(nudge)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.GAMEPAD, "a nudged mouse (a pixel) doesn't take over from the gamepad")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(30, 0)
	motion.screen_relative = Vector2(30, 0)
	motion.position = Vector2(40, 10)
	Input.parse_input_event(motion)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.KEYBOARD and not InputDevice.navigating, "a mouse moved for real: keyboard and mouse, the focus frame put away")
	_screen_touch(Vector2(100, 100), true, true)
	await _frames(1)
	_screen_touch(Vector2(100, 100), false, true)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.KEYBOARD, "the mouse's emulated touches are not a touch screen")
	_screen_touch(Vector2(100, 100), true)
	await _frames(1)
	_screen_touch(Vector2(100, 100), false)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.TOUCH and InputDevice.uses_touch(), "a real touch: touch")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(1)
	check(InputDevice.kind == InputDevice.Kind.TOUCH, "a mouse click after a touch keeps the touch buttons (the mouse presses them too)")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	Input.parse_input_event(release)
	await _frames(1)
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"playstation")
	InputDevice.pad = 3
	InputDevice._on_joy_connection_changed(3, false)
	check(InputDevice.kind == InputDevice.Kind.KEYBOARD, "the gamepad in use unplugged: back to the keyboard")
	check(InputDevice.family == &"playstation", "...the family kept for its names")
	InputDevice.changed.disconnect(count)
	# The families, from the pads' names.
	var data := Prompts.DATA
	check(data.family_for("Xbox Series X Controller").id == &"xbox" and data.family_for("XInput Gamepad (GLFW)").id == &"xbox", "Xbox pads are Xbox")
	check(data.family_for("PS5 Controller").id == &"playstation" and data.family_for("Sony DualSense Wireless Controller").id == &"playstation" and data.family_for("PS4 Controller").id == &"playstation", "PlayStation pads are PlayStation")
	check(data.family_for("Nintendo Switch Pro Controller").id == &"nintendo", "a Switch pad is Nintendo")
	check(data.family_for("8BitDo Generic USB Gamepad").id == &"generic", "an unknown pad is generic")


## Prompts name the right key or button on each device and family.
func _test_prompts() -> void:
	var keyboard := InputDevice.Kind.KEYBOARD
	check(Prompts.glyph(&"interact", keyboard).text == "E" and Prompts.glyph(&"attack", keyboard).text == "Space", "keyboard prompts: E to use, Space to attack")
	check(Prompts.glyph(&"move", keyboard).text == "WASD", "moving reads WASD (the keyboard's own letters)")
	check(Prompts.glyph(&"pause", keyboard).text == "Esc" and Prompts.glyph(&"skill_1", keyboard).text == "1", "Esc pauses, 1 rolls")
	var attack_all := Prompts.glyphs(&"attack", keyboard)
	check(attack_all.size() == 3 and attack_all[2].shape == Prompts.Shape.MOUSE and attack_all[2].button == MOUSE_BUTTON_LEFT, "the Controls page lists Space, J and the left mouse button for the attack")
	check(not Prompts.glyphs(&"ui_accept", keyboard).any(func(cap: Dictionary) -> bool: return str(cap.text).begins_with("Kp")), "no keypad twins on the Controls page")
	var pad := InputDevice.Kind.GAMEPAD
	InputDevice.use(pad, &"xbox")
	check(Prompts.glyph(&"interact").text == "RT" and Prompts.glyph(&"attack").text == "X" and Prompts.glyph(&"skill_1").text == "A", "Xbox: RT uses, X attacks, A rolls")
	check(Prompts.glyph(&"attack").shape == Prompts.Shape.ROUND and Prompts.glyph(&"interact").shape == Prompts.Shape.SHOULDER and Prompts.glyph(&"move").shape == Prompts.Shape.STICK, "round face buttons, a trigger's shape, a stick")
	check(Prompts.glyph(&"pause").text == "Menu" and Prompts.glyph(&"inventory").text == "View", "Xbox: Menu pauses, View opens the bag")
	InputDevice.use(pad, &"playstation")
	check(Prompts.glyph(&"attack").text == "□" and Prompts.glyph(&"skill_1").text == "✕" and Prompts.glyph(&"interact").text == "R2", "PlayStation: □ attacks, ✕ rolls, R2 uses")
	check(Prompts.glyph(&"ui_cancel").text == "○" and Prompts.glyph(&"menu_tabs").text == "L1 / R1", "PlayStation: ○ goes back, L1 / R1 switch tabs")
	InputDevice.use(pad, &"nintendo")
	check(Prompts.glyph(&"skill_1").text == "B" and Prompts.glyph(&"skill_2").text == "A" and Prompts.glyph(&"interact").text == "ZR", "Nintendo: its letters where its buttons are (B at the bottom), ZR uses")
	InputDevice.use(InputDevice.Kind.TOUCH)
	check(Prompts.glyph(&"interact").is_empty() and Prompts.inline(&"interact").is_empty(), "touch: no key to show")
	check(Prompts.glyph(&"toggle_fullscreen", InputDevice.Kind.GAMEPAD).is_empty(), "nothing bound on a gamepad: no glyph")
	var glyph := PromptGlyph.make(&"interact")
	add_child(glyph)
	check(not glyph.visible, "a prompt's cap hides on touch")
	InputDevice.use(InputDevice.Kind.KEYBOARD)
	check(glyph.visible and glyph.cap().text == "E" and glyph.size.x >= PromptGlyph.HEIGHT, "...and shows the key with the keyboard")
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"xbox")
	check(glyph.visible and glyph.cap().text == "RT", "...the trigger with an Xbox pad")
	glyph.free()


## Sentences in the device's words, codes filled with its keys.
func _test_texts_per_device() -> void:
	InputDevice.use(InputDevice.Kind.TOUCH)
	check(Prompts.pick("Tap to skip", "Press {ui_accept} to skip") == "Tap to skip", "touch: the touch sentence")
	InputDevice.use(InputDevice.Kind.KEYBOARD)
	check(Prompts.pick("Tap to skip", "Press {ui_accept} to skip") == "Press [Enter] to skip", "keyboard: the key in the sentence")
	check(Prompts.pick("Tap to skip", "") == "Tap to skip", "no keys sentence: the touch one serves")
	check(Prompts.fill("{interact} to use {name}") == "[E] to use {name}", "codes that aren't controls stay for format()")
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"playstation")
	check(Prompts.pick("Tap to skip", "Press {ui_accept} to skip") == "Press [✕] to skip", "a PlayStation pad: its cross")
	# The tutorial's hints that name a control say it for keys and gamepads too.
	var tutorial: TutorialDef = CONTENT.tutorial
	for hint in tutorial.hints:
		var touch_words := hint.text.to_lower()
		if touch_words.contains("tap") or touch_words.contains("thumb"):
			check(not hint.button_text.is_empty(), "the %s hint has words for keys and gamepads" % hint.id)
		if not hint.button_text.is_empty():
			check(hint.button_text.length() <= 120, "%s's keys text is short enough for two lines (%d)" % [hint.id, hint.button_text.length()])
			check(not hint.button_text.to_lower().contains("tap"), "%s's keys text never says tap" % hint.id)
	InputDevice.use(InputDevice.Kind.KEYBOARD)
	var move: HintDef = tutorial.hint(&"move")
	check(move.shown_text() == "Walk with [WASD].", "the move hint on a keyboard: %s" % move.shown_text())
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"xbox")
	check(tutorial.hint(&"merchant").shown_text().contains("[RT]"), "the merchant's hint on a gamepad names its trigger")
	InputDevice.use(InputDevice.Kind.TOUCH)
	check(move.shown_text() == tr(move.text), "and on touch, the thumb")
	# Loading tips about a control follow the device too.
	var tips: LoadingTipsDef = load("res://data/ui/loading_tips.tres")
	check(not tips.control_tips.is_empty(), "loading tips about the controls")
	InputDevice.use(InputDevice.Kind.KEYBOARD)
	check(tips.control_tips.all(func(tip: DeviceText) -> bool: return tip.text().contains("[") and not tip.text().to_lower().contains("tap")), "...on a keyboard with its keys")
	InputDevice.use(InputDevice.Kind.TOUCH)
	check(tips.control_tips.all(func(tip: DeviceText) -> bool: return not tip.text().contains("[")), "...on touch with taps")


## The font draws the prompts' glyphs (never a fallback font's).
func _test_font_glyphs() -> void:
	for glyph in ["✕", "○", "□", "△", "←", "↑", "→", "↓"]:
		check(Fonts.MAIN.has_char(glyph.unicode_at(0)), "the pixel font has %s" % glyph)
	for pad in Prompts.DATA.pads:
		for word in pad.button_glyphs + pad.axis_glyphs:
			for i in word.length():
				check(Fonts.MAIN.has_char(word.unicode_at(i)), "the font draws %s's %s" % [pad.id, word])


## Fullscreen and the interface's size are saved, and older settings files get the defaults.
func _test_settings() -> void:
	var path := "user://test_settings_%d.cfg" % OS.get_process_id()
	var saved_path := Settings.path
	var old := ConfigFile.new()
	old.set_value("options", "master_volume", 0.5)
	old.save(path)
	Settings.path = path
	var full := Settings.fullscreen
	var size := Settings.ui_size
	Settings.fullscreen = true
	Settings.ui_size = Settings.UI_SMALL
	Settings.load_settings()
	check(Settings.fullscreen == true and Settings.ui_size == Settings.UI_SMALL, "a settings file from before keeps what it doesn't know")
	Settings.fullscreen = false
	Settings.ui_size = Settings.UI_BIG
	Settings.set_option(&"fullscreen", true)
	Settings.set_option(&"ui_size", Settings.UI_MEDIUM)
	Settings.fullscreen = false
	Settings.ui_size = Settings.UI_BIG
	Settings.load_settings()
	check(Settings.fullscreen and Settings.ui_size == Settings.UI_MEDIUM, "fullscreen and the interface size are saved")
	var bad := ConfigFile.new()
	bad.set_value("options", "ui_size", 9)
	bad.save(path)
	Settings.load_settings()
	check(Settings.ui_size == Settings.UI_SMALL, "an interface size out of range is held to the smallest")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	Settings.path = saved_path
	# F11 and Alt+Enter, anywhere.
	Settings.fullscreen = false
	await _tap_key(KEY_F11)
	check(Settings.fullscreen, "F11: fullscreen")
	_key(KEY_ENTER, true, true)
	await _frames(1)
	_key(KEY_ENTER, false, true)
	await _frames(1)
	check(not Settings.fullscreen, "Alt+Enter: back to a window")
	Settings.fullscreen = full
	Settings.ui_size = size
	Settings.apply()


## The canvas's scale goes by whole steps of 0.5 (whole font pixels), the canvas fills the rest of
## the screen at least as big as the layouts' 1280x720, and the camera keeps the floor's framing.
func _test_canvas_scale() -> void:
	check(PixelGrid.canvas_scale(1.0667, Settings.UI_BIG) == 1.0 and PixelGrid.canvas_scale(1.5, Settings.UI_BIG) == 1.5, "1366x768 at x1, 1080 lines at x1.5")
	check(PixelGrid.canvas_scale(2.6875, Settings.UI_BIG) == 2.5 and PixelGrid.canvas_scale(2.0, Settings.UI_MEDIUM) == 1.5, "x2.5 for a big screen; Medium a step smaller")
	check(PixelGrid.canvas_scale(1.5, Settings.UI_SMALL) == 1.0 and PixelGrid.canvas_scale(0.8, Settings.UI_SMALL) == 0.8, "never under x1; a small screen keeps its own scale")
	var before := get_tree().root.size
	for size in SIZES:
		await _window(size)
		var visible := get_viewport().get_visible_rect().size
		var scale := PixelGrid.ui_scale()
		var fit := minf(size.x / 1280.0, size.y / 720.0)
		check(visible.x >= 1279.0 and visible.y >= 719.0, "%s: the canvas is at least 1280x720 (%s)" % [size, visible])
		check(fit < 1.0 or is_equal_approx(fposmod(scale, 0.5), 0.0), "%s: a whole step of scale (x%s)" % [size, scale])
		check(is_equal_approx(visible.x * scale, size.x) or is_equal_approx(visible.y * scale, size.y), "%s: the canvas fills the screen, never stretched" % size)
		check(is_equal_approx(PixelGrid.world_zoom(), maxf(1.0, fit / scale)), "%s: the camera zooms by what the rounding took off" % size)
	Settings.ui_size = Settings.UI_MEDIUM
	await _window(Vector2i(2560, 1440))
	check(is_equal_approx(PixelGrid.ui_scale(), 1.5) and is_equal_approx(PixelGrid.world_zoom(), 2.0 / 1.5), "Medium on 1440 lines: x1.5, the floor framed as at x2")
	Settings.ui_size = Settings.UI_BIG
	await _restore_window(before)


## MenuNav on a little menu: first focus, moving, wrapping, tabs, a slider.
func _test_menu_nav_unit() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var menu := VBoxContainer.new()
	menu.add_to_group(MenuNav.GROUP)
	menu.position = Vector2(100, 100)
	layer.add_child(menu)
	var tabs := HBoxContainer.new()
	tabs.set_meta(MenuNav.NOT_FIRST, true)
	menu.add_child(tabs)
	var pressed := [-1]
	var tab_buttons: Array[Button] = []
	for i in 3:
		var tab := Button.new()
		tab.text = "Tab %d" % i
		tab.toggle_mode = true
		tab.add_to_group(MenuNav.TABS)
		tab.pressed.connect(func() -> void:
			pressed[0] = i
			for other in tab_buttons:
				other.set_pressed_no_signal(other == tab))
		tabs.add_child(tab)
		tab_buttons.append(tab)
	tab_buttons[0].set_pressed_no_signal(true)
	var buttons: Array[Button] = []
	for i in 3:
		var button := Button.new()
		button.text = "Row %d" % i
		button.custom_minimum_size = Vector2(200, 40)
		menu.add_child(button)
		buttons.append(button)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(200, 30)
	slider.max_value = 1.0
	slider.step = 0.1
	menu.add_child(slider)
	_keys_mode()
	await _frames(3)
	check(_focus() == buttons[0], "a menu opening with the keys in use: its first button outside the tabs has the focus")
	await _tap_key(KEY_DOWN)
	check(_focus() == buttons[1], "down: the next row")
	await _tap_key(KEY_S)
	check(_focus() == buttons[2], "S (the move keys) too")
	await _tap_key(KEY_DOWN)
	check(_focus() == slider, "down to the slider")
	var value := slider.value
	await _tap_key(KEY_D)
	check(slider.value > value and _focus() == slider, "right on a slider moves its value")
	await _tap_key(KEY_DOWN)
	check(tabs.is_ancestor_of(_focus()), "down past the last row wraps to the top")
	await _tap_key(KEY_E)
	check(pressed[0] == 1 and tab_buttons[1].button_pressed, "E: the next tab")
	await _tap_key(KEY_Q)
	await _tap_key(KEY_Q)
	check(pressed[0] == 2, "Q twice: the previous tab, wrapping")
	_pad_button(JOY_BUTTON_RIGHT_SHOULDER)
	_pad_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	await _frames(1)
	check(pressed[0] == 0, "RB: the next tab")
	buttons[1].grab_focus()
	_pad_axis(JOY_AXIS_LEFT_Y, 0.9)
	await _frames(1)
	_pad_axis(JOY_AXIS_LEFT_Y, 0.95)
	await _frames(1)
	check(_focus() == buttons[2], "a stick held down moves once, not every frame")
	_pad_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _frames(1)
	_pad_button(JOY_BUTTON_DPAD_UP)
	_pad_button(JOY_BUTTON_DPAD_UP, false)
	await _frames(1)
	check(_focus() == buttons[1], "the D-pad moves")
	var hit := [false]
	buttons[1].pressed.connect(func() -> void: hit[0] = true)
	_pad_button(JOY_BUTTON_A)
	await _frames(1)
	_pad_button(JOY_BUTTON_A, false)
	await _frames(1)
	check(hit[0], "A presses the focused button")
	await _frames(1)
	check(MenuNav.get_child(0).get("target") == buttons[1], "the focus frame is on it")
	InputDevice.use(InputDevice.Kind.TOUCH)
	await _frames(1)
	check(MenuNav.get_child(0).get("target") == null, "never on touch")
	# A second menu over it takes the keys; closed, the focus comes back where it was.
	_keys_mode()
	var over := VBoxContainer.new()
	over.add_to_group(MenuNav.GROUP)
	layer.add_child(over)
	var ok := Button.new()
	ok.text = "OK"
	over.add_child(ok)
	await _frames(2)
	check(_focus() == ok, "a menu over another takes the focus")
	await _tap_key(KEY_UP)
	check(_focus() == ok, "...and keeps it (never to the menu underneath)")
	over.hide()
	await _frames(2)
	check(_focus() == buttons[1], "closed: the focus comes back to the button it was on")
	layer.queue_free()
	await _frames(1)


# --- Title --------------------------------------------------------------------------------

func run_title() -> void:
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(3)
	_keys_mode()
	await _frames(2)
	check(_focus() != null and title.is_ancestor_of(_focus()), "the title with the keys: a button has the focus")
	await _test_title_keys(title)
	await _test_options_keys(title)
	await _test_codex_keys(title)
	await _test_title_layouts(title)
	InputDevice.use(InputDevice.Kind.TOUCH)
	title.queue_free()
	await _frames(2)


func _test_title_keys(title: TitleScreen) -> void:
	# Escape on the title itself does nothing (a computer's player never quits by accident).
	await _tap_key(KEY_ESCAPE)
	check(is_instance_valid(title) and title.is_inside_tree(), "Escape on the bare title quits nothing")
	(title.get_node("%PlayButton") as Button).grab_focus()
	await _tap_key(KEY_ENTER)
	await _frames(2)
	var difficulty := title.get_node("%DifficultyPanel") as Control
	check(difficulty.visible, "Enter on Descend opens the difficulties")
	await _check_keys_reach(difficulty, "the difficulties")
	await _tap_key(KEY_ESCAPE)
	check(not difficulty.visible, "Escape closes them")
	var shrine := title.get_node("%ShrinePanel") as Control
	(title.get_node("%ShrineButton") as Button).pressed.emit()
	await _frames(2)
	await _check_keys_reach(shrine, "the shrine")
	var node_button := _focus()
	check(node_button is SoulNodeButton or (node_button != null and shrine.is_ancestor_of(node_button)), "the shrine starts on its tree")
	await _tap_key(KEY_ESCAPE)
	check(not shrine.visible, "Escape closes the shrine")
	title.daily_dialog.open(CONTENT, DailyRun.today())
	await _frames(2)
	await _check_keys_reach(title.daily_dialog, "the Dawn Knell's dialog")
	await _tap_key(KEY_ESCAPE)
	check(not title.daily_dialog.visible, "Escape closes it")


func _test_options_keys(title: TitleScreen) -> void:
	var options := title.get_node("%OptionsPanel") as OptionsPanel
	(title.get_node("%OptionsButton") as Button).pressed.emit()
	await _frames(2)
	await _check_keys_reach(options, "the options")
	var page := options.get_node("%ControlsPage") as ControlsPage
	check(not page.visible, "the options open on the settings")
	await _tap_key(KEY_E)
	check(page.visible and (options.get_node("%ControlsTab") as Button).button_pressed, "E: the Controls tab")
	var rows := page.rows_text()
	check(rows.any(func(row: PackedStringArray) -> bool: return row[0] == "Attack (hold to charge)" and row[1].contains("Space")), "the Controls page lists the keys: %s" % [rows.slice(0, 3)])
	InputDevice.use(InputDevice.Kind.GAMEPAD, &"playstation")
	await _frames(1)
	rows = page.rows_text()
	check(rows.any(func(row: PackedStringArray) -> bool: return row[0] == "Roll" and row[1] == "✕"), "a gamepad picked up: the page names its buttons (✕ rolls)")
	InputDevice.use(InputDevice.Kind.TOUCH)
	await _frames(1)
	rows = page.rows_text()
	check(rows.any(func(row: PackedStringArray) -> bool: return row[0] == "Bag" and row[1] == "The Bag button"), "touch: how it is done by touch")
	_keys_mode()
	await _tap_key(KEY_Q)
	check(not page.visible, "Q: back to the settings")
	# Down to a slider, and change it with the arrows.
	var master := options.get_node("%MasterSlider") as HSlider
	master.grab_focus()
	var volume := Settings.master_volume
	await _tap_key(KEY_LEFT)
	check(Settings.master_volume < volume, "left on a volume turns it down (%s)" % Settings.master_volume)
	await _tap_key(KEY_RIGHT)
	check(is_equal_approx(Settings.master_volume, volume), "right turns it back up")
	var check_button := options.get_node("%RunTimerCheck") as CheckButton
	check_button.grab_focus()
	var timer := Settings.run_timer
	await _tap_key(KEY_ENTER)
	check(Settings.run_timer != timer, "Enter flips a switch")
	await _tap_key(KEY_ENTER)
	check(Settings.run_timer == timer, "...and back")
	var medium := options.get_node("%UiSizeMedium") as Button
	medium.pressed.emit()
	check(Settings.ui_size == Settings.UI_MEDIUM and medium.button_pressed, "the interface size option")
	(options.get_node("%UiSizeBig") as Button).pressed.emit()
	check(Settings.ui_size == Settings.UI_BIG, "...back to big")
	await _tap_key(KEY_ESCAPE)
	check(not options.visible, "Escape closes the options")
	# A gamepad's B too.
	options.open()
	await _frames(1)
	await _tap_pad(JOY_BUTTON_B)
	check(not options.visible, "B closes the options")


func _test_codex_keys(title: TitleScreen) -> void:
	var codex := title.get_node("%CodexPanel") as CodexPanel
	# Two monsters met (unknown ones can't be opened, nor focused).
	var seen_before := Profile.seen_monsters.duplicate()
	for monster in CONTENT.dungeon.acts[0].monsters.slice(0, 2):
		Profile.mark_seen(monster.id)
	await _test_codex_cards(codex)
	Profile.seen_monsters = seen_before


func _test_codex_cards(codex: CodexPanel) -> void:
	codex.open(CONTENT, CodexPanel.Tab.QUESTS)
	await _frames(2)
	await _check_keys_reach(codex, "the codex")
	await _tap_key(KEY_E)
	check((codex.get_node("%BestiaryTab") as Button).button_pressed, "E: the codex's next tab (Bestiary)")
	var cards := codex.bestiary_cards().filter(func(card: CodexCard) -> bool: return not card.disabled)
	check(not cards.is_empty(), "the bestiary's cards")
	if cards.is_empty():
		return
	check(cards.size() >= 2, "several monsters in the bestiary (%d)" % cards.size())
	if cards.size() < 2:
		return
	cards[0].grab_focus()
	await _tap_key(KEY_RIGHT)
	check(_focus() == cards[1], "right: the next monster")
	await _tap_key(KEY_ENTER)
	check(codex.is_page_open(), "Enter: its page")
	check(_focus() != null and (codex.get_node("%MonsterPage") as Control).is_ancestor_of(_focus()), "the keys go to its page")
	await _tap_key(KEY_ESCAPE)
	check(codex.visible and not codex.is_page_open(), "Escape: back to the list")
	await _frames(2)
	check(_focus() == cards[1], "the focus back on the monster it was on")
	await _tap_key(KEY_ESCAPE)
	check(not codex.visible, "Escape again closes the codex")


## The title and its windows fit every screen: nothing out of it.
func _test_title_layouts(title: TitleScreen) -> void:
	var before := get_tree().root.size
	var options := title.get_node("%OptionsPanel") as OptionsPanel
	var codex := title.get_node("%CodexPanel") as CodexPanel
	var shrine := title.get_node("%ShrinePanel") as ShrinePanel
	for size in SIZES:
		await _window(size)
		var outside := _panel_outside(title.get_node("Margin") as Control)
		check(outside.is_empty(), "%s: the title's buttons and records fit (%s)" % [size, ", ".join(outside.slice(0, 3))])
		options.open()
		options.show_page(true)
		await _frames(2)
		outside = _panel_outside(options)
		check(outside.is_empty(), "%s: the options' Controls page fits (%s)" % [size, ", ".join(outside.slice(0, 3))])
		options.show_page(false)
		await _frames(1)
		outside = _panel_outside(options)
		check(outside.is_empty(), "%s: the options fit (%s)" % [size, ", ".join(outside.slice(0, 3))])
		options.hide()
		codex.open(CONTENT, CodexPanel.Tab.BESTIARY)
		await _frames(2)
		outside = _panel_outside(codex)
		check(outside.is_empty(), "%s: the codex fits (%s)" % [size, ", ".join(outside.slice(0, 3))])
		codex.hide()
		shrine.open(CONTENT.soul_tree, CONTENT)
		await _frames(2)
		outside = _panel_outside(shrine)
		check(outside.is_empty(), "%s: the shrine fits (%s)" % [size, ", ".join(outside.slice(0, 3))])
		shrine.hide()
	# French runs longer: the options and their Controls page still fit the narrowest canvas.
	Settings.language = "fr"
	Settings.apply()
	var french := (load("res://src/ui/options/options_panel.tscn") as PackedScene).instantiate() as OptionsPanel
	add_child(french)
	for size in [Vector2i(1280, 720), Vector2i(1024, 768), Vector2i(1366, 768)]:
		await _window(size)
		french.open()
		await _frames(2)
		var outside := _panel_outside(french)
		check(outside.is_empty(), "%s in French: the options fit (%s)" % [size, ", ".join(outside.slice(0, 3))])
		french.show_page(true)
		await _frames(2)
		outside = _panel_outside(french)
		check(outside.is_empty(), "%s in French: the Controls page fits (%s)" % [size, ", ".join(outside.slice(0, 3))])
		french.hide()
	french.queue_free()
	Settings.language = "en"
	Settings.apply()
	await _restore_window(before)


# --- Game ---------------------------------------------------------------------------------

func run_game(game: Game) -> void:
	await _clear_monsters(game.world)
	await _test_hud_devices(game)
	await _test_mouse_fight(game)
	await _test_pause_keys(game)
	await _test_panels_keys(game)
	await _test_hud_layouts(game)
	InputDevice.use(InputDevice.Kind.TOUCH)
	await _frames(2)


## The touch controls go away on keys and a gamepad (an action bar with their keys instead) and
## come back on the first touch.
func _test_hud_devices(game: Game) -> void:
	var hud := game.hud
	InputDevice.use(InputDevice.Kind.TOUCH)
	await _frames(2)
	check(hud.touch_controls_shown() and not hud.action_bar.visible and (hud.get_node("%Joystick") as Control).visible, "touch: the joystick and the round buttons")
	var bag_key := hud.get_node("%BagButton").find_children("*", "PromptGlyph", true, false)
	check(bag_key.size() == 1 and not (bag_key[0] as Control).visible, "touch: no key on the bag button")
	_key(KEY_D)
	await _frames(2)
	_key(KEY_D, false)
	check(not hud.touch_controls_shown() and not (hud.get_node("%Joystick") as Control).visible and hud.action_bar.visible, "a key: the touch controls are put away for the action bar")
	check((bag_key[0] as Control).visible and (bag_key[0] as PromptGlyph).cap().text == "I", "the bag button shows its key")
	var attack := hud.action_bar.slot_for(&"AttackButton") as ActionBar.Slot
	check(attack != null and attack.glyph().cap().text == "Space", "the attack's slot shows Space")
	var rect := hud.hint_target(&"AttackButton")
	check(rect.has_area() and rect.is_equal_approx(attack.get_global_rect()), "the tutorial points at the attack's slot")
	check(not hud.hint_target(&"Joystick").has_area(), "...and at no joystick")
	# The skills' cooldowns show on the bar too.
	var roll := hud.action_bar.slot_for(&"Skill1Button")
	check(roll != null and roll.visible, "the roll's slot")
	_pad_button(JOY_BUTTON_X)
	await _frames(2)
	_pad_button(JOY_BUTTON_X, false)
	check(InputDevice.uses_gamepad() and hud.action_bar.visible and attack.glyph().cap().text == "X", "a gamepad: the same bar with its buttons (X attacks)")
	# Interact: a thing in reach shows its prompt beside the bar.
	var merchant := game.world.spawn_merchant(CONTENT.dungeon.merchant, game.world.map.world_to_cell(game.world.find_open_point_near(game.player.global_position + Vector2(60, 0), 40.0)))
	game.player.global_position = merchant.global_position + Vector2(0, 26)
	await _frames(4)
	check(hud.action_bar.interact.visible and hud.action_bar.interact.caption() == "Trade", "by the merchant: [RT] Trade beside the bar")
	check(hud.hint_target(&"InteractButton").has_area(), "the tutorial points at it")
	game.player.global_position += Vector2(0, 600)
	await _frames(4)
	merchant.queue_free()
	await _frames(2)
	check(not hud.action_bar.interact.visible, "out of reach: gone")
	var screen := get_viewport().get_visible_rect().size
	_screen_touch(screen * 0.5, true)
	await _frames(1)
	_screen_touch(screen * 0.5, false)
	await _frames(1)
	check(hud.touch_controls_shown() and not hud.action_bar.visible, "the first touch brings the touch controls back")
	# The hint's words follow the device.
	var hint: HintDef = CONTENT.tutorial.hint(&"attack")
	game.hint_box.show_hint(hint, Rect2())
	check(game.hint_box.shown_text() == tr(hint.text), "a hint on touch: its tap words")
	_keys_mode()
	await _frames(1)
	check(game.hint_box.shown_text() == "Press [Space] to strike. It aims at the closest enemy by itself.", "the keyboard taken up mid-hint: its key (%s)" % game.hint_box.shown_text())
	game.hint_box.hide_hint()


## In a fight the left mouse button attacks and the right one rolls; never over the HUD's buttons,
## never from a touch's mouse.
func _test_mouse_fight(game: Game) -> void:
	_keys_mode()
	await _frames(2)
	var screen := get_viewport().get_visible_rect().size
	var to_window := get_tree().root.get_final_transform()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = to_window * (screen * 0.5 + Vector2(60, 40))
	click.global_position = click.position
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(1)
	check(Input.is_action_pressed(&"attack"), "a left click in the fight attacks")
	click.pressed = false
	Input.parse_input_event(click)
	await _frames(1)
	check(not Input.is_action_pressed(&"attack"), "...let go")
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(1)
	check(Input.is_action_pressed(&"skill_1"), "a right click rolls")
	click.pressed = false
	Input.parse_input_event(click)
	await _frames(1)
	var touch := click.duplicate() as InputEventMouseButton
	touch.button_index = MOUSE_BUTTON_LEFT
	touch.device = InputEvent.DEVICE_ID_EMULATION
	touch.pressed = true
	Input.parse_input_event(touch)
	await _frames(1)
	check(not Input.is_action_pressed(&"attack"), "a touch's mouse never attacks")
	touch.pressed = false
	Input.parse_input_event(touch)
	var bag := game.hud.get_node("%BagButton") as Button
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = to_window * bag.get_global_rect().get_center()
	click.global_position = click.position
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(1)
	check(not Input.is_action_pressed(&"attack"), "a click on the bag button doesn't attack")
	click.pressed = false
	Input.parse_input_event(click)
	await _frames(2)
	if game.inventory_panel.visible:
		game.inventory_panel.close()
		await _frames(2)


## Escape and Start pause and resume; a gamepad's B in a fight never pauses (it is a skill).
func _test_pause_keys(game: Game) -> void:
	_keys_mode()
	await _tap_key(KEY_ESCAPE)
	check(game.pause_menu.visible and get_tree().paused, "Escape pauses")
	await _frames(2)
	var resume := game.pause_menu.get_node("%ResumeButton") as Button
	check(_focus() == resume, "the pause menu starts on Resume")
	await _check_keys_reach(game.pause_menu, "the pause menu")
	resume.grab_focus()
	await _tap_key(KEY_ENTER)
	await _frames(2)
	check(not game.pause_menu.visible and not get_tree().paused, "Enter on Resume: back to the fight")
	await _tap_pad(JOY_BUTTON_B)
	await _frames(2)
	check(not game.pause_menu.visible and not get_tree().paused, "B in a fight doesn't pause")
	await _tap_pad(JOY_BUTTON_START)
	check(game.pause_menu.visible, "Start pauses")
	await _tap_pad(JOY_BUTTON_B)
	await _frames(2)
	check(not game.pause_menu.visible and not get_tree().paused, "B closes the pause menu")
	# The map key.
	await _tap_key(KEY_M)
	check((game.hud.get_node("%FullMap") as Control).visible, "M: the whole floor's map")
	await _tap_key(KEY_M)
	check(not (game.hud.get_node("%FullMap") as Control).visible, "M again: back")


## Every in-run panel with the keys: it takes the focus, the arrows move in it, Escape closes it
## (the end screens stay: they never close by Back).
func _test_panels_keys(game: Game) -> void:
	var player := game.player
	var world := game.world
	_keys_mode()
	# The bag: Enter on the weapon's slot shows it.
	game.open_inventory()
	await _frames(2)
	await _check_keys_reach(game.inventory_panel, "the bag")
	var focused := _focus()
	if focused is ItemSlot:
		await _tap_key(KEY_ENTER)
		check((focused as ItemSlot).selected or (focused as ItemSlot).item == null, "Enter picks the slot")
	await _tap_key(KEY_ESCAPE)
	check(not game.inventory_panel.visible, "Escape closes the bag")
	# The shop.
	var merchant := world.spawn_merchant(CONTENT.dungeon.merchant, world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(60, 0), 40.0)))
	await _frames(2)
	game.open_shop(merchant)
	await _frames(2)
	await _check_keys_reach(game.shop_panel, "the merchant")
	await _tap_key(KEY_ESCAPE)
	check(not game.shop_panel.visible, "Escape closes the merchant")
	merchant.queue_free()
	# The forge.
	var forge := world.spawn_forge(CONTENT.dungeon.forge, world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(-60, 0), 40.0)))
	await _frames(2)
	game.open_forge(forge)
	await _frames(2)
	await _check_keys_reach(game.menus.forge, "the forge")
	await _tap_pad(JOY_BUTTON_B)
	check(not game.menus.forge.visible, "B closes the forge")
	forge.queue_free()
	# An encounter.
	var spring := world.spawn_encounter(load("res://data/encounters/spirit_spring.tres"), world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(0, 60), 40.0)))
	await _frames(2)
	game.open_encounter(spring)
	await _frames(2)
	await _check_keys_reach(game.encounter_panel, "an encounter")
	await _tap_key(KEY_ESCAPE)
	check(not game.encounter_panel.visible, "Escape leaves the encounter")
	spring.queue_free()
	# A pact door.
	if world.pact == null and world.arena == null:
		var here: Array[int] = []
		for i in world.map.rooms.size():
			if world.map.rooms[i].grow(1).has_point(world.map.world_to_cell(player.global_position)):
				here.append(i)
		var index := PactRoom.find_room(world.map, world.rng, here, world.config().corridor_width + 3)
		if index >= 0:
			world.spawn_pact(CONTENT.dungeon.pacts[0], world.map.rooms[index], {})
	if world.pact:
		game.open_pact(world.pact)
		await _frames(2)
		await _check_keys_reach(game.menus.pact, "a pact's offer")
		await _tap_key(KEY_ESCAPE)
		check(not game.menus.pact.visible, "Escape closes the pact's offer")
	# A fragment: any key closes it.
	var fragment_def: FragmentDef = null
	for chronicle_boss in CONTENT.dungeon.acts[0].all_bosses():
		if chronicle_boss.chronicle and not chronicle_boss.chronicle.fragments.is_empty():
			fragment_def = chronicle_boss.chronicle.fragments[0]
			break
	if fragment_def:
		game.menus.fragment.open(fragment_def, null)
		get_tree().paused = true
		await _frames(int(FragmentPanel.OPEN_GRACE_FRAMES) + 2)
		await _check_keys_reach(game.menus.fragment, "a fragment", false)
		await _tap_key(KEY_ENTER)
		check(not game.menus.fragment.visible, "a key closes the fragment")
		get_tree().paused = false
	# The perk choice: the first card, Enter takes it.
	var perks_before := player.perks.entries.size()
	game.offers.add(PerkDef.Rarity.COMMON, 3, "Level 2!", "Choose an upgrade", true)
	game.open_offers()
	await _frames(2)
	var first_card := game.perk_panel.get_node("%Cards").get_child(0) as Control
	_keys_mode()
	await _frames(2)
	check(_focus() == first_card, "the perk choice starts on its first card, while the cards still wait")
	await get_tree().create_timer(0.6, true).timeout
	await _check_keys_reach(game.perk_panel, "the perk choice")
	first_card.grab_focus()
	var offered := game.perk_panel.get_offered()
	await _tap_key(KEY_ENTER)
	await _frames(3)
	check(not game.perk_panel.visible, "Enter on a card takes it")
	check(not offered.is_empty() and player.perks.stacks_of(offered[0]) > 0, "...the first card's perk")
	check(player.perks.entries.size() >= perks_before, "the perk is the hero's")
	get_tree().paused = false
	# The perk choice put off with B.
	game.offers.add(PerkDef.Rarity.COMMON, 3, "Level 3!", "Choose an upgrade", true)
	game.open_offers()
	await _frames(2)
	await _tap_pad(JOY_BUTTON_B)
	check(not game.perk_panel.visible and game.offers.size() == 1, "B puts the choice off")
	game.offers.clear()
	get_tree().paused = false
	# The ending's choice and the end screen hold the focus too (they never close by Back).
	if CONTENT.dungeon.finale:
		game.menus.ending.open(CONTENT.dungeon.finale)
		await _frames(2)
		await _check_keys_reach(game.menus.ending, "the ending's choice")
		game.menus.ending.hide()
	game.game_over_panel.show_result("Test")
	await _frames(2)
	await _check_keys_reach(game.game_over_panel, "the end of a run")
	game.game_over_panel.hide()
	get_tree().paused = false
	await _frames(2)


## The HUD fits every screen, on touch and on keys: nothing out of it, nothing over anything.
func _test_hud_layouts(game: Game) -> void:
	var hud := game.hud
	var before := get_tree().root.size
	hud.offers_button.count = 2
	await _frames(1)
	for size in SIZES:
		await _window(size)
		for kind in [InputDevice.Kind.TOUCH, InputDevice.Kind.KEYBOARD]:
			InputDevice.use(kind)
			await _frames(3)
			var widgets := {
				"stats": hud.get_node("TopLeft/HpBar"), "info": hud.get_node("%InfoLabel"),
				"bag": hud.get_node("%BagButton"), "pause": hud.get_node("%PauseButton"),
				"debug": hud.get_node_or_null("DebugButton"), "map": hud.get_node("%Minimap"),
				"seal": hud.get_node("%SealLabel"), "timer": hud.get_node("%TimerLabel"),
				"perks": hud.offers_button,
			}
			if kind == InputDevice.Kind.TOUCH:
				for button_name in ["AttackButton", "Skill1Button", "Skill2Button", "Skill3Button", "Skill4Button", "QuickItemButton", "Belt2Button", "Belt3Button"]:
					var button := hud.get_node("%" + button_name) as ActionButton
					button.visible = true  # every one, as with a full kit
					widgets[button_name] = button
			else:
				widgets["action bar"] = hud.action_bar
			var problems := _layout_problems(widgets)
			check(problems.is_empty(), "%s %s: the HUD holds (%s)" % [size, "touch" if kind == InputDevice.Kind.TOUCH else "keys", ", ".join(problems.slice(0, 4))])
		# The in-run panels fit too.
		_keys_mode()
		game.open_inventory()
		await _frames(2)
		var outside := _panel_outside(game.inventory_panel)
		check(outside.is_empty(), "%s: the bag fits (%s)" % [size, ", ".join(outside.slice(0, 3))])
		game.inventory_panel.close()
		game.open_pause_menu()
		await _frames(2)
		outside = _panel_outside(game.pause_menu)
		check(outside.is_empty(), "%s: the pause menu fits (%s)" % [size, ", ".join(outside.slice(0, 3))])
		game.pause_menu.hide()
		get_tree().paused = false
	hud.offers_button.count = 0
	InputDevice.use(InputDevice.Kind.TOUCH)
	await _restore_window(before)
