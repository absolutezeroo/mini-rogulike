class_name DeathLookDef
extends Resource
## How a body killed by an element goes (DeathFx): the body shader's death in that element's
## ramp (ActorRig's flash.gdshader, `death_style`), and what flies off it: a fire kill burns to
## ash from the feet up behind an ember edge, frost freezes the body then shatters it into
## pieces, poison melts it into a puddle, storm flashes it white and scatters it in sparks, holy
## lifts it away as light, shadow sucks it into a dark point, spirit thins it into rising wisps,
## earth turns it to stone that crumbles; a plain blow (steel, blood) dissolves it as before, its
## chunks flying. One file per look in data/vfx/deaths/, an element points to one
## (VfxElementDef.death); the colors are always the element's (docs/vfx.md, "Shaders on bodies").

## What the shader does with the body. Keep in step with `death_style` in flash.gdshader.
enum Style {
	## Pixels vanish in a random order behind a glowing edge (a plain blow).
	DISSOLVE,
	## Burnt away from the feet up behind a ragged ember edge, the rest charring.
	ASH,
	## Frozen from the edges in, cracks showing, then broken into pieces (`shards`).
	SHATTER,
	## Columns sagging into a widening puddle, green taking over, dithered away.
	MELT,
	## A white flash, then flickering in the element's colors while its pixels fly apart.
	SCATTER,
	## Turned to light and lifted away from the feet up.
	ASCEND,
	## Drawn into one dark point with a bright rim.
	IMPLODE,
	## Pale, wavering and rising, dithered away from the feet first.
	WISP,
	## Turned to stone, cracking, the columns slumping, gone in dust.
	CRUMBLE,
}

@export var style: Style = Style.DISSOLVE
## Seconds before it starts going (the killing blow's flash and hit stop first).
@export var delay: float = 0.15
## Seconds it takes to go.
@export var duration: float = 0.45

@export_group("What flies off")
## The body's chunks in the monster's color and a puff of smoke (Vfx.death): a plain blow's.
@export var chunks: bool = false
## When the element's impact plays over the body (Vfx.pop: frost's shards cracking out, storm's
## forks, shadow's ring collapsing), as a fraction of `duration`. Below 0: never.
@export_range(-1.0, 1.0) var burst_at: float = -1.0
## The frozen body breaks into pieces of its own art at `burst_at` (DeathPiecesVfx.shards).
@export var shards: bool = false
## Bits of the element rising off the body while it goes (embers, motes of light, wisps).
@export_range(0, 24) var motes: int = 0
## The element's nova piece rises at the feet as it starts (a shaft of light, pale flames).
@export var piece: bool = false
## The element's mark is left on the floor (a scorch, a puddle), this big (0: none).
@export_range(0.0, 2.0) var mark: float = 0.0


## The look of a death by `element` (the killing hit's): its own, else a plain blow's.
static func of(element: VfxElementDef) -> DeathLookDef:
	if element and element.death:
		return element.death
	var physical := VfxElementDef.named(&"physical")
	if physical and physical.death:
		return physical.death
	return DeathLookDef.new()
