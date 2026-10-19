class_name Encounter
extends StaticBody2D
## An encounter (EncounterDef) standing in a room. Walking up to it asks what to do;
## once a choice is made it is spent.

const OPEN_DISTANCE := 46.0
const REARM_DISTANCE := 90.0

var def: EncounterDef
var used := false

var _world: World
var _armed := true
var _time := 0.0


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
	if used:
		return
	var player := _world.player
	if player == null or player.is_dead:
		return
	var distance := global_position.distance_to(player.global_position)
	if _armed and distance <= OPEN_DISTANCE:
		_armed = false
		Events.encounter_requested.emit(self)
	elif distance >= REARM_DISTANCE:
		_armed = true


func _draw() -> void:
	draw_set_transform(Vector2(0, 12), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	if not used:
		# A soft glow: something is here.
		var glow := def.color
		glow.a = 0.15 + 0.1 * sin(_time * 3.0)
		draw_circle(Vector2(0, -2), 22.0, glow)
	if def.icon:
		var tint := def.icon_tint if not used else def.icon_tint.darkened(0.45)
		draw_texture_rect(def.icon, Rect2(-16, -20, 32, 32), false, tint)
	if not used and _armed:
		var font := Fonts.MAIN
		draw_string_outline(font, Vector2(-4, -26), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 4, Color.BLACK)
		draw_string(font, Vector2(-4, -26), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, def.color.lightened(0.3))
