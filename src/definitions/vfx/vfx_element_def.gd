class_name VfxElementDef
extends Resource
## What an element looks like, everywhere it shows: its ramp of colors, the shape of its
## particles, which way they move, and the sheets of its kit (a shot, an impact, the pieces of a
## nova, a claw, the look on a body). Gameplay data points to an element (WeaponDef, SkillDef
## effects, OnHitStatus, passives) instead of picking free colors, so frost is frost wherever it
## comes from. One file per element in data/vfx/elements/, listed in data/vfx/elements.tres.
## The rules and the table of every element: docs/vfx.md.

## The particle "bit" of an element: the tiny shape its sparks, chips and motes take
## (PixelDraw.bit). Shape, not color, is what tells elements apart.
## FORK (a little staircase spark) is the storm's, RUNE (a hollow rhombus) the arcane's; GLINT
## (the 4-point glint) is holy's alone.
enum Bit { SQUARE, DIAMOND, SHARD, TEARDROP, CROSS, RING, GLINT, DROP, MOTE, FORK, RUNE }
## Which way its particles go once they are out.
enum Motion {
	## Up, flickering (fire, embers, spirits).
	RISE,
	## Down, slowly then faster (frost chips, hail, blood drops).
	FALL,
	## Out a little, then settling to the ground (poison, mist, dust).
	SINK,
	## Barely moving (shadow smoke, motes).
	DRIFT,
	## Straight out from the source (sparks, shards).
	OUTWARD,
	## Pulled in toward the source (shadow, the void).
	CONVERGE,
	## Around the source (arcane runes).
	ORBIT,
}
## How it bends the space around it (DistortionStamp, drawn by the screen pass).
enum Distortion {
	NONE,
	## The air trembles above it, rows of pixels sliding sideways (fire).
	HEAT,
	## Pixels caught askew, like through ice (frost novas).
	COLD,
	## Rings of the picture drawn in toward it (shadow, arcane shots).
	PULL,
}

@export var id: StringName
## Its colors from the bright core to the dark edge, 3 to 5 of them (shadow is the one turned
## inside out: a dark core, a bright edge). Everything the element draws takes these colors only.
@export var ramp := PackedColorArray()
## Which step of the ramp is its main color (lights, tints, damage numbers): the orange of fire,
## the ice cyan of frost, the bright edge of shadow.
@export_range(0, 4) var accent: int = 1
## What it leaves in the air: mist, smoke, dust (transparent: nothing).
@export var residue := Color.TRANSPARENT
## What it leaves on the floor for a while: rime, a scorch, a puddle (transparent: nothing).
@export var mark := Color.TRANSPARENT
## Size of the `mark` a landing shot or a spurt of it leaves on the floor (a puddle of venom, a
## stain of blood; 1 = a monster's death). 0: its landings leave nothing (frost, light).
@export_range(0.0, 1.0) var impact_mark: float = 0.0
@export var bit: Bit = Bit.SQUARE
@export var motion: Motion = Motion.OUTWARD
## Shines on its own (a halo and a light around its shots, unshaded sparks). Off for the
## elements that are matter, not energy (blood, earth, steel).
@export var emissive: bool = true
## How it bends the space around its fires, novas and shots (docs/vfx.md, "Shaders").
@export var distortion: Distortion = Distortion.NONE

@export_group("Kit")
## Its shot in flight.
@export var projectile: VfxSheetDef
## Where a shot or a blow lands (one-shot sheet; without one, a burst of its bits).
@export var impact: VfxSheetDef
## One piece of its novas, waves and trails, many of them composed around a ring or along a
## line (ice crystals growing then shattering, licks of fire, rock spikes). Its frames: grow,
## hold, break.
@export var piece: VfxSheetDef
## Its novas lie on the ground as one pool of its matter (GasPoolVfx: poison's gas, its rim
## where the area ends) instead of a ring of pieces; `piece` still makes its trails and arcs.
@export var pool: bool = false
## The sound of its pool welling up (poison's gas bubbling), played with it. Optional.
@export var pool_sound: AudioStream
## What wells up in its pool and pops (poison's bubbles), on the ground with it. Optional.
@export var pool_bubble: VfxSheetDef
## A creature's blow (claws, fangs) in this element.
@export var claw: VfxSheetDef
## Its explosion (Vfx.explosion: a fireball bursting, the ground erupting), drawn at 2x in the
## middle; a bigger blast adds a ring of its pieces at the edge instead of stretching it.
## Without one, a burst in its ramp (BlastVfx).
@export var blast: VfxSheetDef
## The look (a StatusLookDef in data/vfx/status_looks.tres, by its status id) a body slowed by it
## shows: frost's is &"slow" (rime, cold mist). Empty: being slowed by it shows nothing (sand,
## ink: they slow, they don't freeze).
@export var slow_look: StringName
## How a body it kills goes (data/vfx/deaths/: burns to ash, shatters, melts...), in its ramp.
## Every element has one (the vfx tests check it).
@export var death: DeathLookDef
## A body it hits crackles a moment: forks of its ramp on the rim for a frame or two (storm).
@export var crackles: bool = false
## Its impact sound (the "sound family" of docs/vfx.md). Optional.
@export var impact_sound: AudioStream

const ELEMENTS_PATH := "res://data/vfx/elements.tres"

static var _set: VfxElementSet
static var _from_color := {}


## The brightest color (the heart of a shot, the 1-frame flash).
func core() -> Color:
	return ramp[0] if not ramp.is_empty() else Color.WHITE


## Its main color (lights, tints, damage numbers, UI accents).
func color() -> Color:
	return ramp[clampi(accent, 0, ramp.size() - 1)] if not ramp.is_empty() else Color.WHITE


## The darkest color (the edge that outlines it on bright floors).
func edge() -> Color:
	return ramp[ramp.size() - 1] if not ramp.is_empty() else Color.BLACK


## The ramp's color at `t` (0 = core, 1 = edge), in steps: never a blend of two.
func shade(t: float) -> Color:
	if ramp.is_empty():
		return Color.WHITE
	return ramp[clampi(roundi(clampf(t, 0.0, 1.0) * (ramp.size() - 1)), 0, ramp.size() - 1)]


## The element called `element_id` (data/vfx/elements.tres), or null.
static func named(element_id: StringName) -> VfxElementDef:
	if _set == null:
		_set = load(ELEMENTS_PATH) as VfxElementSet
	return _set.find(element_id) if _set else null


## Every element.
static func all() -> Array[VfxElementDef]:
	if _set == null:
		_set = load(ELEMENTS_PATH) as VfxElementSet
	return _set.elements if _set else ([] as Array[VfxElementDef])


## `element`, or for content that only gives a color (made before the elements), a plain
## element built on that color: its own hue for the core, the body and the edge, square bits.
static func or_color(element: VfxElementDef, fallback: Color) -> VfxElementDef:
	if element:
		return element
	var key := fallback.to_html(false)
	if not _from_color.has(key):
		var made := VfxElementDef.new()
		made.id = StringName("color_" + key)
		var base := Color(fallback, 1.0)
		made.ramp = PackedColorArray([base.lightened(0.65), base.lightened(0.2), base, base.darkened(0.45)])
		made.residue = Color(base.darkened(0.6), 0.0)
		_from_color[key] = made
	return _from_color[key]
