class_name Hud
extends CanvasLayer
## In-game overlay: bars, stats, messages and the touch controls.

signal inventory_requested
signal pause_requested
## The DBG button (debug builds only).
signal debug_requested

const BAG_ICON: Texture2D = preload("res://assets/ui/icons/bag.png")

var _player: Player
var _world: World
var _banner_tween: Tween
var _souls_tween: Tween
var _seal_tween: Tween
var _toasts: Array[String] = []
var _toast_busy := false

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
		toast("Achievement: %s  (+%d souls)" % [achievement.display_name, achievement.reward_souls]))
	Events.quest_completed.connect(func(quest: Dictionary) -> void:
		toast("%s quest done: %s  (+%d souls)" % ["Daily" if (quest.def as QuestDef).period == QuestDef.Period.DAILY else "Weekly", QuestBoard.text(quest), quest.reward]))
	_apply_settings()
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


## Size of the touch controls (Options). They grow from their corner of the screen.
func _apply_settings() -> void:
	(%Controls as Control).scale = Vector2.ONE * Settings.controls_scale
	(%Joystick as TouchJoystick).max_distance = TouchJoystick.BASE_DISTANCE * Settings.controls_scale


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


func _refresh_seal() -> void:
	var seal := _world.seal
	_seal_label.visible = seal.needed > 0 or _world.arena == null
	if seal.is_sealed():
		_seal_label.text = "Seal  %d / %d" % [seal.kills, seal.needed]
		_seal_label.add_theme_color_override("font_color", Palette.SEAL)
	else:
		_seal_label.text = "Stairs open"
		_seal_label.add_theme_color_override("font_color", Palette.GOLD)


func _on_seal_broken() -> void:
	show_banner("The stairs are open", Palette.GOLD)
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
	_player = player
	_player.health_changed.connect(_on_health_changed)
	_vignette.reset()
	_player.health_changed.connect(_vignette.on_health_changed)
	_player.stats_changed.connect(_refresh_info)
	_player.xp_changed.connect(_on_xp_changed)
	_player.equipment.changed.connect(_refresh_info)
	_player.skills_changed.connect(_refresh_skill_buttons)
	_player.gold_changed.connect(_on_gold_changed)
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
			button.label = skill.short_label
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
	var label := ("Freezing!" if is_cold else "Burning up!") if temperature.is_extreme() else ("Cold" if is_cold else "Hot")
	_temp_bar.fill_color = BodyTemperature.COLD_COLOR if is_cold else BodyTemperature.HOT_COLOR
	if temperature.is_extreme() and int(Time.get_ticks_msec() / 250) % 2 == 0:
		_temp_bar.fill_color = _temp_bar.fill_color.lightened(0.4)
	_temp_bar.set_values(absf(temperature.value), BodyTemperature.LIMIT, label)


func _on_health_changed(current: int, maximum: int) -> void:
	_hp_bar.set_values(current, maximum, "%d / %d" % [current, maximum])


func _on_xp_changed(xp: int, needed: int, level: int) -> void:
	_xp_bar.set_values(xp, needed, "Lv %d" % level)


func _refresh_info() -> void:
	if _player == null:
		return
	var stats := _player.get_stats()
	var weapon := _player.get_weapon()
	var difficulty := _player.world.difficulty if _player.world else null
	_info_label.text = "%sDepth %d   ATK %d   DEF %d   %s" % [
		(difficulty.display_name + "   ") if difficulty else "",
		_player.world.depth if _player.world else 1,
		_player.get_power(),
		stats.defense,
		weapon.display_name if weapon else "Bare hands",
	]


func _on_gold_changed(gold: int) -> void:
	(%GoldLabel as Label).text = "Gold %d" % gold


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
	_souls_label.text = "Souls %d" % count
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


func _on_depth_changed(depth: int) -> void:
	_refresh_info()
	show_banner("Depth %d" % depth)
