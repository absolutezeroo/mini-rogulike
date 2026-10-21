class_name Hud
extends CanvasLayer
## In-game overlay: bars, stats, messages and the touch controls.

signal inventory_requested
signal pause_requested
## The DBG button (debug builds only).
signal debug_requested
## The perk button: the player wants to make the waiting perk choices.
signal offers_requested

const BAG_ICON: Texture2D = preload("res://assets/ui/icons/bag.png")

var _player: Player
var _world: World
var _banner_tween: Tween
var _souls_tween: Tween
var _seal_tween: Tween
var _toasts: Array[String] = []
var _split_tween: Tween
## The run time's text on screen (rebuilt only when it changes).
var _time_text := ""
var _toast_busy := false
## The trial of the Threshold's counters (see bind_threshold()).
var _threshold_hud: ThresholdHud
## The floor's widgets put away during the trial, to show again after (the boss bar, the map).
var _hidden_for_trial: Array[Control] = []

@onready var _hp_bar: StatBar = %HpBar
@onready var _xp_bar: StatBar = %XpBar
## Shown while the hero is cold or hot (BodyTemperature).
@onready var _temp_bar: StatBar = %TempBar
## Frost (or a burning haze) creeping in from the screen's edges.
@onready var _temp_overlay: ColorRect = %TemperatureOverlay
@onready var _info_label: Label = %InfoLabel
@onready var _souls_label: Label = %SoulsLabel
## Under the minimap: kills the stairs' seal still wants, then "Stairs open".
@onready var _seal_label: Label = %SealLabel
@onready var _depth_banner: Label = %DepthBanner
@onready var _message_log: MessageLog = %MessageLog
@onready var _attack_button: ActionButton = %AttackButton
## One button per belt slot (potions, bombs...); empty slots are hidden.
@onready var _belt_buttons: Array[ActionButton] = [%QuickItemButton, %Belt2Button, %Belt3Button]
@onready var _skill_buttons: Array[ActionButton] = [%Skill1Button, %Skill2Button, %Skill3Button, %Skill4Button]
@onready var _vignette: DamageVignette = %DamageVignette
@onready var _perk_tray: PerkTray = %PerkTray
@onready var _boss_bar: BossBar = %BossBar
@onready var _minimap: Minimap = %Minimap
@onready var _full_map: Minimap = %FullMap
## Under the map during a pact's fight: its rule and how it holds (built in code).
var pact_line := PactLine.new()
## Loot left on the ground (auto loot, a full bag) with its Take button (built in code).
var loot_prompt := LootPrompt.new()
## Left of the map while perk choices wait: their count, a glow (built in code).
var offers_button := OffersButton.new()
## Above the skills while the hero stands by something to use (built in code).
var interact_button := InteractButton.new()
## The perk choices the button counts (bind_offers()).
var _offers: OfferQueue
## During the trial of the Threshold the perk and Interact buttons are put away.
var _in_trial := false


func _ready() -> void:
	%BagButton.pressed.connect(func() -> void: inventory_requested.emit())
	%BagButton.icon = BAG_ICON
	%PauseButton.pressed.connect(func() -> void: pause_requested.emit())
	if DebugPanel.is_available():
		_add_debug_button()
	# Tap the minimap for the whole floor, tap again to close it.
	_minimap.tapped.connect(func() -> void: _full_map.visible = not _full_map.visible)
	_full_map.tapped.connect(func() -> void: _full_map.hide())
	Settings.changed.connect(_apply_settings)
	Events.achievement_unlocked.connect(func(achievement: AchievementDef) -> void:
		toast(tr("Achievement: %s  (+%d souls)") % [tr(achievement.display_name), achievement.reward_souls]))
	Events.bestiary_rank_reached.connect(func(monster: MonsterDef, rank: int, souls: int) -> void:
		var rules := _player.world.bestiary_rules() if _player and _player.world else null
		toast(tr("Bestiary: %s, %s  (+%d souls)") % [tr(monster.display_name), Bestiary.rank_name(rank, rules) if rules else str(rank), souls]))
	Events.hunt_challenge_done.connect(func(monster: MonsterDef, challenge: HuntChallenge) -> void:
		toast(tr("Challenge done: %s  (+%d souls)") % [challenge.describe(monster), challenge.souls]))
	Events.quest_completed.connect(func(quest: Dictionary) -> void:
		var done := tr("Daily quest done: %s  (+%d souls)") if (quest.def as QuestDef).period == QuestDef.Period.DAILY else tr("Weekly quest done: %s  (+%d souls)")
		toast(done % [QuestBoard.text(quest), quest.reward]))
	_apply_settings()
	pact_line.hud = self
	add_child(pact_line)
	loot_prompt.hud = self
	add_child(loot_prompt)
	_add_offers_button()
	_add_interact_button()
	Events.depth_changed.connect(_on_depth_changed)
	_depth_banner.modulate.a = 0.0


