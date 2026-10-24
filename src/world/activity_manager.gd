class_name ActivityManager
extends RefCounted
## What isn't seen isn't run: a few times a second it looks at the floor's monsters and lets those
## off screen (with a margin) and out of reach of the hero sleep (Monster.set_awake(): no AI, no
## movement, no animation; their bodies stay, shots still hit them), unless they are after
## someone, are a boss or are falling. Owned by the World (World.activity), ticked by its physics.

## Seconds between two looks at who sleeps and who wakes.
const INTERVAL := 0.2
## Monsters this far past the screen's edge still think (they may walk in any moment).
const WAKE_MARGIN := 256.0
## Pixels past a monster's chasing sight (Monster.chase_detect_radius()) it still thinks, for a
## hero about to come into view.
const REACH_MARGIN := 64.0

## The monsters thinking this moment, refreshed every INTERVAL (a new one is awake until the next
## look). Untyped: one may be freed before the next refresh.
var awake: Array = []
## The awake monsters by grid cell, for their spacing (MonsterBuckets, Monster._keep_spacing).
var buckets := MonsterBuckets.new()

var _world: World
var _timer := 0.0


func _init(world: World) -> void:
	_world = world


## A new floor: nobody counted, the next tick looks at once.
func clear() -> void:
	awake.clear()
	buckets.invalidate()
	_timer = 0.0


func tick(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = INTERVAL
		update()


## Wakes the monsters that must think and puts the others to sleep.
func update() -> void:
	awake.clear()
	buckets.invalidate()
	var view := _world.view_rect(WAKE_MARGIN)
	var player := _world.player
	var hero := player.global_position if player and is_instance_valid(player) else Vector2.INF
	for node in _world.get_tree().get_nodes_in_group("monsters"):
		var monster := node as Monster
		if monster == null or monster.is_dead or monster.is_queued_for_deletion():
			continue
		var is_awake := monster.target != null or monster.is_boss() or monster.is_falling \
			or view.has_point(monster.global_position) \
			or (hero != Vector2.INF and monster.global_position.distance_to(hero) <= monster.chase_detect_radius() + REACH_MARGIN)
		monster.set_awake(is_awake)
		if is_awake:
			awake.append(monster)
