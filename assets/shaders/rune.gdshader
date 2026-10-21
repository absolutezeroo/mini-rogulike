shader_type canvas_item;
render_mode blend_disabled;
// A sigil or a rune that draws itself and burns out (Vfx.magic's holy sigil, arcane glyphs, the
// pact's circle). A stepped reveal mask over whatever the node draws (a sheet, rings, lines):
//   - drawing (`reveal` 0..1): a ring is drawn in a few strokes, not swept: each stroke an arc
//     traced from one end to the other, every other one the other way, in a hand's order; what
//     lies inside (rays, glyphs) comes last, a chunk at a time; a glyph is drawn top-down. The
//     tip of the stroke being drawn is in the `head` color (hot);
//   - burning out (`burn` 0..1): it goes in patches, each pixel turning to `ember` (the ramp's
//     dark step) the moment before it is gone.
// Every pixel is there or not (translucent drawing is dithered), on the world's grid.

#include "res://assets/shaders/fx.gdshaderinc"

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float burn : hint_range(0.0, 1.0) = 0.0;
// 0: a ring (strokes around the centre), 1: a glyph (strokes top-down).
uniform int order_mode = 0;
uniform int strokes = 5;
// The drawing's middle (from the node's origin) and size, world units; under 1, an oval lying
// on the floor.
uniform vec2 center = vec2(0.0);
uniform float radius = 32.0;
uniform float squash = 1.0;
// Inside this share of the radius: drawn after the ring.
uniform float inner = 0.55;
uniform vec4 head : source_color = vec4(1.0, 0.98, 0.91, 1.0);
uniform vec4 ember : source_color = vec4(0.74, 0.47, 0.35, 1.0);
uniform bool emissive = true;
uniform float seed = 0.0;
uniform float pixel = 2.0;

varying vec2 world;
varying vec2 origin;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	origin = MODEL_MATRIX[3].xy;
}

void fragment() {
	vec4 c = COLOR;  // the texel, already tinted (fx.gdshaderinc)
	vec2 cell = floor(world / pixel);
	if (c.a < bayer(cell)) {
		discard;
	}
	vec2 d = (cell + 0.5) * pixel - (origin + center);
	d.y /= squash;
	float order;
	if (order_mode == 0) {
		float r = length(d) / radius;
		// 0 at the front (toward the viewer), around clockwise.
		float angle = fract(atan(-d.x, d.y) / 6.2831853 + 1.0);
		float n = float(strokes);
		float s = floor(angle * n);
		float along = fract(angle * n);
		if (mod(s, 2.0) > 0.5) {
			along = 1.0 - along;
		}
		order = (mod(s * 3.0, n) + along) / n * 0.7;
		if (r < inner) {
			order = 0.7 + 0.28 * hash(floor(cell / 3.0) + seed);
		}
	} else {
		order = clamp(d.y / radius * 0.5 + 0.5, 0.0, 1.0) * 0.8 + hash(vec2(floor(cell.x / 2.0), seed)) * 0.2;
	}
	if (order > reveal) {
		discard;
	}
	float burn_order = noise(cell * 0.35 + seed) * 0.85 + bayer(cell) * 0.15;
	if (burn > 0.0 && burn_order < burn) {
		discard;
	}
	vec3 color = c.rgb;
	if (reveal < 1.0 && order > reveal - 0.07) {
		color = head.rgb;
	}
	if (burn > 0.0 && burn_order < burn + 0.1) {
		color = ember.rgb;
	}
	COLOR = vec4(color, fx_alpha(emissive));
}
