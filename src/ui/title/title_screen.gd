class_name TitleScreen
extends Control
## First screen: play, visit the shrine (permanent upgrades bought with souls), see your records.
## No class to pick: you become who you want with what you find in the dungeon.

const GAME_SCENE := "res://src/game/game.tscn"

@export var content: ContentDB

@onready var _records: Label = %Records
@onready var _shrine: ShrinePanel = %ShrinePanel
@onready var _hero: AnimatedSprite2D = %Hero


func _ready() -> void:
	get_tree().paused = false
	if content.sounds:
		Sfx.bank = content.sounds
	var first_act := content.dungeon.acts[0] if not content.dungeon.acts.is_empty() else null
	if first_act and first_act.theme:
		Sfx.play_music(first_act.theme.music)
	_hero.sprite_frames = content.player.frames
	_hero.play(&"idle_down")
	var spot: Control = %HeroSpot
	spot.resized.connect(func() -> void: _hero.position.x = spot.size.x * 0.5)
	_build_boss_row()
	%PlayButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		(%DifficultyPanel as DifficultyPanel).open(content.difficulties))
	(%DifficultyPanel as DifficultyPanel).chosen.connect(func(_difficulty: DifficultyDef) -> void: play())
	%ShrineButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		_shrine.open(content.upgrades))
	Profile.changed.connect(_refresh)
	_refresh()
	(%PlayButton as Button).grab_focus()


func play() -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	get_tree().change_scene_to_file(GAME_SCENE)


## The goal of a run: one boss per act.
func _build_boss_row() -> void:
	var row: HBoxContainer = %Bosses
	for act in content.dungeon.acts:
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		var portrait := TextureRect.new()
		portrait.texture = act.boss.portrait if act.boss else null
		portrait.custom_minimum_size = Vector2(76, 76)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		column.add_child(portrait)
		var label := Label.new()
		label.text = "%s\n%s" % [act.subtitle, act.title]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		column.add_child(label)
		row.add_child(column)


func _refresh() -> void:
	var difficulty := content.get_difficulty(Profile.difficulty)
	_records.text = "Souls: %d     Runs: %d     Victories: %d     Deepest floor: %d     Difficulty: %s" % [
		Profile.souls, Profile.runs, Profile.victories, Profile.best_depth,
		difficulty.display_name if difficulty else "Normal"]