## Dev builds: a DBG button next to the pause button.
func _add_debug_button() -> void:
	var pause := %PauseButton as Button
	var button := Button.new()
	button.name = "DebugButton"
	button.text = "DBG"
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.offset_left = pause.offset_left - 80.0
	button.offset_right = pause.offset_left - 8.0
	button.offset_top = pause.offset_top
	button.offset_bottom = pause.offset_bottom
	button.modulate = Color(1, 1, 1, 0.75)
	button.pressed.connect(func() -> void: debug_requested.emit())
	add_child(button)


## The perk button, left of the minimap, under the pause button: in thumb's reach on the right,
## away from the joystick and the fight's buttons.
func _add_offers_button() -> void:
	offers_button.name = "OffersButton"
	offers_button.anchor_left = 1.0
	offers_button.anchor_right = 1.0
	offers_button.offset_left = -326.0
	offers_button.offset_right = -326.0 + OffersButton.SIZE
	offers_button.offset_top = 92.0
	offers_button.offset_bottom = 92.0 + OffersButton.SIZE
	offers_button.pressed.connect(func() -> void: offers_requested.emit())
	add_child(offers_button)
	move_child(offers_button, _minimap.get_index())  # under the full map
	offers_button.owner = self  # the tutorial points at it (hint_target())
	offers_button.unique_name_in_owner = true


## The Interact button, above the skills (left of the third one): the thumb on the attack button
## reaches it, and it never covers a skill.
func _add_interact_button() -> void:
	interact_button.name = "InteractButton"
	interact_button.position = Vector2(-262, -372)
	%Controls.add_child(interact_button)
	interact_button.owner = self
	interact_button.unique_name_in_owner = true


## The perk choices waiting: the button shows how many.
func bind_offers(offers: OfferQueue) -> void:
	_offers = offers
	offers.changed.connect(_refresh_offers)
	_refresh_offers()


func _refresh_offers() -> void:
	offers_button.count = 0 if _offers == null or _in_trial else _offers.size()


## What the Interact button would use: shown by it, hidden when nothing is in reach.
func bind_interactor(interactor: Interactor) -> void:
	interactor.focus_changed.connect(func(target: Interactable) -> void:
		interact_button.show_for(null if _in_trial else target))


## Size of the touch controls (Options). They grow from their corner of the screen.
func _apply_settings() -> void:
	(%Controls as Control).scale = Vector2.ONE * Settings.controls_scale
	(%Joystick as TouchJoystick).max_distance = TouchJoystick.BASE_DISTANCE * Settings.controls_scale
	(%Joystick as TouchJoystick).fixed = Settings.fixed_joystick


## The floor shown on the minimap.
func bind_world(world: World) -> void:
	_minimap.bind_world(world)
	_full_map.bind_world(world)
	if _world == world:
		return
	_world = world
	world.seal.changed.connect(_refresh_seal)
	world.seal.broken.connect(_on_seal_broken)
	_refresh_seal()


