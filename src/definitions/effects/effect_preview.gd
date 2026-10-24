class_name EffectPreview
extends RefCounted
## Where an effect shows what it does outside a fight (the bestiary's attack preview,
## AttackPreview): Effect.play_preview() says it with these few strokes, so a new kind brings its
## own picture instead of a branch in the preview. Positions are along the caster's aim (to the
## right), from its feet. The base draws nothing: the preview's stage overrides them.


## The caster's body radius (rings round it start there).
func caster_radius() -> float:
	return 0.0


## `count` shots fanned over `spread` degrees (360: a ring), turned `aim` radians off the aim.
func shots(_count: int, _spread: float, _speed: float, _distance: float, _radius: float, _color: Color, _blast: float, _sheet: VfxSheetDef, _element: VfxElementDef, _aim: float) -> void:
	pass


## A ring of `radius` `forward` units along the aim (0: round the caster), `filled` for an area
## that hits.
func ring(_forward: float, _radius: float, _color: Color, _filled: bool) -> void:
	pass


## The caster lunges `distance` along the aim (back for a negative one) in `duration` seconds.
func lunge(_distance: float, _duration: float) -> void:
	pass


## A cut along the aim, `distance` long and `width` wide.
func line(_distance: float, _width: float, _color: Color) -> void:
	pass


## The monsters `summon` calls appear round the caster.
func summon(_summon: SummonEffect) -> void:
	pass


## How a shot looks in flight, as in the game (Projectile): its sprite, else its element's shot.
static func shot_sheet(texture: Texture2D, frames: int, element: VfxElementDef) -> VfxSheetDef:
	if texture:
		return VfxSheetDef.from_texture(texture, frames)
	return element.projectile if element else null
