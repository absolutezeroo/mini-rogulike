shader_type canvas_item;
// The ceiling over the actors (CeilingLayer): its pieces are drawn as they are, except around a
// body (the hero, a monster), where they are dithered away per art pixel of the world (ordered
// dithering, docs/vfx.md section 1: no smooth alpha). Within `clear_radius` of a body's outline
// nothing is left; over the next `fade_band` the pixels come back one Bayer step at a time.

#include "res://assets/shaders/fx.gdshaderinc"

// xy: the body's feet, z: its radius, w: its height (feet to head).
uniform vec4 bodies[16];
uniform int body_count = 0;
uniform float clear_radius = 22.0;
uniform float fade_band = 26.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 cell = floor(world / 2.0);
	vec2 p = cell * 2.0 + 1.0;
	float near = 100000.0;
	for (int i = 0; i < body_count; i++) {
		vec4 b = bodies[i];
		// The body as a segment from its feet up to its head, `z` thick.
		float top = b.y - b.w;
		vec2 q = vec2(b.x, clamp(p.y, top, b.y));
		near = min(near, distance(p, q) - b.z);
	}
	float amount = clamp((near - clear_radius) / max(fade_band, 1.0), 0.0, 1.0);
	if (amount < 1.0 && bayer(cell) >= amount) {
		discard;
	}
}
