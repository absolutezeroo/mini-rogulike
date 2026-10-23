class_name OptionsPanel
extends Control
## Options window (title screen and pause menu), in the game's skin (MenuWindow). Two tabs: the
## settings, grouped (language, sound, controls, screen, tutorial), each option with its name and
## a short line saying what it does; and Controls, what does what on the device in use (its keys,
## buttons or touch, ControlsPage). Every change goes straight to Settings (applied and saved).
## Built in code; every control is reachable as %Name from the panel (%EnglishButton,
## %FrenchButton, %MasterSlider, %MusicSlider, %InterfaceSlider, %CombatSlider, %AmbienceSlider,
## %ShakeSlider, %ControlsSlider, %VibrationsCheck, %FixedStickCheck, %BatteryCheck,
## %FewerEffectsCheck, %FlashesCheck, %RunTimerCheck, %TutorialCheck, %ReplayTutorialButton, %AutoLootAll, %AutoLootBetter,
## %AutoLootOff, %StoriesFull, %StoriesShort, %StoriesOff, %FullscreenCheck (computers),
## %UiSizeBig, %UiSizeMedium, %UiSizeSmall, %SettingsTab, %ControlsTab, %ControlsPage,
## %CloseButton; Privacy: %PolicyButton, %CreditsButton, %PolicyPanel, %CreditsPanel, and with
## a server in the build: %BoardsNameText, %BoardsNameButton, %BoardsShowCheck, %NameDialog,
## %AnalyticsCheck, %ConsentDialog, %OnlineIdText, %DeleteDataButton, %DeleteDialog).
## The leaderboards' pseudonym and "Publish my scores online" live in the Leaderboards autoload,
## the statistics' consent in Privacy (their own files), not in Settings.
## Picking a language rebuilds the window in it at once; the title screen behind is rebuilt when
## the window closes (other screens pick it up the next time they open).

const SettingsScript := preload("res://src/autoload/settings.gd")  # its static helpers are called on the script, not the autoload

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
## Auto loot: Settings.LOOT_* -> its button, and the line saying what the picked one does.
var _loot_modes := {}
var _loot_help: Label
## Boss stories: Settings.STORIES_* -> its button, and the line saying what the picked one does.
var _story_modes := {}
var _story_help: Label
## Interface size: Settings.UI_* -> its button.
var _ui_sizes := {}
## The two tabs and what they show.
var _settings_tab: Button
var _controls_tab: Button
var _settings_page: Control
var _controls_page: ControlsPage
## The language changed while the window was open.
var _language_changed := false
## The online leaderboards' name and switch (null in a build without them), and its dialog.
var _boards_name: Label
var _boards_show: CheckButton
var _name_dialog: PseudonymDialog
## Privacy: the statistics' switch and questions, the online ID, the policy, the credits, the
## deletion request (null when not built).
var _analytics: CheckButton
var _consent: ConsentDialog
var _online_id: Label
var _policy: PrivacyPolicyPanel
var _credits: CreditsPanel
var _delete: DeleteDataDialog


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
	for mode: int in _loot_modes:
		(_loot_modes[mode] as Button).pressed.connect(_pick_loot_mode.bind(mode))
	for mode: int in _story_modes:
		(_story_modes[mode] as Button).pressed.connect(_pick_story_mode.bind(mode))
	for ui_size: int in _ui_sizes:
		(_ui_sizes[ui_size] as Button).pressed.connect(func() -> void:
			Settings.set_option(&"ui_size", ui_size)
			Sfx.play_ui(Sfx.bank.ui_click)
			_show_ui_size())
	_settings_tab.pressed.connect(show_page.bind(false))
	_controls_tab.pressed.connect(show_page.bind(true))
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
	_show_loot_mode()
	_show_story_mode()
	_show_ui_size()
	_show_boards()
	show_page(false)
	show()


## The online choices as Leaderboards and Privacy have them.
func _show_boards() -> void:
	if _boards_name:
		_boards_name.text = Leaderboards.display_name()
		_boards_show.set_pressed_no_signal(Leaderboards.shown)
	if _analytics:
		_analytics.set_pressed_no_signal(Privacy.analytics_allowed())
	if _online_id:
		_online_id.text = Leaderboards.device_id if not Leaderboards.device_id.is_empty() else tr("None yet (nothing was sent)")


## The settings (`controls` false) or what does what on the device in use (true).
func show_page(controls: bool) -> void:
	_settings_tab.set_pressed_no_signal(not controls)
	_controls_tab.set_pressed_no_signal(controls)
	_settings_page.visible = not controls
	_controls_page.visible = controls
	if controls:
		_controls_page.refresh()


