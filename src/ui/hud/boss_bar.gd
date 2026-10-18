class_name BossBar
extends Control
## Big health bar with the boss' name and portrait, shown during boss fights.

var _boss: Monster

@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %BossName
@onready var _bar: StatBar = %BossHp


func _ready() -> void:
	hide()
	Events.boss_started.connect(show_boss)
	Events.boss_defeated.connect(func(_boss_monster: Monster) -> void: _fade_out())


func show_boss(boss: Monster) -> void:
	if _boss and is_instance_valid(_boss) and _boss.health_changed.is_connected(_on_health_changed):
		_boss.health_changed.disconnect(_on_health_changed)
	_boss = boss
	_boss.health_changed.connect(_on_health_changed)
	var def := boss.def as BossDef
	_name.text = boss.display_name
	_portrait.texture = def.portrait if def else boss.def.icon
	_on_health_changed(boss.hp, boss.get_max_hp())
	modulate.a = 0.0
	show()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.4)


func hide_now() -> void:
	_boss = null
	hide()


func _on_health_changed(current: int, maximum: int) -> void:
	_bar.set_values(current, maximum, "")


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(hide_now)
