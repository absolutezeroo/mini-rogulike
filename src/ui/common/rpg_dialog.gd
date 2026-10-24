class_name RpgDialog
extends Control
## A smaller panel in the game's skin (UiSkin), centred and as big as what it holds: the world
## dimmed behind, a wooden board with a gold ornate border, its title on a red ribbon over the
## top edge. No Close button (the panel using it puts its own buttons in `body`). For the
## pause menu, encounters, perk choices and the end of a run; RpgWindow is the full-screen one.
## A menu for keys and gamepads (MenuNav).

## Where the dialog's contents go.
var body: VBoxContainer
## The words on the ribbon.
var title_label: Label

var _board: PanelContainer
var _ribbon: PanelContainer
var _ornate: StyleBoxTexture


## `width`: the board's minimum width (0: as wide as its contents).
func _init(title_text: String = "", width: float = 0.0, dim_alpha: float = 0.72) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(MenuNav.GROUP)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = UiSkin.backdrop(dim_alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 14  # room for the ribbon above the board
	add_child(center)

	_board = PanelContainer.new()
	_board.custom_minimum_size.x = width
	_board.add_theme_stylebox_override("panel", UiSkin.panel())
	center.add_child(_board)
	_ornate = StyleBoxTexture.new()
	_ornate.texture = UiSkin.ORNATE
	_ornate.modulate_color = UiSkin.ORNATE_TINT
	_ornate.draw_center = false
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_ornate.set_texture_margin(side, 42)
	_board.draw.connect(func() -> void:
		_board.draw_style_box(_ornate, Rect2(Vector2.ZERO, _board.size).grow(-9)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 22)
	_board.add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)

	_ribbon = UiSkin.title(title_text)
	title_label = _ribbon.get_child(0) as Label
	add_child(_ribbon)
	_ribbon.resized.connect(_place_ribbon)
	_board.item_rect_changed.connect(_place_ribbon)
	resized.connect(_place_ribbon)


func set_title(text: String, color: Color = UiSkin.TEXT) -> void:
	title_label.text = text
	title_label.add_theme_color_override("font_color", color)
	_place_ribbon.call_deferred()


## The board's size on screen (tests, layout checks).
func board_rect() -> Rect2:
	return _board.get_global_rect()


func _place_ribbon() -> void:
	if not is_inside_tree():
		return
	var top := _board.get_global_rect().position.y - get_global_rect().position.y
	_ribbon.position = Vector2((size.x - _ribbon.size.x) * 0.5, top - 24)