func close() -> void:
	if _name_dialog and _name_dialog.visible:
		_name_dialog.cancel()
		return
	if _consent and _consent.visible:
		_consent.back()
		return
	if _delete and _delete.visible:
		_delete.back()
		return
	for page: InfoPanel in [_policy, _credits]:
		if page and page.back():
			return
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
	_loot_modes.clear()
	_story_modes.clear()
	_ui_sizes.clear()
	_boards_name = null
	_boards_show = null
	_name_dialog = null
	_analytics = null
	_consent = null
	_online_id = null
	_policy = null
	_credits = null
	_delete = null
	_build()
	_wire()
	open()
	language_changed.emit()


func _pick_loot_mode(mode: int) -> void:
	Settings.set_option(&"auto_loot", mode)
	Sfx.play_ui(Sfx.bank.ui_click)
	_show_loot_mode()


func _show_loot_mode() -> void:
	for mode: int in _loot_modes:
		(_loot_modes[mode] as Button).set_pressed_no_signal(mode == Settings.auto_loot)
	if _loot_help:
		_loot_help.text = _loot_help_text(Settings.auto_loot)


func _show_ui_size() -> void:
	for ui_size: int in _ui_sizes:
		(_ui_sizes[ui_size] as Button).set_pressed_no_signal(ui_size == Settings.ui_size)


func _pick_story_mode(mode: int) -> void:
	Settings.set_option(&"boss_stories", mode)
	Sfx.play_ui(Sfx.bank.ui_click)
	_show_story_mode()


func _show_story_mode() -> void:
	for mode: int in _story_modes:
		(_story_modes[mode] as Button).set_pressed_no_signal(mode == Settings.boss_stories)
	if _story_help:
		_story_help.text = _story_help_text(Settings.boss_stories)


## What a Boss stories mode does, in a line.
static func _story_help_text(mode: int) -> String:
	if mode == Settings.STORIES_SHORT:
		return TranslationServer.tr("Only its name and a line it remembers, about two seconds.")
	if mode == Settings.STORIES_OFF:
		return TranslationServer.tr("No scene: the fight starts at once.")
	return TranslationServer.tr("A new chapter of its story when there is one; otherwise two seconds.")


## What a mode does, in a line.
static func _loot_help_text(mode: int) -> String:
	if mode == Settings.LOOT_ALL:
		return TranslationServer.tr("Walking over an item takes it.")
	if mode == Settings.LOOT_OFF:
		return TranslationServer.tr("Gear stays on the ground: walk over it, then Take.")
	return TranslationServer.tr("Gear only if it beats what you wear; the rest stays on the ground.")


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
	var saved := UiSkin.label(note, Fonts.BODY, UiSkin.DIM, true)
	saved.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	saved.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	window.header_left.add_child(saved)
	_build_languages(window.header_left)
	_build_tabs(window.body)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	window.body.add_child(columns)
	_settings_page = columns
	_controls_page = ControlsPage.new()
	_controls_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	window.body.add_child(_controls_page)
	MenuWindow.expose(_controls_page, "ControlsPage", self)
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
	_checks[_check(screen, tr("Fewer effects"), tr("Half the particles, no heat haze nor glow: smoother on older phones."), "FewerEffectsCheck")] = &"fewer_effects"
	_checks[_check(screen, tr("Screen flashes"), tr("Lightning lights up the whole screen for an instant."), "FlashesCheck")] = &"screen_flashes"
	_checks[_check(screen, tr("Battery saver"), tr("30 FPS: the phone stays cooler."), "BatteryCheck")] = &"battery_saver"
	_checks[_check(screen, tr("Run timer"), tr("The run's time, under the map."), "RunTimerCheck")] = &"run_timer"
	if SettingsScript.has_window_modes():
		_checks[_check(screen, tr("Fullscreen"), tr("The whole screen, or a window you can resize (F11, Alt+Enter)."), "FullscreenCheck")] = &"fullscreen"
	_build_ui_size(screen)

	# Loot under Sound, where it shows without scrolling; the tutorial (set once) closes the right
	# column, scrolled to on a small screen.
	_build_loot(_section(left, tr("Loot")))
	_build_stories(_section(left, tr("Story")))

	var tutorial := _section(right, tr("Tutorial"))
	_tutorial = _check(tutorial, tr("Tutorial hints"), tr("Short tips during your first runs."), "TutorialCheck")
	_checks[_tutorial] = &"tutorial_hints"
	var replay_row := HBoxContainer.new()
	replay_row.add_theme_constant_override("separation", 12)
	tutorial.add_child(replay_row)
	replay_row.add_child(_words(tr("Replay tutorial"), tr("Every tip again, from the first steps.")))
	_replay = MenuWindow.button(tr("Replay tutorial"), Fonts.BODY, 44)
	_replay.custom_minimum_size.x = 190
	_replay.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	replay_row.add_child(_replay)
	MenuWindow.expose(_replay, "ReplayTutorialButton", self)
	_build_privacy(_section(right, tr("Privacy")))


