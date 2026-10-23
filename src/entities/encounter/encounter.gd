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
	Events.encounter_used.emit(self)
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
	if def.niche:
		_draw_niche(def.niche)
	if not used:
		Fonts.draw(self, Vector2(0, -26), "?", Fonts.BODY, def.color.lightened(0.3), 0.5, Color.BLACK)


## The empty niche beside it (EncounterNiche), in art pixels at the statue's size: a block of the
## statue's stone, an arched hollow with nothing on its ledge, a base whose name was scratched.
func _draw_niche(niche: EncounterNiche) -> void:
	var lit := niche.stone
	var mid := niche.stone.darkened(0.28)
	var dark := niche.stone.darkened(0.62)
	var hollow := Color(0.07, 0.06, 0.09)
	var corner := PixelDraw.snap(niche.offset + Vector2(-12, -20))
	PixelDraw.disc(self, niche.offset + Vector2(0, 12), 11.0, Color(0, 0, 0, 0.35), 1.0, 0.4)
	for y in 16:
		for x in 12:
			var color := lit if x < 6 else mid  # lit from the left, as the statue is
			if x == 0 or x == 11 or y == 0 or y == 15:
				color = dark
			elif y >= 12:
				color = mid if x < 6 else dark.lightened(0.15)  # the base, in shadow
			var arch := (y == 2 and x >= 4 and x <= 7) or (y == 3 and x >= 3 and x <= 8) or (y >= 4 and y <= 10 and x >= 2 and x <= 9)
			if arch:
				color = hollow
			if y == 11 and x >= 2 and x <= 9:
				color = lit.lightened(0.15) if x < 6 else lit  # the bare ledge: nothing stands on it
			if y == 13 and x >= 3 and x <= 8 and (x * 7 + 3) % 3 != 0:
				color = dark  # the name, scratched away
			PixelDraw.cell(self, Vector2i(corner / PixelDraw.PX) + Vector2i(x, y), color)
