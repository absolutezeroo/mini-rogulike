class_name DifficultyPanel
extends Control
## "Choose a difficulty", shown when pressing Play, in the game's skin (MenuWindow): one card per
## difficulty with what changes in plain words (DifficultyCard); locked ones say how to unlock
## them. Once Nightmare has been won, its ascension level (+1, +2...) is picked below the cards,
## with every twist up to that level and the next one to win.
## Built in code; its controls are reachable as %DifficultyCards, %AscensionRow, %AscensionLevel,
## %AscensionMinus, %AscensionPlus, %AscensionText and %BackButton from the title screen.

signal chosen(difficulty: DifficultyDef)

const CARD_SCENE: PackedScene = preload("res://src/ui/title/difficulty_card.tscn")

var _ascensions: Array[AscensionDef] = []
var _difficulties: Array[DifficultyDef] = []

var _window: MenuWindow
var _cards: HBoxContainer
var _ascension_box: Control
var _ascension_row: HBoxContainer
var _ascension_level: Label
var _ascension_souls: Label
var _ascension_text: Label
var _minus: Button
var _plus: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()
	_window.close_button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		hide())
	_minus.pressed.connect(func() -> void: _change_ascension(-1))
	_plus.pressed.connect(func() -> void: _change_ascension(1))


func open(difficulties: Array[DifficultyDef], ascensions: Array[AscensionDef] = []) -> void:
	_difficulties = difficulties
	_ascensions = ascensions
	_refresh_ascension()
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var reference: DifficultyDef = null
	for def in difficulties:
		if def.id == &"normal":
			reference = def
	var focus: Control = null
	for def in difficulties:
		var card := CARD_SCENE.instantiate() as DifficultyCard
		_cards.add_child(card)
		card.show_difficulty(def, Profile.is_unlocked(def), def.id == Profile.difficulty, reference)
		card.pressed.connect(func() -> void: choose(def))
		if def.id == Profile.difficulty and not card.disabled:
			focus = card
	show()
	if focus:
		focus.grab_focus()  # keyboard and gamepad


func choose(def: DifficultyDef) -> void:
	if not Profile.is_unlocked(def):
		return
	Profile.select_difficulty(def)
	hide()
	chosen.emit(def)


func _change_ascension(step: int) -> void:
	Sfx.play_ui(Sfx.bank.ui_click)
	Profile.select_ascension(Profile.ascension + step)
	_refresh_ascension()


## Shown once Nightmare was won: the level, the souls it pays, every twist up to it, the next.
func _refresh_ascension() -> void:
	var open_levels := mini(Profile.ascension_unlocked, _ascensions.size())
	_ascension_box.visible = open_levels > 0
	_ascension_row.visible = open_levels > 0
	_ascension_text.visible = open_levels > 0
	if open_levels <= 0:
		return
	var level := mini(Profile.ascension, open_levels)
	_ascension_level.text = "+%d" % level
	_minus.disabled = level <= 0
	_plus.disabled = level >= open_levels
	var nightmare: DifficultyDef = null
	for def in _difficulties:
		if def.has_ascensions:
			nightmare = def
	if nightmare:
		var climbed := AscensionDef.apply_levels(nightmare, _ascensions, level)
		_ascension_souls.text = tr("Souls earned x%s") % DifficultyCard.number(climbed.souls, 1)
	_ascension_text.text = "\n".join(ascension_lines(_ascensions, level, open_levels))


## The twists of levels 1..`level` (each adds to the ones before), then the next one.
static func ascension_lines(ascensions: Array[AscensionDef], level: int, open_levels: int) -> PackedStringArray:
	var lines := PackedStringArray()
	if level <= 0:
		lines.append(TranslationServer.tr("+0: Nightmare as it is. Each level adds one twist on top of the ones before, and 10% more souls."))
	for i in level:
		lines.append(TranslationServer.tr("+%d  %s: %s") % [i + 1, TranslationServer.tr(ascensions[i].title), TranslationServer.tr(ascensions[i].description)])
	if level < ascensions.size():
		var next := ascensions[level]
		var title := TranslationServer.tr(next.title)
		var description := TranslationServer.tr(next.description)
		if level < open_levels:
			lines.append(TranslationServer.tr("Next, +%d  %s: %s") % [level + 1, title, description])
		else:
			lines.append(TranslationServer.tr("Win Nightmare +%d to open +%d  %s: %s") % [level, level + 1, title, description])
	return lines


# --- Building -----------------------------------------------------------------------

func _build() -> void:
	_window = MenuWindow.new(tr("Choose a difficulty"))
	add_child(_window)
	var scene_owner: Node = owner if owner != null else self
	_window.close_button.text = tr("Back")
	MenuWindow.expose(_window.close_button, "BackButton", scene_owner)
	var intro := UiSkin.label(tr("Tap one to start the run. Harder ones pay more souls."), 16, UiSkin.TEXT, true)
	intro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_window.header_left.add_child(intro)
	_cards = HBoxContainer.new()
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards.add_theme_constant_override("separation", 12)
	_window.body.add_child(_cards)
	MenuWindow.expose(_cards, "DifficultyCards", scene_owner)

	# Nightmare's ascension, on a dark strip: the level [-] +2 [+] and its souls on the left,
	# the twists on the right.
	_ascension_box = MenuWindow.strip()
	_window.body.add_child(_ascension_box)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 18)
	_ascension_box.add_child(line)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	line.add_child(left)
	left.add_child(UiSkin.label(tr("Nightmare ascension"), 18, Color(0.85, 0.6, 1.0)))
	_ascension_row = HBoxContainer.new()
	_ascension_row.add_theme_constant_override("separation", 8)
	left.add_child(_ascension_row)
	MenuWindow.expose(_ascension_row, "AscensionRow", scene_owner)
	_minus = MenuWindow.button("-", 24, 46)
	_minus.custom_minimum_size.x = 52
	_ascension_row.add_child(_minus)
	MenuWindow.expose(_minus, "AscensionMinus", scene_owner)
	_ascension_level = UiSkin.label("+0", 26, Color(0.85, 0.6, 1.0))
	_ascension_level.custom_minimum_size.x = 56
	_ascension_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ascension_row.add_child(_ascension_level)
	MenuWindow.expose(_ascension_level, "AscensionLevel", scene_owner)
	_plus = MenuWindow.button("+", 24, 46)
	_plus.custom_minimum_size.x = 52
	_ascension_row.add_child(_plus)
	MenuWindow.expose(_plus, "AscensionPlus", scene_owner)
	_ascension_souls = UiSkin.label("", 17, MenuWindow.SOULS)
	_ascension_souls.custom_minimum_size.x = 180
	_ascension_souls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_ascension_row.add_child(_ascension_souls)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 72
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	line.add_child(scroll)
	_ascension_text = UiSkin.label("", 15, UiSkin.TEXT, true)
	scroll.add_child(_ascension_text)
	MenuWindow.expose(_ascension_text, "AscensionText", scene_owner)
