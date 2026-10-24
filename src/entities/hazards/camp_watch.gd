class_name CampWatch
extends Node
## Watches a campfire (or an oasis): stay by it too long and the light draws monsters in, wave
## after wave, each bigger. A warning first. Leaving lets the watch calm down slowly.
## Added by HeatSource when its def has a `camp_limit`.

var source: HeatSource
## Seconds the hero has been camping (goes back down, slower, when away).
var camped := 0.0
var waves := 0

var _warned := false


func _physics_process(delta: float) -> void:
	var world := source.world
	var player := world.player
	if player == null or player.is_dead:
		return
	var limit := source.def.camp_limit
	if source.reaches(player):
		camped += delta
	else:
		camped = maxf(camped - delta * 0.5, 0.0)
	if not _warned and camped >= limit * 0.6:
		_warned = true
		Events.log_message(tr(source.def.camp_warning), Palette.DANGER)
		world.spawn_floating_text(source.global_position + Vector2(0, -30), "!", Palette.DANGER)
		Sfx.play_at(Sfx.bank.monster_alert, source.global_position)
	if camped >= limit:
		invade()


## Monsters of the act come out of the dark around the spot, after the hero. They give nothing:
## camping is not farming.
func invade() -> void:
	var world := source.world
	var count := world.rng.randi_range(source.def.invasion.x, source.def.invasion.y) + waves
	for i in count:
		var kind := world.pick_monster()
		if kind == null:
			continue
		var at := world.find_open_point_near(source.global_position, source.def.reach + 140.0, WorldSpace.room_for(kind))
		var monster := world.spawn_monster(kind, at)
		monster.summoned = true
		monster.target = world.player
		Vfx.puff(world, at)
	waves += 1
	camped = 0.0
	_warned = false
	Events.log_message(tr(source.def.invasion_message), Palette.DANGER)
	Events.screen_shake.emit(0.4)
	Sfx.play_at(Sfx.bank.ambush, source.global_position)
