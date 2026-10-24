class_name AuraDef
extends CosmeticDef
## An aura (docs/vfx.md, "Auras"): a glow lying on the ground at the hero's feet, a halo of light
## behind his body, and a few motes, all in its elements' ramps, on the art's grid, drawn by
## AuraVfx. For the look only: it never hides a telegraph (the ground glow is under them, on the
## GROUND layer, and sparse), never the hero (the halo and the motes are behind him), and with
## Settings.fewer_effects only the ground glow stays, still.

## How the ground glow is drawn (aura_ground.gdshader).
enum Ground {
	## A ring of light with rays turning slowly around the feet (the divine).
	RAYS,
	## A pool of dark with a crawling edge, the floor dimmed under it (the dark).
	POOL,
	## A ring of embers flaring and dying in turn around a smouldering core (the demonic).
	EMBERS,
}

## How its motes move.
enum Motes {
	## Rising and fading (sparks of light, embers).
	RISE,
	## Sinking to the ground from the shoulders (wisps of dark).
	SINK,
}

@export_group("Colors")
## Its ramp (the ground glow's, the halo's), and the steps of it it takes (0 = core, 1 = edge):
## an element's ramp runs from its core to its edge, bright to dark for light (holy), dark to
## light for the dark (shadow), so each aura says which step is which.
@export var element: VfxElementDef
@export_range(0.0, 1.0, 0.05) var bright_shade: float = 0.25
@export_range(0.0, 1.0, 0.05) var glow_shade: float = 0.5
@export_range(0.0, 1.0, 0.05) var dim_shade: float = 0.75
## The deep color (the pool, the embers' core): a step of `accent` (null: `element`).
@export var accent: VfxElementDef
@export_range(0.0, 1.0, 0.05) var deep_shade: float = 1.0
## The motes' and the sparks' ramp (null: `element`) and the sparks' step.
@export var mote_element: VfxElementDef
@export_range(0.0, 1.0, 0.05) var spark_shade: float = 0.0
## The motes' steps as they live (born, then older); the halo's two bands'.
@export var mote_shades := PackedFloat32Array([0.0, 0.25, 0.5])
@export_range(0.0, 1.0, 0.05) var halo_inner_shade: float = 0.5
@export_range(0.0, 1.0, 0.05) var halo_outer_shade: float = 0.75

@export_group("Ground")
@export var ground: Ground = Ground.RAYS
## Half its width on the ground, world units (the hero is about 12 wide).
@export_range(8.0, 40.0, 1.0) var radius: float = 18.0
## Its height over its width: an oval lying on the floor.
@export_range(0.3, 1.0, 0.05) var squash: float = 0.45
## How many art pixels of it are lit (0..1): sparse enough to read the floor and a telegraph.
@export_range(0.1, 1.0, 0.05) var density: float = 0.55
## Seconds of one breath (the glow a pixel wider, then back).
@export_range(0.5, 6.0, 0.1) var breath: float = 2.4
## Its glowing pixels write the emissive mark (kept out of the floor's grading); the pool's dark
## doesn't.
@export var emissive: bool = true
## A light on the floor around him in its core color, world units (0: none).
@export_range(0.0, 120.0, 1.0) var light_reach: float = 48.0

@export_group("Halo")
## The halo of light behind his body: its two bands' radii (world units), its height over its
## width (above 1: a tall oval round a standing body); 0: none.
@export_range(0.0, 30.0, 0.5) var halo_inner: float = 9.0
@export_range(0.0, 40.0, 0.5) var halo_outer: float = 14.0
@export_range(1.0, 3.0, 0.05) var halo_squash: float = 1.6
## How much of each band's color is added (0..1).
@export_range(0.0, 1.0, 0.05) var halo_inner_density: float = 0.3
@export_range(0.0, 1.0, 0.05) var halo_outer_density: float = 0.15
## Flickers (on, on, off: flames) instead of breathing.
@export var halo_flicker: bool = false

@export_group("Motes")
@export_range(0, 16) var motes: int = 6
@export var mote_motion: Motes = Motes.RISE
## World units a second.
@export_range(2.0, 60.0, 1.0) var mote_speed: float = 14.0
## Seconds a mote lives.
@export_range(0.3, 4.0, 0.1) var mote_life: float = 1.6
## Sideways sway, world units.
@export_range(0.0, 8.0, 0.5) var mote_sway: float = 2.0
