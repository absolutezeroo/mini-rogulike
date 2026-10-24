class_name OptionsPanel
extends Control
## Options window (title screen and pause menu), in the game's skin (MenuWindow). Five tabs (TABS,
## switched by a tap, a click, Q / E or LB / RB: MenuNav), each a page of grouped options with
## their name and a short line saying what it does:
## - Gameplay: the language, auto loot, boss stories, in a run (run timer, screen shake,
##   vibrations), the tutorial (hints, Replay tutorial);
## - Graphics: the screen (fullscreen on a computer, interface size), the touch controls (buttons
##   size, fixed joystick), effects and battery (fewer effects, screen flashes, battery saver);
## - Audio: the five volumes;
## - Controls: what does what on the device in use (its keys, buttons or touch, ControlsPage);
## - Privacy: online (with a server in the build: the leaderboards' name and switch, the gameplay
##   statistics, the online ID, the deletion), the privacy policy and the credits.
## Every change goes straight to Settings (applied and saved).
## Built in code; every control is reachable as %Name from the panel (%EnglishButton,
## %FrenchButton, %MasterSlider, %MusicSlider, %InterfaceSlider, %CombatSlider, %AmbienceSlider,
## %ShakeSlider, %ControlsSlider, %VibrationsCheck, %FixedStickCheck, %BatteryCheck,
## %FewerEffectsCheck, %FlashesCheck, %RunTimerCheck, %TutorialCheck, %ReplayTutorialButton, %AutoLootAll, %AutoLootBetter,
## %AutoLootOff, %StoriesFull, %StoriesShort, %StoriesOff, %FullscreenCheck (computers),
## %UiSizeBig, %UiSizeMedium, %UiSizeSmall, the tabs %GameplayTab, %GraphicsTab, %AudioTab,
## %ControlsTab, %PrivacyTab and their pages %GameplayPage, %GraphicsPage, %AudioPage,
## %ControlsPage, %PrivacyPage, %CloseButton; Privacy: %PolicyButton, %CreditsButton,
## %PolicyPanel, %CreditsPanel, and with a server in the build: %BoardsNameText,
## %BoardsNameButton, %BoardsShowCheck, %NameDialog, %AnalyticsCheck, %ConsentDialog,
## %OnlineIdText, %DeleteDataButton, %DeleteDialog).
## The leaderboards' pseudonym and "Publish my scores online" live in the Leaderboards autoload,
## the statistics' consent in Privacy (their own files), not in Settings.
## Picking a language rebuilds the window in it at once; the title screen behind is rebuilt when
## the window closes (other screens pick it up the next time they open).

signal closed
## The player picked another language (Settings.language is already set).
signal language_changed

## The window's tabs, in their order on screen.
enum Tab { GAMEPLAY, GRAPHICS, AUDIO, CONTROLS, PRIVACY }

## Each tab's name (translated where shown), also its nodes' names: %<name>Tab, %<name>Page.
## The Settings autoload's script, for its static functions.
const SettingsScript := preload("res://src/autoload/settings.gd")
const TAB_NAMES := {
	Tab.GAMEPLAY: "Gameplay",  # i18n
	Tab.GRAPHICS: "Graphics",  # i18n
	Tab.AUDIO: "Audio",  # i18n
	Tab.CONTROLS: "Controls",  # i18n
	Tab.PRIVACY: "Privacy",  # i18n
}

const SLIDER_WIDTH := 180.0
## A slider's height: the strip a finger grabs (UI units).
const SLIDER_HEIGHT := 48.0
## The smallest move of a slider under a finger or the mouse (smooth; every range and key step
## is a multiple of it, so a value set in code stays exact).
const FINE_STEP := 0.01

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
## The tab buttons and their pages, by Tab; the tab shown.
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _controls_page: ControlsPage
var _current := Tab.GAMEPLAY
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
	for tab: int in _tab_buttons.size():
		_tab_buttons[tab].pressed.connect(func() -> void:
			if tab != _current:
				Sfx.play_ui(Sfx.bank.ui_click)
			show_tab(tab as Tab))
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
	show_tab(Tab.GAMEPLAY)
	show()


