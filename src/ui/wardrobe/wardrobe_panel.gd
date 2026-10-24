class_name WardrobePanel
extends InfoPanel
## The Wardrobe (title screen: its button, or a tap on the hero by the Well): what the hero wears
## for the look alone (CosmeticDef; for now the auras, AuraDef). Left, the hero wearing what is
## picked, turning round (its four sides); right, each aura with its words: "Wear", "Worn", or
## what opens it, dimmed. Nothing here changes the game (docs/design/progression.md, "The
## Wardrobe"). Works with touch, the mouse, the keys and a gamepad (MenuNav: its buttons).
## Reachable as %Preview, %Wear_<id> (each open aura's button; "none" for no aura), %Rows.

## The preview's size, and the hero's scale in it (art pixels to UI units).
const PREVIEW_SIZE := Vector2(260, 300)
const PREVIEW_SCALE := 6.0
## Seconds on each side as he turns.
const TURN_SECONDS := 1.6
const SIDES: Array[StringName] = [&"down", &"right", &"up", &"left"]

var _content: ContentDB
var _preview: Control
var _hero: AnimatedSprite2D
var _aura: AuraVfx
var _rows: VBoxContainer
var _side := 0
var _turn := 0.0


func _init() -> void:
	super._init(TranslationServer.tr("Wardrobe"))


## Shown with `content_db`'s cosmetics (the title's).
func open_with(content_db: ContentDB) -> void:
	_content = content_db
	if _rows == null:
		_build()
	_fill()
	open()
	var first := _first_button()
	if first and InputDevice.uses_buttons():
		first.grab_focus()


func _build() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	content.add_child(row)
	_preview = PanelContainer.new()
	_preview.custom_minimum_size = PREVIEW_SIZE
	_preview.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_preview.add_theme_stylebox_override("panel", UiSkin.inset())
	_preview.clip_contents = true
	row.add_child(_preview)
	MenuWindow.expose(_preview, "Preview", self)
	_hero = AnimatedSprite2D.new()
	_hero.scale = Vector2.ONE * PREVIEW_SCALE
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.add_child(_hero)
	_preview.resized.connect(_place_hero)
	var box: Dictionary = RpgWindow.section(tr("Auras"))
	(box.box as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box.box)
	_rows = box.column
	MenuWindow.expose(_rows, "Rows", self)


## The rows again (an unlock met since, the one worn changed) and the preview.
func _fill() -> void:
	if _content and _content.player:
		_hero.sprite_frames = _content.player.frames
		_hero.offset = _content.player.frames_offset
	UiParts.clear(_rows)
	_row(null)
	for cosmetic in _content.cosmetics_of(CosmeticDef.Slot.AURA):
		_row(cosmetic as AuraDef)
	_dress()


## One aura's row (null: "No aura"): its name, its words, and Wear / Worn / what opens it.
func _row(aura: AuraDef) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	_rows.add_child(line)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	line.add_child(words)
	var wearable := aura == null or aura.is_open()
	var title := tr(aura.display_name) if aura else tr("No aura")
	words.add_child(UiSkin.label(title, Fonts.BODY, UiSkin.GOLD if wearable else UiSkin.DIM, true))
	if aura and not aura.description.is_empty():
		words.add_child(UiSkin.label(tr(aura.description), Fonts.BODY, UiSkin.TEXT if wearable else UiSkin.DIM, true))
	if not wearable:
		words.add_child(UiSkin.label(tr("Locked: %s") % aura.unlock_text(), Fonts.BODY, UiSkin.DIM, true))
		return
	var worn := Wardrobe.aura(_content)
	var is_worn := worn == aura
	var button := MenuWindow.button(tr("Worn") if is_worn else tr("Wear"), Fonts.BODY, 44)
	button.custom_minimum_size.x = 150
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = is_worn
	line.add_child(button)
	MenuWindow.expose(button, "Wear_%s" % (String(aura.id) if aura else "none"), self)
	button.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_open)
		if aura:
			Wardrobe.wear(aura)
		else:
			Wardrobe.take_off(CosmeticDef.Slot.AURA)
		_fill()
		var next := _first_button()
		if next and InputDevice.uses_buttons():
			next.grab_focus())


## The hero in the preview wearing the aura worn.
func _dress() -> void:
	if _aura and is_instance_valid(_aura):
		_aura.queue_free()
	_aura = AuraVfx.make(Wardrobe.aura(_content), 30.0, 12.0)
	if _aura:
		_aura.wear_on_sprite(_hero, feet_of(_content.player.frames, _content.player.frames_offset))
	_place_hero()
	_show_side()


## The hero's feet in his own art pixels (his frames are drawn centered, standing on their last row).
static func feet_of(frames: SpriteFrames, offset: Vector2) -> Vector2:
	var height := 16.0
	if frames and frames.has_animation(&"idle_down") and frames.get_frame_count(&"idle_down") > 0:
		height = frames.get_frame_texture(&"idle_down", 0).get_size().y
	return Vector2(0, height * 0.5 + offset.y - 1.0)


func _place_hero() -> void:
	if _hero == null or _preview == null:
		return
	var at := Vector2(_preview.size.x * 0.5, _preview.size.y * 0.55)
	var moved := at - _hero.position
	_hero.position = at
	if _aura and is_instance_valid(_aura):
		_aura.position += moved


func _process(delta: float) -> void:
	if not visible or _hero == null:
		return
	_turn += delta
	if _turn >= TURN_SECONDS:
		_turn = 0.0
		_side = (_side + 1) % SIDES.size()
		_show_side()


func _show_side() -> void:
	var animation := StringName("idle_%s" % SIDES[_side])
	if _hero.sprite_frames and _hero.sprite_frames.has_animation(animation):
		_hero.play(animation)


## The first button that can be pressed (the focus for keys and gamepads).
func _first_button() -> Button:
	for line in _rows.get_children():
		for child in line.get_children():
			if child is Button and not (child as Button).disabled and not child.is_queued_for_deletion():
				return child as Button
	return null