## Privacy: with a server in the build, the leaderboards (the name, "Publish my scores online"),
## the gameplay statistics' switch, the device's online ID and "Delete my online data"; always,
## the privacy policy and the credits.
func _build_privacy(section: VBoxContainer) -> void:
	if Leaderboards.is_available():
		_build_boards(section)
		_build_analytics(section)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	section.add_child(row)
	var policy := MenuWindow.button(tr("Privacy policy"), Fonts.BODY, 44)
	policy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(policy)
	MenuWindow.expose(policy, "PolicyButton", self)
	var credits := MenuWindow.button(tr("Credits"), Fonts.BODY, 44)
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(credits)
	MenuWindow.expose(credits, "CreditsButton", self)
	_policy = PrivacyPolicyPanel.new()
	add_child(_policy)
	MenuWindow.expose(_policy, "PolicyPanel", self)
	_credits = CreditsPanel.new()
	add_child(_credits)
	MenuWindow.expose(_credits, "CreditsPanel", self)
	policy.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_policy.open())
	credits.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_credits.open())
	_policy.closed.connect(func() -> void: _refocus(policy))
	_credits.closed.connect(func() -> void: _refocus(credits))


## The gameplay statistics' switch (on: the age and consent questions, ConsentDialog; off: at
## once), the device's online ID, and the deletion request.
func _build_analytics(section: VBoxContainer) -> void:
	_analytics = _check(section, tr("Gameplay statistics"), tr("A summary of each run sent to help balance the game (asked first). Off: nothing is sent."), "AnalyticsCheck")
	_consent = ConsentDialog.new()
	add_child(_consent)
	MenuWindow.expose(_consent, "ConsentDialog", self)
	_consent.finished.connect(func() -> void:
		_show_boards()
		_refocus(_analytics))
	_analytics.toggled.connect(func(on: bool) -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		if on:
			_analytics.set_pressed_no_signal(false)  # (on only once accepted)
			_consent.ask()
		else:
			Privacy.refuse()
		_show_boards())
	var id_row := _words(tr("Your online ID"), "")
	_online_id = id_row.get_child(1) as Label
	_online_id.add_theme_color_override("font_color", UiSkin.GOLD)
	_online_id.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (an ID)
	section.add_child(id_row)
	MenuWindow.expose(_online_id, "OnlineIdText", self)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	section.add_child(row)
	row.add_child(_words(tr("Delete my online data"), tr("Asks by email for what was sent to be deleted, then turns everything online off.")))
	var delete := MenuWindow.button(tr("Delete"), Fonts.BODY, 44)
	delete.custom_minimum_size.x = 150
	delete.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(delete)
	MenuWindow.expose(delete, "DeleteDataButton", self)
	_delete = DeleteDataDialog.new()
	add_child(_delete)
	MenuWindow.expose(_delete, "DeleteDialog", self)
	_delete.finished.connect(func() -> void:
		_show_boards()
		_refocus(delete))
	delete.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_delete.open())


## Keys or a gamepad: the focus back on `control` once what it opened closed.
func _refocus(control: Control) -> void:
	if is_instance_valid(control) and control.is_visible_in_tree() and InputDevice.uses_buttons():
		control.grab_focus()


## The online leaderboards: the name shown (Change opens PseudonymDialog), and the switch that
## publishes the scores or keeps every score home.
func _build_boards(section: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	section.add_child(row)
	var words := _words(tr("Your name"), "")
	_boards_name = words.get_child(1) as Label
	_boards_name.add_theme_color_override("font_color", UiSkin.GOLD)
	_boards_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # (a player's name)
	row.add_child(words)
	MenuWindow.expose(_boards_name, "BoardsNameText", self)
	var change := MenuWindow.button(tr("Change"), Fonts.BODY, 44)
	change.custom_minimum_size.x = 150
	change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(change)
	MenuWindow.expose(change, "BoardsNameButton", self)
	_boards_show = _check(section, tr("Publish my scores online"), tr("Your Dawn Knell scores and this name, public on the leaderboards. Off: nothing is sent nor read."), "BoardsShowCheck")
	_boards_show.toggled.connect(func(on: bool) -> void:
		Sfx.play_ui(Sfx.bank.ui_click)
		if on and not Leaderboards.name_chosen:
			# Never chosen: the question with what it means first.
			_boards_show.set_pressed_no_signal(false)
			_name_dialog.open()
			return
		Leaderboards.set_shown(on)
		_show_boards())
	_name_dialog = PseudonymDialog.new()
	add_child(_name_dialog)
	MenuWindow.expose(_name_dialog, "NameDialog", self)
	_name_dialog.finished.connect(_show_boards)
	change.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_name_dialog.open())