## The trial of the Threshold: its name, countdown and kills while it is on; the floor's map,
## seal and boss bar (and the bag, closed in there) put away until the hero is back.
func bind_threshold(threshold: Threshold) -> void:
	_threshold_hud = ThresholdHud.new()
	_threshold_hud.name = "ThresholdHud"
	_threshold_hud.threshold = threshold
	add_child(_threshold_hud)
	move_child(_threshold_hud, (%Toast as Control).get_index())  # under the toasts and banners
	# The tutorial points at the counters by name (hint_target()).
	_threshold_hud.counters().owner = self
	_threshold_hud.counters().unique_name_in_owner = true
	threshold.opened.connect(func(trial: ThresholdDef, needed: int, _seconds: float) -> void:
		_show_floor_widgets(false)
		_threshold_hud.open(trial, needed))
	threshold.progressed.connect(_threshold_hud.set_progress)
	threshold.ended.connect(func(won: bool) -> void:
		_threshold_hud.close()
		if won:
			toast(tr("You come back from the Threshold."))
		else:
			show_banner(tr("The knell has tolled"), Palette.DANGER))
	threshold.closed.connect(func(_won: bool) -> void:
		_threshold_hud.close()
		_show_floor_widgets(true))


func _show_floor_widgets(shown: bool) -> void:
	_in_trial = not shown
	_refresh_offers()
	if not shown:
		interact_button.show_for(null)
		_full_map.hide()
		_hidden_for_trial.clear()
		for widget: Control in [_minimap, _seal_label, _boss_bar, %BagButton, %SplitLabel]:
			if widget.visible:
				_hidden_for_trial.append(widget)
				widget.hide()
		return
	for widget in _hidden_for_trial:
		if is_instance_valid(widget):
			widget.show()
	_hidden_for_trial.clear()
	if _world:
		_refresh_seal()


func _refresh_seal() -> void:
	var seal := _world.seal
	_seal_label.visible = seal.needed > 0 or _world.arena == null
	if seal.is_sealed():
		_seal_label.text = tr("Seal  %d / %d") % [seal.kills, seal.needed]
		_seal_label.add_theme_color_override("font_color", Palette.SEAL)
	else:
		_seal_label.text = tr("Stairs open")
		_seal_label.add_theme_color_override("font_color", Palette.GOLD)


func _on_seal_broken() -> void:
	show_banner(tr("The stairs are open"), Palette.GOLD)
	if _seal_tween:
		_seal_tween.kill()
	_seal_label.pivot_offset = _seal_label.size * Vector2(1.0, 0.5)
	_seal_label.scale = Vector2.ONE * 1.4
	_seal_tween = create_tween()
	_seal_tween.tween_property(_seal_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)


func bind_player(player: Player) -> void:
	if _player:
		_player.health_changed.disconnect(_on_health_changed)
		_player.health_changed.disconnect(_vignette.on_health_changed)
		_player.stats_changed.disconnect(_refresh_info)
		_player.xp_changed.disconnect(_on_xp_changed)
		_player.equipment.changed.disconnect(_refresh_info)
		_player.skills_changed.disconnect(_refresh_skill_buttons)
		_player.gold_changed.disconnect(_on_gold_changed)
		_player.perks.synergy_awakened.disconnect(_on_synergy_awakened)
	_player = player
	loot_prompt.player = player
	_player.health_changed.connect(_on_health_changed)
	_vignette.reset()
	_player.health_changed.connect(_vignette.on_health_changed)
	_player.stats_changed.connect(_refresh_info)
	_player.xp_changed.connect(_on_xp_changed)
	_player.equipment.changed.connect(_refresh_info)
	_player.skills_changed.connect(_refresh_skill_buttons)
	_player.gold_changed.connect(_on_gold_changed)
	_player.perks.synergy_awakened.connect(_on_synergy_awakened)
	_on_gold_changed(player.gold)
	_message_log.clear()
	_perk_tray.bind(player.perks)
	_boss_bar.hide_now()
	_full_map.hide()

	_refresh_skill_buttons()
	_on_health_changed(player.hp, player.get_max_hp())
	_on_xp_changed(player.xp, player.xp_to_next_level(), player.level)
	_refresh_info()


