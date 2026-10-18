class_name Hud
extends CanvasLayer
## In-game overlay: bars, stats, messages and the touch controls.

signal inventory_requested

const BAG_ICON: Texture2D = preload("res://assets/ui/icons/bag.png")

var _player: Player
var _banner_tween: Tween
var _souls_tween: Tween

@onready var _hp_bar: StatBar = %HpBar
@onready var _xp_bar: StatBar = %XpBar
@onready var _info_label: Label = %InfoLabel
@onready var _souls_label: Label = %SoulsLabel
@onready var _depth_banner: Label = %DepthBanner
@onready var _message_log: MessageLog = %MessageLog
@onready var _attack_button: ActionButton = %AttackButton
@onready var _quick_item_button: ActionButton = %QuickItemButton
@onready var _skill_buttons: Array[ActionButton] = [%Skill1Button, %Skill2Button, %Skill3Button, %Skill4Button]
@onready var _vignette: DamageVignette = %DamageVignette
@onready var _perk_tray: PerkTray = %PerkTray
@onready var _boss_bar: BossBar = %BossBar


func _ready() -> void:
	%BagButton.pressed.connect(func() -> void: inventory_requested.emit())
	%BagButton.icon = BAG_ICON
	Events.depth_changed.connect(_on_depth_changed)
	_depth_banner.modulate.a = 0.0


func bind_player(player: Player) -> void:
	if _player:
		_player.health_changed.disconnect(_on_health_changed)
		_player.health_changed.disconnect(_vignette.on_health_changed)
		_player.stats_changed.disconnect(_refresh_info)
		_player.xp_changed.disconnect(_on_xp_changed)
		_player.equipment.changed.disconnect(_refresh_info)
		_player.skills_changed.disconnect(_refresh_skill_buttons)
	_player = player
	_player.health_changed.connect(_on_health_changed)
	_vignette.reset()
	_player.health_changed.connect(_vignette.on_health_changed)
	_player.stats_changed.connect(_refresh_info)
	_player.xp_changed.connect(_on_xp_changed)
	_player.equipment.changed.connect(_refresh_info)
	_player.skills_changed.connect(_refresh_skill_buttons)
	_message_log.clear()
	_perk_tray.bind(player.perks)
	_boss_bar.hide_now()

	_refresh_skill_buttons()
	_on_health_changed(player.hp, player.get_max_hp())
	_on_xp_changed(player.xp, player.xp_to_next_level(), player.level)
	_refresh_info()


func _process(_delta: float) -> void:
	if _player == null:
		return
	for i in _skill_buttons.size():
		if _skill_buttons[i].visible:
			_skill_buttons[i].cooldown_ratio = _player.skills.cooldown_ratio(i)
	var potion := _player.inventory.first_consumable()
	_quick_item_button.visible = potion != null
	if potion:
		_quick_item_button.icon = potion.icon
		_quick_item_button.icon_tint = potion.icon_tint
		_quick_item_button.label = potion.glyph
		_quick_item_button.color = potion.color
		_quick_item_button.counter = _player.inventory.count_of(potion)
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
