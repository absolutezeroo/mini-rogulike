class_name Encounter
extends StaticBody2D
## An encounter (EncounterDef) standing in a room. Standing by it and pressing Interact (its
## `verb`: "Pray", "Drink"...) asks what to do; once a choice is made it is spent.

## The Interact button offers it from this close.
const OPEN_DISTANCE := 60.0

var def: EncounterDef
## Spent: a choice was made (Interact no longer offers it).
var used := false:
	set(value):
		used = value
		_spot.enabled = not value

var _world: World
var _time := 0.0
## Where the hero presses Interact (off once spent).
var _spot := Interactable.new()


func setup(encounter: EncounterDef, world: World) -> void:
	def = encounter
	_world = world
	collision_layer = Layers.WORLD
	collision_mask = 0
	add_to_group("encounters")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 18)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, 4)
	add_child(collision)
	_spot.verb = encounter.verb
	_spot.reach = OPEN_DISTANCE
	_spot.color = encounter.color
	_spot.icon = encounter.icon
	_spot.icon_tint = encounter.icon_tint
	_spot.used.connect(func(_by: Player) -> void: Events.encounter_requested.emit(self))
	add_child(_spot)


## Pays the cost of choice `index`, draws an outcome and applies it. Returns the outcome
## (null if the hero can't afford it).
func resolve(index: int, player: Player) -> EncounterOutcome:
	if used or index < 0 or index >= def.choices.size():
		return null
	var choice := def.choices[index]
	if not choice.can_afford(player, _world.depth):
		return null
	used = true
	Events.stat_counted.emit("encounters", 1)
	player.spend_gold(choice.cost_in_gold(_world.depth))
	if choice.max_hp_cost > 0.0:
		player.base_stats.max_hp -= choice.max_hp_lost(player)
		player.invalidate_stats()
	var outcome := choice.pick_outcome(_world.rng)
	if outcome:
		outcome.apply(player, global_position)
	queue_redraw()
	return outcome


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	PixelDraw.disc(self, Vector2(0, 12), 13.0, Color(0, 0, 0, 0.35), 1.0, 0.4)
	if not used:
		# A soft glow: something is here (a flat stepped disc, breathing in two steps).
		var glow := Color(def.color, 0.2 if sin(_time * 3.0) > 0.0 else 0.12)
		PixelDraw.disc(self, Vector2(0, -2), 22.0, glow)
	if def.icon:
		var tint := def.icon_tint if not used else def.icon_tint.darkened(0.45)
		draw_texture_rect(def.icon, Rect2(-16, -20, 32, 32), false, tint)
	if not used:
		Fonts.draw(self, Vector2(0, -26), "?", Fonts.BODY, def.color.lightened(0.3), 0.5, Color.BLACK)