func _process(_delta: float) -> void:
	if _player == null:
		return
	_refresh_temperature()
	for i in _skill_buttons.size():
		if _skill_buttons[i].visible:
			_skill_buttons[i].cooldown_ratio = _player.skills.cooldown_ratio(i)
	for i in _belt_buttons.size():
		var button := _belt_buttons[i]
		var item := _player.belt.item_at(i)
		button.visible = item != null
		if item:
			button.icon = item.icon
			button.icon_tint = item.icon_tint
			button.label = item.glyph
			button.color = item.color
			button.counter = _player.belt.count_at(i)
	var weapon := _player.get_weapon()
	_attack_button.icon = weapon.icon if weapon else null
	_attack_button.icon_tint = weapon.icon_tint if weapon else Color.WHITE
	_attack_button.label = weapon.glyph if weapon else "-"


## One button per skill slot; empty slots (no weapon skill, no spell learned) are hidden.
func _refresh_skill_buttons() -> void:
	for i in _skill_buttons.size():
		var button := _skill_buttons[i]
		var skill: SkillDef = _player.skills.skills[i] if i < _player.skills.skills.size() else null
		button.visible = skill != null
		if skill:
			button.label = tr(skill.short_label)
			button.icon = skill.icon
			button.color = skill.color


func _refresh_temperature() -> void:
	var temperature := _player.temperature
	var shown := absf(temperature.value) >= 1.0
	_temp_bar.visible = shown
	var cold := clampf((-temperature.value - 15.0) / 85.0, 0.0, 1.0)
	var heat := clampf((temperature.value - 15.0) / 85.0, 0.0, 1.0)
	_temp_overlay.visible = cold > 0.0 or heat > 0.0
	if _temp_overlay.visible:
		var look := _temp_overlay.material as ShaderMaterial
		look.set_shader_parameter("cold", cold)
		look.set_shader_parameter("heat", heat)
		look.set_shader_parameter("aspect", _temp_overlay.size / _temp_overlay.size.y * 9.0)
	if not shown:
		return
	var is_cold := temperature.value < 0.0
	var label := (tr("Freezing!") if is_cold else tr("Burning up!")) if temperature.is_extreme() else (tr("Cold") if is_cold else tr("Hot"))
	_temp_bar.fill_color = BodyTemperature.COLD_COLOR if is_cold else BodyTemperature.HOT_COLOR
	if temperature.is_extreme() and int(Time.get_ticks_msec() / 250) % 2 == 0:
		_temp_bar.fill_color = _temp_bar.fill_color.lightened(0.4)
	_temp_bar.set_values(absf(temperature.value), BodyTemperature.LIMIT, label)


func _on_health_changed(current: int, maximum: int) -> void:
	_hp_bar.set_values(current, maximum, "%d / %d" % [current, maximum])


func _on_xp_changed(xp: int, needed: int, level: int) -> void:
	_xp_bar.set_values(xp, needed, tr("Lv %d") % level)


func _refresh_info() -> void:
	if _player == null:
		return
	var stats := _player.get_stats()
	var weapon := _player.get_weapon()
	var difficulty := _player.world.difficulty if _player.world else null
	_info_label.text = (tr(difficulty.display_name) + "   " if difficulty else "") + tr("Depth %d   Damage %d   Armor %d   %s") % [
		_player.world.depth if _player.world else 1,
		_player.get_power(),
		stats.defense,
		tr(weapon.display_name) if weapon else tr("Bare hands"),
	]


func _on_gold_changed(gold: int) -> void:
	(%GoldLabel as Label).text = tr("Gold %d") % gold


## Three of a family: its name across the screen, what it does in the log.
func _on_synergy_awakened(synergy: SynergyDef) -> void:
	show_banner(tr("%s awakens") % tr(synergy.display_name), synergy.color)
	Events.log_message(tr("%s awakens: %s") % [tr(synergy.display_name), tr(synergy.description)], synergy.color)


## A short note at the top of the screen (achievements...). Several wait their turn.
func toast(text: String) -> void:
	_toasts.append(text)
	if not _toast_busy:
		_next_toast()


