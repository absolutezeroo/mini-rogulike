class_name OptionsPanel
extends Control
## Options window (title screen and pause menu), in the game's skin (MenuWindow). Grouped
## (language, sound, controls, screen, tutorial), each option with its name and a short line saying
## what it does. Every change goes straight to Settings (applied and saved).
## Built in code; every control is reachable as %Name from the panel (%EnglishButton,
## %FrenchButton, %MasterSlider, %MusicSlider, %InterfaceSlider, %CombatSlider, %AmbienceSlider,
## %ShakeSlider, %ControlsSlider, %VibrationsCheck, %FixedStickCheck, %BatteryCheck,
## %FewerEffectsCheck, %RunTimerCheck, %TutorialCheck, %ReplayTutorialButton, %CloseButton).
## Picking a language rebuilds the window in it at once; the title screen behind is rebuilt when
## the window closes (other screens pick it up the next time they open).

signal closed
## The player picked another language (Settings.language is already set).
signal language_changed

const SLIDER_WIDTH := 180.0

## Volume sliders: Settings key -> slider (general, music, interface, combat, ambience).
var _volumes := {}
var _shake: HSlider
var _controls: HSlider
var _vibrations: CheckButton
## Plain on/off options: check -> Settings key.
var _checks := {}
## Slider -> the label showing its value.
var _values := {}
var _replay: Button
var _tutorial: CheckButton
## Language code -> its button.
var _languages := {}
## The language changed while the window was open.
var _language_changed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()
	_wire()


## Connects the controls to Settings (after each build).
func _wire() -> void:
	for code: String in _languages:
		(_languages[code] as Button).pressed.connect(_pick_language.bind(code))
	for key: StringName in _volumes:
		_bind_slider(_volumes[key], key)
	_bind_slider(_shake, &"screen_shake")
	_bind_slider(_controls, &"controls_scale")
	_vibrations.toggled.connect(func(on: bool) -> void:
		Settings.set_option(&"vibrations", on)
		if on:
			Settings.vibrate(0.6))
	for check: CheckButton in _checks:
		var key: StringName = _checks[check]
		check.toggled.connect(func(on: bool) -> void:
			Settings.set_option(key, on)
			Sfx.play_ui(Sfx.bank.ui_click))
	# Every hint shows again, from the first steps (and the hints come back on).
	_replay.pressed.connect(func() -> void:
		Profile.reset_hints()
		Settings.set_option(&"tutorial_hints", true)
		_tutorial.set_pressed_no_signal(true)
		_replay.text = tr("Done! Tips are back")
		Sfx.play_ui(Sfx.bank.ui_click))


func open() -> void:
	for slider: HSlider in _volumes.values() + [_shake, _controls]:
		var key: StringName = slider.get_meta(&"option")
		slider.set_value_no_signal(Settings.get(key))
		_show_value(slider)
	_vibrations.set_pressed_no_signal(Settings.vibrations)
	for check: CheckButton in _checks:
		check.set_pressed_no_signal(Settings.get(_checks[check]))
	_replay.text = tr("Replay tutorial")
	for code: String in _languages:
		(_languages[code] as Button).set_pressed_no_signal(code == Settings.language)
	show()


func close() -> void:
	Sfx.play_ui(Sfx.bank.ui_close)
	hide()
	closed.emit()
	# The title screen was built in the old language: build it again.
	if _language_changed and get_tree().current_scene is TitleScreen:
		get_tree().reload_current_scene()
	_language_changed = false


## Switches the game to another language and rebuilds this window in it.
func _pick_language(code: String) -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	if code == Settings.language:
		(_languages[code] as Button).set_pressed_no_signal(true)
		return
	Settings.set_option(&"language", code)
	_language_changed = true
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_checks.clear()
	_values.clear()
	_volumes.clear()
	_languages.clear()
	_build()
	_wire()
	open()
	language_changed.emit()


func _bind_slider(slider: HSlider, option: StringName) -> void:
	slider.set_meta(&"option", option)
	slider.value_changed.connect(func(value: float) -> void:
		Settings.set_option(option, value)
		_show_value(slider))
	# Letting go plays a sound of what it sets, to hear the new volume.
	slider.drag_ended.connect(func(_changed: bool) -> void: _preview(option))


## A short sound of what a slider sets: a click for the interface, a hit for combat, coins for
## the ambience (the music is its own preview).
func _preview(option: StringName) -> void:
	match option:
		&"music_volume":
			pass
		&"combat_volume":
			Sfx.play_at(Sfx.bank.monster_hurt, Sfx.listener_position())
		&"ambience_volume":
			Sfx.play_world(Sfx.bank.coin, Sfx.listener_position())
		_:
			Sfx.play_ui(Sfx.bank.ui_click)


