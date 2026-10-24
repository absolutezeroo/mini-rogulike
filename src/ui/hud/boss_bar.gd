class_name BossBar
extends Control
## Big health bar with the boss' name and portrait, shown during boss fights. Notches mark
## where its next phases start (BossDef.phases).

var _boss: Monster

@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %BossName
@onready var _bar: StatBar = %BossHp


func _ready() -> void:
	hide()
	_bar.draw.connect(_draw_phase_notches)
	Events.boss_started.connect(show_boss)
	Events.boss_defeated.connect(func(_boss_monster: Monster) -> void: _fade_out())


func show_boss(boss: Monster) -> void:
	if _boss and is_instance_valid(_boss) and _boss.health_changed.is_connected(_on_health_changed):
		_boss.health_changed.disconnect(_on_health_changed)
	_boss = boss
	_boss.health_changed.connect(_on_health_changed)
	var def := boss.def as BossDef
	_name.text = tr(boss.display_name)
	var monster := boss as Monster
	if monster and monster.rank:
		# A rare boss: its rank's color, its affixes after its name.
		_name.add_theme_color_override("font_color", monster.rank_color())
		if not monster.affixes.is_empty():
			_name.text += "  (%s)" % monster.affix_names()
	else:
		_name.remove_theme_color_override("font_color")
	if def and def.title_on_bar and not def.title.is_empty():
		_name.text = tr("{name}  ({title})").format({ "name": _name.text, "title": tr(def.title) })
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
	_bar.queue_redraw()


## A notch on the bar at each phase's HP ratio: bright while still ahead, dim once passed.
func _draw_phase_notches() -> void:
	var def := _boss.def as BossDef if _boss and is_instance_valid(_boss) else null
	if def == null:
		return
	var ratio := float(_boss.hp) / maxf(_boss.get_max_hp(), 1.0)
	for phase in def.phases:
		var x := roundf(_bar.size.x * phase.hp_ratio)
		var ahead := ratio > phase.hp_ratio
		_bar.draw_rect(Rect2(x - 2.0, -3.0, 4.0, _bar.size.y + 6.0), Palette.INK)
		_bar.draw_rect(Rect2(x - 1.0, -2.0, 2.0, _bar.size.y + 4.0), Palette.GOLD if ahead else Color(1, 1, 1, 0.35))


func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(hide_now)
