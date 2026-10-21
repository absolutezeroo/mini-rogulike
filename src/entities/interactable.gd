class_name Interactable
extends Node2D
## Something the hero uses by standing next to it and pressing Interact (the HUD's contextual
## button, E / F, the right trigger): the merchant, the forge, an encounter, a pact's stele.
## Walking up to it opens nothing by itself.
## The thing adds one as a child where the hero must stand, sets its verb and icon and connects
## `used`; the Game's Interactor gives the button to the nearest one in reach. Anything else can
## take part the same way (an item lying on the ground, later): no other code to change.

## The hero pressed Interact by it.
signal used(by: Player)

const GROUP := &"interactables"

## The word on the button ("Trade", "Pray"...), in English: translated where it is shown.
var verb := "Use"
## Its picture on the button (none: the verb's first letter).
var icon: Texture2D
var icon_tint := Color.WHITE
## The button's tint.
var color := Color(1.0, 0.82, 0.4)
## How close the hero must stand (pixels from this node).
var reach := 46.0
## False while it can't be used (an encounter spent, a pact already sworn).
var enabled := true
## The Interactor gave it the button (a soft ring at its feet).
var focused := false:
	set(value):
		if value != focused:
			focused = value
			_time = 0.0
			queue_redraw()

var _time := 0.0


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	# Its ring is light: added onto the floor, over the floor's darkness.
	z_as_relative = false
	z_index = LightField.Z + 1
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = add


## In reach and usable by `player`.
func can_use(player: Player) -> bool:
	return enabled and is_inside_tree() and global_position.distance_to(player.global_position) <= reach


func use(player: Player) -> void:
	if enabled:
		used.emit(player)


func _process(delta: float) -> void:
	if focused:
		_time += delta
		queue_redraw()


## A gold ring on the ground while the button is its: this is what Interact will use.
func _draw() -> void:
	if not focused:
		return
	var grow := minf(_time / 0.18, 1.0)
	var pulse := 0.6 + 0.4 * sin(_time * 4.0)
	var ring := Color(color, 1.0)
	PixelDraw.disc(self, Vector2(0, 10), 22.0 * grow, Color(ring, 0.08 * grow), 1.0, 0.45)
	PixelDraw.ring(self, Vector2(0, 10), 22.0 * grow, ring, 1, 0.55 + 0.45 * pulse, 0.45)