## The online choices as Leaderboards and Privacy have them.
func _show_boards() -> void:
	if _boards_name:
		_boards_name.text = Leaderboards.display_name()
		_boards_show.set_pressed_no_signal(Leaderboards.shown)
	if _analytics:
		_analytics.set_pressed_no_signal(Privacy.analytics_allowed())
	if _online_id:
		_online_id.text = OnlineSession.device_id if not OnlineSession.device_id.is_empty() else tr("None yet (nothing was sent)")


## Shows the page of `tab` (its button stays pressed, the others not).
func show_tab(tab: Tab) -> void:
	_current = tab
	for i in _pages.size():
		_tab_buttons[i].set_pressed_no_signal(i == tab)
		_pages[i].visible = i == tab
	if tab == Tab.CONTROLS:
		_controls_page.refresh()


## The tab shown.
func current_tab() -> Tab:
	return _current


## The page of `tab` (tests).
func page(tab: Tab) -> Control:
	return _pages[tab]


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
	for info: InfoPanel in [_policy, _credits]:
		if info and info.back():
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
	_tab_buttons.clear()
	_pages.clear()
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


## While a finger or the mouse drags it, the value follows and applies at once (the volume heard)
## without writing the file at every step; letting go saves it and plays a sound of what it sets.
## A key or a gamepad's step saves at once.
func _bind_slider(slider: HSlider, option: StringName) -> void:
	slider.set_meta(&"option", option)
	slider.drag_started.connect(func() -> void: slider.set_meta(&"dragging", true))
	slider.value_changed.connect(func(value: float) -> void:
		if slider.has_meta(&"dragging"):
			Settings.preview_option(option, value)
		else:
			Settings.set_option(option, value)
		_show_value(slider))
	slider.drag_ended.connect(func(_changed: bool) -> void:
		slider.remove_meta(&"dragging")
		Settings.set_option(option, slider.value)
		_preview(option))


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
	_build_tabs(window.body)


## The tabs over the window's body (switched with the tab keys too: MenuNav; not in the header:
## five French names and the header's Close don't fit a 1280-wide screen on one line), and under
## them each tab's page, built into the body by its own function (which returns it); one page
## shows at a time.
func _build_tabs(body: VBoxContainer) -> void:
	var builders := {
		Tab.GAMEPLAY: _build_gameplay,
		Tab.GRAPHICS: _build_graphics,
		Tab.AUDIO: _build_audio,
		Tab.CONTROLS: _build_controls,
		Tab.PRIVACY: _build_privacy,
	}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body.add_child(row)
	var keys := PromptGlyph.make(&"menu_tabs")
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(keys)
	for tab: int in Tab.values():
		var tab_name: String = TAB_NAMES[tab]
		var button := MenuWindow.button(tr(tab_name), Fonts.BODY, 44)
		button.toggle_mode = true
		button.custom_minimum_size.x = 150
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_to_group(MenuNav.TABS)
		row.add_child(button)
		MenuWindow.expose(button, tab_name + "Tab", self)
		_tab_buttons.append(button)
		var page_node := (builders[tab] as Callable).call(body) as Control
		page_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
		MenuWindow.expose(page_node, tab_name + "Page", self)
		_pages.append(page_node)


## Gameplay: the language (first: a player who can't read the one in use finds it at once), auto
## loot and boss stories; what shows or shakes in a run, and the tutorial.
func _build_gameplay(body: VBoxContainer) -> Control:
	var page_node := _page(body)
	var left := _column(page_node)
	var right := _column(page_node)
	_build_languages(_section(left, tr("Language")))
	_build_loot(_section(left, tr("Loot")))
	_build_stories(_section(left, tr("Story")))
	var in_run := _section(right, tr("In a run"))
	_checks[_check(in_run, tr("Run timer"), tr("The run's time, under the map."), "RunTimerCheck")] = &"run_timer"
	_shake = _slider(in_run, tr("Screen shake"), tr("On big hits."), 0.0, 1.5, 0.1, "ShakeSlider")
	_vibrations = _check(in_run, tr("Vibrations"), tr("The phone buzzes on big hits and critical hits."), "VibrationsCheck")
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
	return page_node


