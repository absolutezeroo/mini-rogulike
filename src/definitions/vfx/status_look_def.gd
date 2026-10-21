class_name StatusLookDef
extends Resource
## How a status shows on whoever has it (StatusFx), in its element's language: burning bodies
## throw small flames and embers, poisoned ones bubble and leak a sinking green haze, chilled
## ones grow rime on their edges, shed ice chips and breathe cold mist at their feet. A burst
## when it starts (and a sound), and the color of its damage numbers. Everything is drawn on the
## art's grid in the element's ramp (docs/vfx.md). One per status id, listed in
## data/vfx/status_looks.tres; a slowing element names the one it shows (VfxElementDef.slow_look).

enum Mote {
	NONE,
	## Rising sparks that cool down the ramp (fire).
	EMBER,
	## Bubbles that swell and pop (poison).
	BUBBLE,
	## Chips of the element's bit falling off the body (frost).
	CHIP,
}

## What the body shader paints on the body itself, in the element's ramp (BodyLook,
## flash.gdshader); the particles here are its accent.
enum Body {
	NONE,
	## Heat crawling up the lower rim, flickering (burn).
	HEAT,
	## Rime creeping in from the edges as it lasts, cold colors; heavy: a glint sweeping (frost).
	RIME,
	## A wave rising up the body on each tick, dithered (poison).
	WAVE,
	## A pale flicker of the silhouette, a see-through rim (a wail's haunt).
	FLICKER,
}

## The status: a damage-over-time id (&"burn", &"poison") or &"slow" (frost's).
@export var status: StringName
## Its colors and shapes (data/vfx/elements/).
@export var element: VfxElementDef
## What it paints on the body (the base of the look; the particles are the accent).
@export var body: Body = Body.NONE
## RIME only: a slow at least this strong freezes the body (thicker rime, a glint sweeping).
@export_range(0.0, 1.0) var heavy_at: float = 0.5

@export_group("While it lasts")
## A small animated sheet (frames in a row) spawned over the body, rising or falling.
@export var particle: Texture2D
@export_range(1, 32) var particle_frames: int = 1
## Spawned per second.
@export var particle_rate: float = 8.0
@export var particle_life: float = 0.5
## Pixels per second, up (negative: they fall).
@export var particle_rise: float = 18.0
## World units per texel of the sheets (2 = the art's own size; always whole and even).
@export_range(2, 4, 2) var texel: int = 2
@export var particle_tint: Color = Color.WHITE
## Tiny things around it (embers rising, bubbles popping, chips falling), per second.
@export var mote: Mote = Mote.NONE
@export var mote_rate: float = 6.0
## The motes' color when the look has no element.
@export var mote_color: Color = Color.WHITE
## Pieces that cling to the body's edges while it lasts (rime crystals): a sheet whose frames
## grow once, then its last frame holds; when the status ends they break into chips.
@export var crust: Texture2D
@export_range(1, 16) var crust_frames: int = 1
@export_range(0, 8) var crust_count: int = 0
## Pixels of the element's residue drifting down at the feet (cold mist, a sinking haze), per
## second.
@export var mist_rate: float = 0.0

@export_group("When it starts")
## Played once over the body (frames in a row). Without one, a burst of the element's bits.
@export var burst: Texture2D
@export_range(1, 32) var burst_frames: int = 1
@export var burst_time: float = 0.4
@export var burst_tint: Color = Color.WHITE
@export var sound: AudioStream
@export var sound_db: float = -8.0

@export_group("Numbers")
## The color of the damage it deals (its ticks).
@export var text_color: Color = Color.WHITE


## The color of motes at `t` of their life (0 born, 1 gone): down the element's ramp.
func mote_shade(t: float) -> Color:
	if element:
		return element.shade(0.1 + t * 0.9)
	return mote_color