func _show_value(slider: HSlider) -> void:
	var label: Label = _values.get(slider)
	if label:
		label.text = tr("%d%%") % roundi(slider.value * 100.0)


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	var window := MenuWindow.new(tr("Options"))
	window.close_requested.connect(close)
	add_child(window)
	MenuWindow.expose(window.close_button, "CloseButton", self)
	# In a run, the menus already built keep their words until the next run: say so.
	var in_run := _language_changed and not get_tree().current_scene is TitleScreen
	var note := tr("Language changed: some menus follow from the next run.") if in_run else tr("Every change is saved right away.")
	var saved := UiSkin.label(note, 16, UiSkin.DIM, true)
	saved.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saved.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	window.header_left.add_child(saved)
	_build_languages(window.header_left)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	window.body.add_child(columns)
	var left := _column(columns)
	var right := _column(columns)

	var sound := _section(left, tr("Sound"))
	_volumes[&"master_volume"] = _slider(sound, tr("General"), tr("Every sound at once."), 0.0, 1.0, 0.05, "MasterSlider")
	_volumes[&"music_volume"] = _slider(sound, tr("Music"), tr("Background music."), 0.0, 1.0, 0.05, "MusicSlider")
	_volumes[&"ui_volume"] = _slider(sound, tr("Interface"), tr("Menus, buttons, level up."), 0.0, 1.0, 0.05, "InterfaceSlider")
	_volumes[&"combat_volume"] = _slider(sound, tr("Combat"), tr("Weapons, hits, cries, spells."), 0.0, 1.0, 0.05, "CombatSlider")
	_volumes[&"ambience_volume"] = _slider(sound, tr("Ambience"), tr("Footsteps, wind, doors, chests."), 0.0, 1.0, 0.05, "AmbienceSlider")

	var controls := _section(right, tr("Touch controls"))
	_controls = _slider(controls, tr("Buttons size"), tr("Joystick and buttons."), 0.7, 1.3, 0.05, "ControlsSlider")
	_checks[_check(controls, tr("Fixed joystick"), tr("Stays in its corner instead of following your thumb."), "FixedStickCheck")] = &"fixed_joystick"
	_vibrations = _check(controls, tr("Vibrations"), tr("The phone buzzes on big hits and critical hits."), "VibrationsCheck")

	var screen := _section(right, tr("Screen and battery"))
	_shake = _slider(screen, tr("Screen shake"), tr("On big hits."), 0.0, 1.5, 0.1, "ShakeSlider")
	_checks[_check(screen, tr("Fewer effects"), tr("Half the particles: smoother on older phones."), "FewerEffectsCheck")] = &"fewer_effects"
	_checks[_check(screen, tr("Battery saver"), tr("30 FPS: the phone stays cooler."), "BatteryCheck")] = &"battery_saver"
	_checks[_check(screen, tr("Run timer"), tr("The run's time, under the map."), "RunTimerCheck")] = &"run_timer"

	var tutorial := _section(left, tr("Tutorial"))
	_tutorial = _check(tutorial, tr("Tutorial hints"), tr("Short tips during your first runs."), "TutorialCheck")
	_checks[_tutorial] = &"tutorial_hints"
	var replay_row := HBoxContainer.new()
	replay_row.add_theme_constant_override("separation", 12)
	tutorial.add_child(replay_row)
	replay_row.add_child(_words(tr("Replay tutorial"), tr("Every tip again, from the first steps.")))
	_replay = MenuWindow.button(tr("Replay tutorial"), 17, 44)
	_replay.custom_minimum_size.x = 190
	_replay.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	replay_row.add_child(_replay)
	MenuWindow.expose(_replay, "ReplayTutorialButton", self)


## In the header, always in sight: "Language" and two big buttons, each language's name in
## itself; the one in use stays pressed.
func _build_languages(row: HBoxContainer) -> void:
	var title := UiSkin.label(tr("Language"), 18, UiSkin.GOLD)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	for code: String in Settings.LANGUAGES:
		var button := MenuWindow.button(Settings.LANGUAGE_NAMES[code], 19, 48)
		button.toggle_mode = true
		button.custom_minimum_size.x = 160
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# A language's own name is never translated.
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.add_child(button)
		_languages[code] = button
		MenuWindow.expose(button, "FrenchButton" if code == "fr" else "EnglishButton", self)


## One of the two columns, scrolling if the screen is short.
func _column(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	return column


func _section(column: VBoxContainer, heading: String) -> VBoxContainer:
	var section: Dictionary = RpgWindow.section(heading)
	column.add_child(section.box)
	(section.column as VBoxContainer).add_theme_constant_override("separation", 4)
	return section.column


## The option's name, and below it what it does.
func _words(title: String, helper: String) -> VBoxContainer:
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	words.add_child(UiSkin.label(title, 18))
	words.add_child(UiSkin.label(helper, 14, UiSkin.DIM, true))
	return words


func _slider(section: VBoxContainer, title: String, helper: String, low: float, high: float, step: float, node_name: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	section.add_child(row)
	row.add_child(_words(title, helper))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 44)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := UiSkin.label("", 17, UiSkin.GOLD)
	value.custom_minimum_size.x = 58
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value)
	_values[slider] = value
	MenuWindow.expose(slider, node_name, self)
	return slider


## An on/off option: its name and what it does, the switch on the right. Tapping the name
## flips it too.
func _check(section: VBoxContainer, title: String, helper: String, node_name: String) -> CheckButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	section.add_child(row)
	var words := _words(title, helper)
	words.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(words)
	var check := CheckButton.new()
	check.custom_minimum_size = Vector2(MenuWindow.SWITCH_SIZE.x + 8, 40)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	MenuWindow.style_switch(check)
	row.add_child(check)
	words.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed \
				and Rect2(Vector2.ZERO, words.size).has_point(click.position):
			check.button_pressed = not check.button_pressed)
	MenuWindow.expose(check, node_name, self)
	return check