## Graphics: the screen (fullscreen, interface size), the touch controls' look, the effects and
## the battery.
func _build_graphics(body: VBoxContainer) -> Control:
	var page_node := _page(body)
	var left := _column(page_node)
	var right := _column(page_node)
	var screen := _section(left, tr("Screen"))
	if SettingsScript.has_window_modes():
		_checks[_check(screen, tr("Fullscreen"), tr("The whole screen, or a window you can resize (F11, Alt+Enter)."), "FullscreenCheck")] = &"fullscreen"
	_build_ui_size(screen)
	var controls := _section(left, tr("Touch controls"))
	_controls = _slider(controls, tr("Buttons size"), tr("Joystick and buttons."), 0.7, 1.3, 0.05, "ControlsSlider")
	_checks[_check(controls, tr("Fixed joystick"), tr("Stays in its corner instead of following your thumb."), "FixedStickCheck")] = &"fixed_joystick"
	var effects := _section(right, tr("Effects and battery"))
	_checks[_check(effects, tr("Fewer effects"), tr("Half the particles, no heat haze nor glow: smoother on older phones."), "FewerEffectsCheck")] = &"fewer_effects"
	_checks[_check(effects, tr("Screen flashes"), tr("Lightning lights up the whole screen for an instant."), "FlashesCheck")] = &"screen_flashes"
	_checks[_check(effects, tr("Battery saver"), tr("30 FPS: the phone stays cooler."), "BatteryCheck")] = &"battery_saver"
	return page_node


## Audio: the five volumes, one under the other, the sliders long (a single column).
func _build_audio(body: VBoxContainer) -> Control:
	var page_node := _page(body)
	var sound := _section(_column(page_node), tr("Sound"))
	_volumes[&"master_volume"] = _slider(sound, tr("General"), tr("Every sound at once."), 0.0, 1.0, 0.05, "MasterSlider", true)
	_volumes[&"music_volume"] = _slider(sound, tr("Music"), tr("Background music."), 0.0, 1.0, 0.05, "MusicSlider", true)
	_volumes[&"ui_volume"] = _slider(sound, tr("Interface"), tr("Menus, buttons, level up."), 0.0, 1.0, 0.05, "InterfaceSlider", true)
	_volumes[&"combat_volume"] = _slider(sound, tr("Combat"), tr("Weapons, hits, cries, spells."), 0.0, 1.0, 0.05, "CombatSlider", true)
	_volumes[&"ambience_volume"] = _slider(sound, tr("Ambience"), tr("Footsteps, wind, doors, chests."), 0.0, 1.0, 0.05, "AmbienceSlider", true)
	# (0.05: a key's or a gamepad's step; a finger moves them by the hundredth: _slider())
	return page_node


## Controls: what does what on the device in use (ControlsPage, filled when shown).
func _build_controls(body: VBoxContainer) -> Control:
	_controls_page = ControlsPage.new()
	body.add_child(_controls_page)
	return _controls_page


## A page of settings in `body`: columns side by side (each scrolls on its own).
func _page(body: VBoxContainer) -> HBoxContainer:
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 14)
	body.add_child(columns)
	return columns


