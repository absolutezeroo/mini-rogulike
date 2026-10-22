class_name EndingPanel
extends Control
## The choice at the bottom of the Well (FinaleDef.endings), in the game's skin (RpgDialog).
## Built in code. Its title and what is left when the last form falls, then one card per ending
## side by side: its name, what it means in a line, the button that chooses it. Nothing else
## closes it (Back does nothing): the run ends on a choice. The game is paused while it is open.

## The hero chose `ending`.
signal chosen(ending: EndingDef)

const WIDTH := 980.0
const CARD_WIDTH := 420.0

var _finale: FinaleDef
var _dialog: RpgDialog
var _lore: Label
var _cards: HBoxContainer
var _buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()
	_build()


func open(finale: FinaleDef) -> void:
	_finale = finale
	_dialog.set_title(tr(finale.choice_title), finale.color)
	_lore.text = tr(finale.choice_lore)
	_lore.visible = not finale.choice_lore.is_empty()
	UiParts.clear(_cards)
	_buttons.clear()
	for ending in finale.endings:
		if ending:
			_add_card(ending)
	show()


## The endings' buttons, in order (tests).
func buttons() -> Array[Button]:
	return _buttons


## Chooses the ending at `index` (as its button does).
func choose(index: int) -> void:
	if _finale == null or index < 0 or index >= _finale.endings.size():
		return
	var ending := _finale.endings[index]
	Sfx.play_ui(Sfx.bank.perk_chosen)
	hide()
	chosen.emit(ending)


func _add_card(ending: EndingDef) -> void:
	var index := _finale.endings.find(ending)
	var card: Dictionary = RpgWindow.section(tr(ending.title))
	var box := card.box as Control
	box.custom_minimum_size.x = CARD_WIDTH
	box.size_flags_vertical = Control.SIZE_FILL
	(card.title as Label).add_theme_font_size_override("font_size", Fonts.BODY)
	(card.title as Label).add_theme_color_override("font_color", ending.color)
	_cards.add_child(box)
	var column := card.column as VBoxContainer
	column.add_theme_constant_override("separation", 12)
	var hint := UiParts.text(tr(ending.hint), Fonts.BODY, UiSkin.TEXT, CARD_WIDTH - 40)
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(hint)
	var button := UiParts.button(tr(ending.choice), choose.bind(index), Vector2(CARD_WIDTH - 40, 64), Fonts.BODY)
	button.name = "Ending%d" % index
	column.add_child(button)
	_buttons.append(button)


func _build() -> void:
	_dialog = RpgDialog.new("", WIDTH, 0.86)
	add_child(_dialog)
	_dialog.title_label.name = "Title"
	_lore = UiParts.text("", Fonts.BODY, UiSkin.TEXT, WIDTH - 60)
	_lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lore.name = "Lore"
	_dialog.body.add_child(_lore)
	_cards = HBoxContainer.new()
	_cards.name = "Cards"
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 18)
	_dialog.body.add_child(_cards)
