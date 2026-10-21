class_name SlashDef
extends Resource
## How a blade's blow is drawn (SwingVfx): a crescent, a spin or a thrust, at whatever reach
## the blow has, in its element's ramp (steel when it has none), its pixels on the art's grid.
## Drawn rather than played from a sheet, so a 120-unit Cleave has the same 2x2 pixels as a
## dagger's flick and nothing is stretched or turned off the grid (docs/vfx.md). Shared by
## weapons (`WeaponDef.slash`), skills' areas (`DamageAreaEffect.slash`) and dashes
## (`DashStrikeEffect.slash`); one file per look in data/vfx/slashes/.

enum Shape {
	## A crescent sweeping `arc_degrees` across the aim.
	CRESCENT,
	## A blade turning all around (`arc_degrees` of turn: 360 = once around).
	SPIN,
	## A streak shooting out along the aim (a stab, a lunge).
	THRUST,
}

@export var shape: Shape = Shape.CRESCENT
@export_range(20.0, 720.0) var arc_degrees: float = 140.0
## Width of the blade's band at its head, in world units (whole art pixels look best: even).
@export var thickness: float = 18.0
## Strokes one inside the other (2: a double slash), each a little later than the last.
@export_range(1, 3) var strokes: int = 1
## Where the cutting edge runs, as a share of the reach the blow is given.
@export_range(0.3, 1.5) var reach_scale: float = 1.0
## Seconds the head takes to sweep; then it dissolves.
@export var duration: float = 0.14
## How much of the sweep stays drawn behind the head (0..1).
@export_range(0.2, 1.0) var trail: float = 0.75
## A random turn of the whole blow, in degrees (a flurry of stabs is never twice the same).
@export var jitter_degrees: float = 0.0
## Played where the blow ends (Flurry's last stab: a cross), painted in the blow's element.
@export var finisher: VfxSheetDef
