class_name HeroPortrait
extends SubViewportContainer
## The hero as he stands in the bag (InventoryPanel): a rig of his own, dressed in what he wears
## exactly as his body in the world is (ActorRig.wear: his armor with its rarity's trim and what
## its affixes carry, his weapon slung on his back with the elements it carries), idling,
## drawn at a whole number of screen pixels per art pixel (docs/design/interface.md, "The bag").

## Art pixels shown across and down: the 15-pixel hero, his helmet, the weapon peeking over his
## shoulder (its top end rides 20 pixels above his feet).
const ART := Vector2i(20, 22)
## Screen pixels per art pixel (the rig draws an art pixel as 2 units).
const ZOOM := 4
## Art pixels between the frame's bottom and his feet.
const FOOT_ROOM := 1
const RIG_SCENE := preload("res://src/entities/rig/actor_rig.tscn")

## The way he faces.
var facing := Vector2.DOWN
var _viewport: SubViewport
var _rig: ActorRig
var _player: Player


func _init() -> void:
	stretch = true
	stretch_shrink = int(ZOOM / 2.0)
	custom_minimum_size = Vector2(ART * ZOOM)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)
	_rig = RIG_SCENE.instantiate() as ActorRig
	_rig.position = Vector2(ART.x, (ART.y - FOOT_ROOM) * 2)
	_viewport.add_child(_rig)


## Shows `player` as he is now: his body, his weapon and his armor (called when the bag opens
## and whenever what he wears changes).
func show_hero(player: Player) -> void:
	if _player != player:
		if is_instance_valid(_player) and _player.equipment.changed.is_connected(_redress):
			_player.equipment.changed.disconnect(_redress)
		_player = player
		if player:
			player.equipment.changed.connect(_redress)
	_redress()


## Dressed again in what the hero wears (his equipment changed).
func _redress() -> void:
	var player := _player if is_instance_valid(_player) else null
	if player == null or player.frames == null:
		_rig.visible = false
		return
	_rig.visible = true
	if _rig.body.sprite_frames != player.frames:
		_rig.setup(player.frames, player.frames_offset)
	_rig.carries_weapon = true
	_rig.direction = &"down"
	_rig.wear(player.equipment)


## The rig drawn (for the tests: what it wears).
func rig() -> ActorRig:
	return _rig


func _process(delta: float) -> void:
	if is_visible_in_tree() and _rig.visible:
		_rig.update_state(facing, 0.0, false, delta)
