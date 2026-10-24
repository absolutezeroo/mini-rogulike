class_name DismantleWorseDialog
extends RpgDialog
## "Dismantle the worse", asked before anything breaks: how many pieces and for how much gold,
## their slots, what is never touched, then Dismantle (+gold) or Keep them. Over the bag
## (InventoryPanel), which does the dismantling when `confirmed`.

signal confirmed

const WIDTH := 640.0
const TEXT_WIDTH := 580.0
const SLOT := 58.0

## Dismantle: +N gold ("ConfirmDismantleButton" in the bag).
var yes_button: Button
## Keep them ("KeepButton").
var keep_button: Button

var _text: Label
var _items: HFlowContainer


func _init() -> void:
	super._init(tr("Dismantle the worse"), WIDTH)
	name = "DismantleConfirm"
	hide()
	_text = UiParts.text("", Fonts.BODY, UiSkin.TEXT, TEXT_WIDTH)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_text)
	_items = HFlowContainer.new()
	_items.alignment = FlowContainer.ALIGNMENT_CENTER
	_items.custom_minimum_size.x = TEXT_WIDTH
	_items.add_theme_constant_override("h_separation", 6)
	_items.add_theme_constant_override("v_separation", 6)
	body.add_child(_items)
	var note := UiParts.text(tr("What you wear, potions, runes, tomes and keys are never touched."), Fonts.BODY, UiSkin.DIM, TEXT_WIDTH)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(note)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	body.add_child(buttons)
	yes_button = UiParts.button(tr("Dismantle"), func() -> void:
		hide()
		confirmed.emit(), Vector2(0, 56))
	yes_button.name = "ConfirmDismantleButton"
	yes_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(yes_button)
	keep_button = UiParts.button(tr("Keep them"), func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		hide(), Vector2(0, 56))
	keep_button.name = "KeepButton"
	keep_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(keep_button)


## Asks about `worse` (never empty): the count, the gold, a slot per stack.
func ask(worse: Array[ItemDef]) -> void:
	var gold := 0
	var shown := Inventory.new(worse.size())
	for item in worse:
		gold += PlayerPack.DISMANTLE.gold_for(item)
		shown.add(item)
	_text.text = (tr("Dismantle 1 piece of gear worse than what you wear, for %d gold?") % gold) if worse.size() == 1 \
		else tr("Dismantle %d pieces of gear worse than what you wear, for %d gold?") % [worse.size(), gold]
	UiParts.clear(_items)
	for entry in shown.grouped():
		var slot := ItemSlot.new(SLOT)
		slot.item = entry.item
		slot.count = entry.count
		slot.tooltip_text = tr(entry.item.display_name)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.focus_mode = Control.FOCUS_NONE
		_items.add_child(slot)
	yes_button.text = tr("Dismantle: +%d gold") % gold
	show()