## Auto loot: its name, three buttons (one stays pressed), what the picked one does. Gold always
## flies to you.
func _build_loot(section: VBoxContainer) -> void:
	# One row: its name on the left, the three modes on the right (the window has no room to spare).
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	section.add_child(row)
	row.add_child(_words(tr("Auto loot"), tr("Gold, potions, runes and keys: always.")))
	var modes := [
		[Settings.LOOT_ALL, tr("All"), "AutoLootAll"],
		[Settings.LOOT_BETTER, tr("Better only"), "AutoLootBetter"],
		[Settings.LOOT_OFF, tr("By hand"), "AutoLootOff"],
	]
	for entry: Array in modes:
		var button := MenuWindow.button(entry[1], Fonts.BODY, 44)
		button.toggle_mode = true
		button.custom_minimum_size.x = 118
		row.add_child(button)
		_loot_modes[entry[0]] = button
		MenuWindow.expose(button, entry[2], self)
	_loot_help = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	section.add_child(_loot_help)


## Boss stories: its name, three buttons (one stays pressed), what the picked one does. A tap
## skips a story anyway.
func _build_stories(section: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	section.add_child(row)
	row.add_child(_words(tr("Boss stories"), Prompts.pick("Before a warden's fight. A tap skips it.", "Before a warden's fight. {ui_accept} skips it.")))  # i18n
	var modes := [
		[Settings.STORIES_FULL, tr("Full"), "StoriesFull"],
		[Settings.STORIES_SHORT, tr("Short"), "StoriesShort"],
		[Settings.STORIES_OFF, tr("Off"), "StoriesOff"],
	]
	for entry: Array in modes:
		var button := MenuWindow.button(entry[1], Fonts.BODY, 44)
		button.toggle_mode = true
		button.custom_minimum_size.x = 118
		row.add_child(button)
		_story_modes[entry[0]] = button
		MenuWindow.expose(button, entry[2], self)
	_story_help = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	section.add_child(_story_help)


## The two tabs over the window's body: the settings, and what does what (switched with the tab
## keys too: MenuNav).
func _build_tabs(body: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	_settings_tab = _tab(row, tr("Settings"), "SettingsTab")
	_controls_tab = _tab(row, tr("Controls"), "ControlsTab")
	var keys := PromptGlyph.make(&"menu_tabs")
	row.add_child(keys)


func _tab(row: HBoxContainer, text: String, node_name: String) -> Button:
	var button := MenuWindow.button(text, Fonts.BODY, 44)
	button.toggle_mode = true
	button.custom_minimum_size.x = 160
	button.add_to_group(MenuNav.TABS)
	row.add_child(button)
	MenuWindow.expose(button, node_name, self)
	return button


## Interface size: its name, three buttons (one stays pressed).
func _build_ui_size(section: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	section.add_child(row)
	row.add_child(_words(tr("Interface size"), tr("Smaller leaves more room on a big screen.")))
	var sizes := [
		[Settings.UI_BIG, tr("Big"), "UiSizeBig"],
		[Settings.UI_MEDIUM, tr("Medium"), "UiSizeMedium"],
		[Settings.UI_SMALL, tr("Small"), "UiSizeSmall"],
	]
	for entry: Array in sizes:
		var button := MenuWindow.button(entry[1], Fonts.BODY, 44)
		button.toggle_mode = true
		button.custom_minimum_size.x = 96
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(button)
		_ui_sizes[entry[0]] = button
		MenuWindow.expose(button, entry[2], self)


## In the header, always in sight: "Language" and two big buttons, each language's name in
## itself; the one in use stays pressed.
func _build_languages(row: HBoxContainer) -> void:
	var title := UiSkin.label(tr("Language"), Fonts.BODY, UiSkin.GOLD)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	for code: String in Settings.LANGUAGES:
		var button := MenuWindow.button(Settings.LANGUAGE_NAMES[code], Fonts.BODY, 48)
		button.toggle_mode = true
		button.custom_minimum_size.x = 160
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# A language's own name is never translated.
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.set_meta(MenuNav.NOT_FIRST, true)
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
	# Both wrap: a long name in French (beside three buttons) must not push the window past a
	# 1280-wide screen.
	words.add_child(UiSkin.label(title, Fonts.BODY, UiSkin.TEXT, true))
	words.add_child(UiSkin.label(helper, Fonts.BODY, UiSkin.DIM, true))
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
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 44)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
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