## Privacy: with a server in the build, the leaderboards (the name, "Publish my scores online")
## on the left and the player's data on the right (the gameplay statistics' switch, the device's
## online ID, "Delete my online data"); always, the privacy policy and the credits.
func _build_privacy(body: VBoxContainer) -> Control:
	var page_node := _page(body)
	var left := _column(page_node)
	if Leaderboards.is_available():
		_build_boards(_section(left, tr("Leaderboards")))
		_build_analytics(_section(_column(page_node), tr("Your data")))
	var about := _section(left, tr("Policy and credits"))
	about.add_child(UiSkin.label(tr("What is sent, to whom and why; who made the game and its licenses."), Fonts.BODY, UiSkin.DIM, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	about.add_child(row)
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
	return page_node


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
	_loot_modes = _choice(section, tr("Auto loot"), tr("Gold, potions, runes and keys: always."), [
		[Settings.LOOT_ALL, tr("All"), "AutoLootAll"],
		[Settings.LOOT_BETTER, tr("Better only"), "AutoLootBetter"],
		[Settings.LOOT_OFF, tr("By hand"), "AutoLootOff"],
	])
	_loot_help = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	section.add_child(_loot_help)


## Boss stories: its name, three buttons (one stays pressed), what the picked one does. A tap
## skips a story anyway.
func _build_stories(section: VBoxContainer) -> void:
	_story_modes = _choice(section, tr("Boss stories"), Prompts.pick("Before a warden's fight. A tap skips it.", "Before a warden's fight. {ui_accept} skips it."), [  # i18n
		[Settings.STORIES_FULL, tr("Full"), "StoriesFull"],
		[Settings.STORIES_SHORT, tr("Short"), "StoriesShort"],
		[Settings.STORIES_OFF, tr("Off"), "StoriesOff"],
	])
	_story_help = UiSkin.label("", Fonts.BODY, UiSkin.GOLD, true)
	section.add_child(_story_help)


## Interface size: its name, three buttons (one stays pressed).
func _build_ui_size(section: VBoxContainer) -> void:
	_ui_sizes = _choice(section, tr("Interface size"), tr("Smaller leaves more room on a big screen."), [
		[Settings.UI_BIG, tr("Big"), "UiSizeBig"],
		[Settings.UI_MEDIUM, tr("Medium"), "UiSizeMedium"],
		[Settings.UI_SMALL, tr("Small"), "UiSizeSmall"],
	])


## The language: two big buttons, each language's name in itself; the one in use stays pressed.
## First on the first page: a player who can't read the one in use finds it at once.
func _build_languages(section: VBoxContainer) -> void:
	var entries := []
	for code: String in Settings.LANGUAGES:
		entries.append([code, Settings.LANGUAGE_NAMES[code], "FrenchButton" if code == "fr" else "EnglishButton"])
	_languages = _choice(section, "", tr("The game's words, at once."), entries)
	for button: Button in _languages.values():
		# A language's own name is never translated.
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		# Never focused first: an accept pressed at once must not switch the language.
		button.set_meta(MenuNav.NOT_FIRST, true)


## A choice of a few: its name and what it does (`title` empty: only that line), then a row of
## toggle buttons sharing the column's width, one per [value, text, node name] of `entries`.
## Returns value -> button (the caller keeps the one in use pressed).
func _choice(section: VBoxContainer, title: String, helper: String, entries: Array) -> Dictionary:
	if title.is_empty():
		section.add_child(UiSkin.label(helper, Fonts.BODY, UiSkin.DIM, true))
	else:
		section.add_child(_words(title, helper))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	section.add_child(row)
	var buttons := {}
	for entry: Array in entries:
		var button := MenuWindow.button(entry[1], Fonts.BODY, 44)
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
		buttons[entry[0]] = button
		MenuWindow.expose(button, entry[2], self)
	return buttons


## A column of a page, scrolling if the screen is short.
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


## A slider: its name and what it does, the slider, its value. `step`: what a key or a gamepad
## moves it by; a finger or the mouse moves it smoothly (by FINE_STEP) and a tap on
## its track jumps there. A finger-sized strip (SLIDER_HEIGHT) that keeps its drags from the
## column's touch scrolling (TouchScroll). `wide`: the slider takes as much room as the words (a
## page of one column, where a short one would sit far from its name).
func _slider(section: VBoxContainer, title: String, helper: String, low: float, high: float, step: float, node_name: String, wide := false) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	section.add_child(row)
	row.add_child(_words(title, helper))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = FINE_STEP
	slider.set_meta(MenuNav.KEY_STEP, step)
	slider.scrollable = false  # (the wheel scrolls the column, never changes a value by surprise)
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, SLIDER_HEIGHT)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if wide:
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value := UiSkin.label("", Fonts.BODY, UiSkin.GOLD)
	value.custom_minimum_size.x = 76  # ("100 %": every slider of a page the same length)
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
