class_name DeathFx
## A monster dying in the element of the blow that killed it (HitInfo.element, a burn's or a
## poison's ticks included): its DeathLookDef (VfxElementDef.death) says how the body shader
## takes the body away (ash, frozen then shattered, melted...) and what flies off it, all in the
## element's ramp. A plain blow (no element, steel, blood) dissolves it as it always did.
## docs/vfx.md, "Shaders on bodies".


## Plays `actor`'s death in `element` (null: a plain blow), then calls `finished`.
static func play(actor: Actor, element: VfxElementDef, finished: Callable) -> void:
	var look := DeathLookDef.of(element)
	if element == null or element.death == null:
		element = VfxElementDef.named(&"physical")
	var rig := actor.rig
	if look.style != DeathLookDef.Style.DISSOLVE:
		rig.modulate = Color.WHITE  # its ramp's own colors, not the corpse's grey
	rig.dissolve(look, element, finished)
	var world := actor.world
	if world == null:
		return
	var feet := rig.global_position
	var chest := feet + Vector2(0, -actor.head_height * 0.5)
	var fewer := Settings.fewer_effects
	if look.piece and element.piece:
		world.spawn_vfx(SheetVfx.play(element.piece, feet, Vector2.RIGHT, element))
	if look.motes > 0:
		var count := look.motes / 2 if fewer else look.motes
		world.spawn_vfx(DeathPiecesVfx.motes(rig, element, look, count))
	if look.burst_at >= 0.0:
		_later(rig, look.delay + look.duration * look.burst_at, func() -> void:
			if not is_instance_valid(world):
				return
			if look.shards:
				world.spawn_vfx(DeathPiecesVfx.shards(rig, element, fewer))
			Vfx.pop(world, chest, element, 14.0, Vector2.UP))
	if look.mark > 0.0 and element.mark.a > 0.0:
		_later(rig, look.delay + look.duration * 0.3, func() -> void:
			if is_instance_valid(world):
				world.add_splat(feet, element.mark, look.mark * clampf(actor.radius / 11.0, 0.8, 2.2)))


## `call` in `delay` seconds while `rig` lives (it goes when the death is over).
static func _later(rig: Node, delay: float, call: Callable) -> void:
	var tween := rig.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(call)