func _next_toast() -> void:
	if _toasts.is_empty():
		_toast_busy = false
		return
	_toast_busy = true
	(%ToastLabel as Label).text = _toasts.pop_front()
	Sfx.play_ui(Sfx.bank.level_up, -6.0)
	var toast_panel: Control = %Toast
	var tween := create_tween()
	tween.tween_property(toast_panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(2.4)
	tween.tween_property(toast_panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_next_toast)


## Souls gathered this run (what the shrine will get). `pulse` when a new one arrives.
func set_souls(count: int, pulse: bool = false) -> void:
	_souls_label.text = tr("Souls %d") % count
	if not pulse:
		return
	if _souls_tween:
		_souls_tween.kill()
	_souls_label.pivot_offset = _souls_label.size * Vector2(0.0, 0.5)
	_souls_label.scale = Vector2.ONE * 1.25
	_souls_tween = create_tween()
	_souls_tween.tween_property(_souls_label, "scale", Vector2.ONE, 0.2)


## Big centered text that fades out (floor names, boss names...).
func show_banner(text: String, color: Color = Color(1, 0.82, 0.4)) -> void:
	_depth_banner.text = text
	_depth_banner.add_theme_color_override("font_color", color)
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_depth_banner.modulate.a = 1.0
	_banner_tween.tween_interval(1.4)
	_banner_tween.tween_property(_depth_banner, "modulate:a", 0.0, 0.6)


## The run's time under the map (Settings.run_timer). Gold once the run is won (that time stays).
func show_run_time(seconds: float, finished: bool) -> void:
	var label := %TimerLabel as Label
	label.visible = Settings.run_timer
	if not label.visible:
		return
	var text := TimeText.of(seconds, 2 if finished else 1)
	if text == _time_text:
		return
	_time_text = text
	label.text = text
	label.add_theme_color_override("font_color", Palette.GOLD if finished else Color(1, 1, 1, 0.85))


## A floor done: its time, and how far ahead (green) or behind (red) the record run it is.
## `ahead`: seconds against the record's split (NAN: no record to race).
func show_split(depth: int, seconds: float, ahead: float) -> void:
	if not Settings.run_timer:
		return
	var label := %SplitLabel as Label
	var text := tr("Floor %d  %s") % [depth, TimeText.of(seconds, 1)]
	var color := Color(1, 1, 1, 0.85)
	if not is_nan(ahead):
		text += "  " + TimeText.delta(ahead)
		color = Palette.HEAL if ahead <= 0.0 else Palette.DANGER
	label.text = text
	label.add_theme_color_override("font_color", color)
	if _split_tween:
		_split_tween.kill()
	label.modulate.a = 1.0
	_split_tween = create_tween()
	_split_tween.tween_interval(4.0)
	_split_tween.tween_property(label, "modulate:a", 0.0, 0.6)


func split_text() -> String:
	return (%SplitLabel as Label).text if (%SplitLabel as Label).modulate.a > 0.0 else ""


## A big text is on screen (hints wait for it to go).
func is_banner_showing() -> bool:
	return _depth_banner.modulate.a > 0.05 or (_threshold_hud != null and _threshold_hud.is_card_showing())


func is_boss_bar_showing() -> bool:
	return _boss_bar.visible


## Where a control of the HUD is on screen (unique name: "AttackButton", "Joystick",
## "SealLabel"...), for the tutorial to point at. Empty if it isn't there or is hidden.
func hint_target(control_name: StringName) -> Rect2:
	var node := get_node_or_null("%" + String(control_name))
	if node == null or not node.is_visible_in_tree():
		return Rect2()
	if node is TouchJoystick:
		var stick := node as TouchJoystick
		var reach := stick.max_distance
		return Rect2(stick.get_global_rect().position + stick.home() - Vector2.ONE * reach, Vector2.ONE * reach * 2.0)
	if node is ActionButton:
		var button := node as ActionButton
		var radius := button.radius * button.get_global_transform().get_scale().x
		return Rect2(button.global_position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	if node is Control:
		return (node as Control).get_global_rect()
	return Rect2()


func _on_depth_changed(depth: int) -> void:
	_refresh_info()
	show_banner(tr("Depth %d") % depth)
