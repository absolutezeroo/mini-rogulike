class_name BodyTemperature
extends RefCounted
## How cold or hot the hero is: -100 (frozen) .. 0 (fine) .. 100 (burning up).
## Frozen floors pull it down (FloorEventDef.temperature), scorching ground pushes it up,
## campfires bring it back to normal; otherwise it slowly goes back to normal by itself.
## At either end it hurts every few seconds; the cold also slows you down.
## Rules: DungeonConfig > Temperature.

const LIMIT := 100.0
const COLD_COLOR := Color("8fd3ff")
const HOT_COLOR := Color("ff7a3d")

var value := 0.0
var _tick := 0.0


func update(actor: Actor, delta: float) -> void:
	var world := actor.world
	if world == null or actor.is_dead:
		return
	var rules := world.config()
	var comfort := false
	var heat := 0.0
	for node in actor.get_tree().get_nodes_in_group("heat_sources"):
		var source := node as HeatSource
		if source and source.world == world and source.reaches(actor):
			if source.def.comfort:
				comfort = true
			else:
				heat += source.def.heat
	var drift := world.floor_event.temperature if world.floor_event else 0.0
	if comfort:
		value = move_toward(value, 0.0, rules.temperature_comfort_rate * delta)
	elif heat != 0.0:
		value += heat * delta
	elif drift != 0.0:
		value += drift * delta
	else:
		value = move_toward(value, 0.0, rules.temperature_recovery * delta)
	value = clampf(value, -LIMIT, LIMIT)

	if value < -LIMIT * 0.5:
		var cold := (-value - LIMIT * 0.5) / (LIMIT * 0.5)
		actor.statuses.apply_slow(rules.cold_slow * cold, 0.2, &"cold")
	if absf(value) >= LIMIT:
		_tick -= delta
		if _tick <= 0.0:
			_tick = rules.temperature_tick
			_hurt(actor, world, rules)
	else:
		_tick = rules.temperature_tick * 0.5


func _hurt(actor: Actor, world: World, rules: DungeonConfig) -> void:
	var amount := roundi((rules.temperature_damage + world.depth * 0.5) * world.damage_scale())
	var frozen := value < 0.0
	world.spawn_floating_text(actor.head_position() + Vector2(0, -12), "Freezing!" if frozen else "Burning up!", COLD_COLOR if frozen else HOT_COLOR)
	actor.take_hit(Combat.make_tick(null, amount))


## -1 (frozen) .. 1 (burning up).
func ratio() -> float:
	return value / LIMIT


func is_extreme() -> bool:
	return absf(value) >= LIMIT


## Tint of the body: bluish when cold, reddish when hot.
func tint() -> Color:
	var strength := clampf((absf(value) - 25.0) / 75.0, 0.0, 1.0) * 0.55
	return Color.WHITE.lerp(COLD_COLOR if value < 0.0 else HOT_COLOR, strength)


func reset() -> void:
	value = 0.0
	_tick = 0.0
