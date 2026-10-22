class_name RpgWindow
extends Control
## A big panel in the game's skin (UiSkin): the world dimmed behind, a wooden board with a gold
## ornate border, its title on a red ribbon over the top edge, a Close button. Put what it shows
## in `body`. Runs while the game is paused. A menu for keys and gamepads (MenuNav): Close shows
## the Back key or button beside it.

signal close_requested

const MARGIN := Vector2(54, 40)

## Where the panel's contents go.
var body: VBoxContainer
## Right of the title (gold, counters...), before Close.
var header_right: HBoxContainer

var _title: PanelContainer
var _board: PanelContainer


func _init(title_text: String = "") -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(MenuNav.GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_board = PanelContainer.new()
	_board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board.offset_left = MARGIN.x
	_board.offset_right = -MARGIN.x
	_board.offset_top = MARGIN.y + 10
	_board.offset_bottom = -MARGIN.y + 6
	_board.add_theme_stylebox_override("panel", UiSkin.panel())
	add_child(_board)
	var ornate := NinePatchRect.new()
	ornate.texture = UiSkin.ORNATE
	ornate.self_modulate = UiSkin.ORNATE_TINT
	ornate.draw_center = false
	ornate.patch_margin_left = 42
	ornate.patch_margin_right = 42
	ornate.patch_margin_top = 42
	ornate.patch_margin_bottom = 42
	ornate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ornate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ornate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ornate.offset_left = MARGIN.x + 9
	ornate.offset_right = -MARGIN.x - 9
	ornate.offset_top = MARGIN.y + 19
	ornate.offset_bottom = -MARGIN.y - 3
	add_child(ornate)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 14)
	_board.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	header_right = HBoxContainer.new()
	header_right.add_theme_constant_override("separation", 12)
	header.add_child(header_right)
	var close := Button.new()
	close.text = tr("Close")
	close.set_meta(MenuNav.NOT_FIRST, true)
	close.custom_minimum_size = Vector2(120, 48)
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(PromptGlyph.make(&"ui_cancel"))
	header.add_child(close)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)

	# The title on its ribbon, straddling the board's top edge.
	_title = UiSkin.title(title_text)
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	add_child(_title)
	_title.resized.connect(_place_title)
	resized.connect(_place_title)


func set_title(text: String) -> void:
	(_title.get_child(0) as Label).text = text
	_place_title.call_deferred()


func _place_title() -> void:
	_title.position = Vector2((size.x - _title.size.x) * 0.5, MARGIN.y - 14)


## A column of the board: a dark inset with a gold heading, its contents below.
static func section(heading: String, stone := false) -> Dictionary:
	var box := UiSkin.section(stone)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	box.add_child(column)
	var title := UiSkin.label(heading, Fonts.BODY, UiSkin.GOLD)
	column.add_child(title)
	return { "box": box, "column": column, "title": title }
