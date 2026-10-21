shader_type canvas_item;
render_mode blend_disabled;
// A blow's arc (SwingVfx), drawn on a square around the attacker:
//   mode 0: a crescent sweeping over `arc` radians around `aim` (more than a turn for a spin),
//           its cutting edge bright, its body down the element's ramp, thinning toward the tail;
//   mode 1: a thrust, a streak shooting out along `aim` from `inner` (the hand, clear of the
//           wielder's body) to `radius`.
// The node is never turned: the shape turns with `aim`, but its pixels are 2x2 art pixels on
// the world's grid (like the art), so a diagonal swing has the same pixels as a straight one.
// `progress` moves the head (0..1), `fade` dissolves it pixel by pixel (ordered dithering).
// Colors are the steps of an element's ramp (`core` the bright edge, `light`, `body`, `edge`
// the dark inner rim); an enemy's blow adds the `danger` rim on its cutting edge.
//
// `matter` (docs/vfx.md, "Elemental attacks"): an element's blow is not a tinted steel arc, its
// edge breaks into what the element is made of (SwingVfx.matter_of picks it from the element's
// bit): 0 steel (as it always was), 1 fire (flame tongues licking off the cutting edge, the tail
// eaten into licks), 2 frost (ice crystals jutting from the edge, faceted lit and dark), 3 poison
// (green drips hanging under it, dripping longer as it goes), 4 storm (a jagged fork of the core
// running inside, the body flickering), 5 holy (glints in it, short rays off the edge), 6 smoke
// (shadow, spirit: drifting holes, wisps off the edge), 7 arcane (rune rhombi riding the arc),
// 8 spray (blood, water: droplets flung off the edge), 9 earth (crumbling blocks, chunks off it).
// The bits flying off it are SwingMatter's. Everything per art pixel, at 12 fps (`time`).

#include "res://assets/shaders/fx.gdshaderinc"

uniform float radius = 40.0;
uniform float thickness = 16.0;
uniform float arc = 2.0;
uniform float aim = 0.0;
uniform float progress = 0.0;
uniform float fade = 0.0;
uniform float trail = 0.75;
uniform float inner = 0.0;
uniform vec4 core : source_color = vec4(0.95, 0.92, 0.95, 1.0);
uniform vec4 light : source_color = vec4(0.78, 0.78, 0.78, 1.0);
uniform vec4 body : source_color = vec4(0.55, 0.55, 0.55, 1.0);
uniform vec4 edge : source_color = vec4(0.31, 0.28, 0.29, 1.0);
uniform vec4 danger : source_color = vec4(0.0);  // alpha 0: a hero's blow
uniform int mode = 0;
uniform float pixel = 2.0;
uniform int matter = 0;
uniform float time = 0.0;
uniform float seed = 0.0;
uniform bool emissive = false;

varying vec2 world;
varying vec2 origin;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	origin = MODEL_MATRIX[3].xy;
}

// The blow's shape at `p` (its own frame, +x = the aim): `along` 0 tail .. 1 head, `across`
// 0 cutting edge .. 1 inner side (outside 0..1: off the body), `out` world units beyond the
// cutting edge (negative inside), `col` a column index along the blow (2 art pixels wide).
// False when `p` is outside the swept part (before the tail, past the head).
bool shape(vec2 p, out float along, out float across, out float out_edge, out float col) {
	if (mode == 0) {
		float r = length(p);
		float start = -arc * 0.5;
		float head = start + arc * progress;
		float tail = max(head - min(arc * trail, 5.6), start);
		if (head <= tail) {
			return false;
		}
		// The angle unwrapped into [tail, tail + TAU): spins of more than a turn work.
		float angle = atan(p.y, p.x);
		angle += ceil((tail - angle) / 6.2831853) * 6.2831853;
		if (angle > head) {
			return false;
		}
		along = (angle - tail) / (head - tail);
		float width = thickness * (0.25 + 0.75 * along);
		across = (radius - r) / width;
		out_edge = r - radius;
		col = floor((angle - start) * radius / (pixel * 2.0));
	} else {
		float span = max(radius - inner, 1.0);
		float head = inner + span * progress;
		float tail = head - span * trail;
		if (p.x > head || p.x < tail || p.x < inner) {
			return false;
		}
		along = (p.x - tail) / max(head - tail, 1.0);
		float half_width = thickness * 0.5 * (0.2 + 0.8 * along);
		across = abs(p.y) / max(half_width, 1.0);
		out_edge = abs(p.y) - half_width;
		col = floor(p.x / (pixel * 2.0)) + (p.y < 0.0 ? 1000.0 : 0.0);
	}
	return true;
}

// The blow's frame of a world point.
vec2 frame_of(vec2 d) {
	float c = cos(aim);
	float s = sin(aim);
	return vec2(d.x * c + d.y * s, -d.x * s + d.y * c);
}

void fragment() {
	// The art pixel this fragment falls in, on the world's grid.
	vec2 cell = floor(world / pixel);
	vec2 d = (cell + 0.5) * pixel - origin;
	vec2 p = frame_of(d);
	float t12 = floor(time * 12.0);
	float along;
	float across;
	float out_edge;
	float col;
	bool swept = shape(p, along, across, out_edge, col);
	vec4 color = vec4(0.0);
	bool drawn = false;
	if (swept && across >= 0.0 && across <= 1.0) {
		// Thinning toward the tail and the inner side: dithered, never blurry.
		float presence = smoothstep(0.0, 0.4, along) * (1.0 - smoothstep(0.6, 1.0, across) * 0.6);
		float threshold = bayer(cell);
		if (matter == 1 || matter == 6) {
			// Fire and smoke: the tail is eaten in drifting patches (licks, wisps), not a screen.
			threshold = noise(cell * 0.45 + vec2(seed, t12 * (matter == 1 ? 0.6 : 0.25)));
		} else if (matter == 9) {
			threshold = hash(floor(cell / 2.0) + seed);  // earth crumbles by blocks
		}
		if (presence >= threshold && hash(cell) >= fade) {
			drawn = true;
			// Bands down the ramp from the cutting edge in; the tail cools a step or two.
			float step_down = (1.0 - along) * 1.6 + fade * 2.0;
			float band_at = across * 3.2 + step_down;
			if (matter == 2) {
				// Frost: facets, every other column a step darker (lit and shaded faces).
				band_at += mod(col, 2.0) * 0.9 - 0.3;
			} else if (matter == 4) {
				band_at += 1.2;  // storm: a violet body, so the white fork reads in it
			}
			float band = floor(band_at);
			color = band < 1.0 ? core : (band < 2.0 ? light : (band < 3.0 ? body : edge));
			if (along > 0.92 && across < 0.7 && matter != 4) {
				color = core;  // the head, all bright
			}
			if (matter == 4) {
				// Storm: a jagged fork of the core runs through it, the rest flickers a step.
				float zig = abs(fract(along * 4.0 + seed + t12 * 0.5) * 2.0 - 1.0);
				float target = 0.2 + 0.6 * floor(zig * 4.0) / 4.0;
				if (abs(across - target) < 0.14 && mod(t12, 4.0) != 3.0) {
					color = core;
				} else if (mod(t12, 3.0) == 1.0) {
					color = band < 2.0 ? body : edge;
				}
			} else if (matter == 5 && hash(cell + vec2(t12, seed)) > 0.93) {
				color = core;  // holy: glints catch in it
			} else if (matter == 7) {
				// Arcane: rune rhombi riding the arc, hollow, in the core.
				float length_px = (mode == 0 ? min(arc * trail, 5.6) * radius : (radius - inner) * trail) / pixel;
				float slot = floor(along * 5.0);
				float u = (fract(along * 5.0) - 0.5) * length_px / 5.0;
				float v = (across - 0.5) * thickness * (0.25 + 0.75 * along) / pixel;
				float diamond = abs(u) + abs(v);
				if (slot >= 1.0 && diamond >= 1.5 && diamond < 2.5) {
					color = core;
				}
			} else if (matter == 9 && hash(floor(cell / 2.0) + seed + 3.0) > 0.85) {
				color = edge;  // earth: dark cracks between the blocks
			}
		}
	}
	if (!drawn && swept && along < 0.95 && hash(cell) >= fade) {
		// Off the cutting edge (out_edge > 0) or under the inner side: the element's matter.
		float o = out_edge / pixel;  // art pixels beyond the edge
		float lick = hash(vec2(col, seed));
		if (matter == 1 && o > 0.0) {
			// Fire: tongues two pixels wide licking off the edge, each its own height,
			// changing 12 times a second; tallest in the middle of the trail.
			float tall = floor(hash(vec2(col, t12 + seed)) * 5.0) * smoothstep(0.05, 0.5, along) * (1.0 - fade);
			if (o <= tall) {
				drawn = true;
				float up = o / max(tall, 1.0);
				color = up < 0.34 ? light : (up < 0.7 ? body : edge);
			}
		} else if (matter == 2 && o > 0.0 && lick > 0.35) {
			// Frost: crystals jutting from the edge, sharp, lit on one face.
			float h = 1.0 + floor(hash(vec2(col, seed + 1.0)) * 3.0);
			float x = fract(mode == 0 ? (atan(p.y, p.x) * radius / (pixel * 2.0)) : p.x / (pixel * 2.0));
			if (o <= h * (1.0 - abs(x * 2.0 - 1.0)) + 0.5 && along > 0.15) {
				drawn = true;
				color = x < 0.5 ? core : body;
			}
		} else if (matter == 3 && lick > 0.55) {
			// Poison: drips hanging under the body (screen down), longer as the blow goes on.
			float drip = 1.0 + floor((lick - 0.55) * 9.0 * progress + fract(time * 2.0) * 1.5);
			for (float k = 1.0; k <= 5.0; k += 1.0) {
				if (k > drip) {
					break;
				}
				float a2;
				float c2;
				float o2;
				float col2;
				vec2 above = frame_of(d - vec2(0.0, k * pixel));
				if (shape(above, a2, c2, o2, col2) && c2 >= 0.0 && c2 <= 1.0) {
					drawn = true;
					color = k >= drip - 0.5 ? light : (k > 1.0 ? body : edge);
					break;
				}
			}
		} else if (matter == 5 && o > 0.0 && lick > 0.78 && o <= 3.0 && along > 0.3) {
			// Holy: short rays off the edge.
			drawn = true;
			color = o < 1.5 ? light : body;
		} else if (matter == 6 && o > 0.0) {
			// Smoke: wisps curling off the edge, half there.
			float tall = floor(hash(vec2(col, floor(t12 / 2.0) + seed)) * 3.0);
			if (o <= tall && bayer(cell) < 0.55) {
				drawn = true;
				color = o < 1.5 ? light : body;
			}
		} else if (matter == 8 && o > 0.0 && o <= 4.0 && hash(cell + seed) > 0.86 && along < 0.85) {
			// Blood, water: droplets flung off the edge.
			drawn = true;
			color = o < 2.0 ? light : body;
		} else if (matter == 9 && o > 0.0 && o <= 3.0 && hash(floor(cell / 2.0) + seed + 7.0) > 0.86) {
			// Earth: chunks breaking off it.
			drawn = true;
			color = body;
		}
	}
	if (!drawn) {
		discard;
	}
	if (danger.a > 0.0 && out_edge > -pixel * 1.5 && out_edge <= 0.0 && along < 0.92) {
		color = danger;  // an enemy's blow: a warning rim on its edge
	}
	COLOR = vec4(color.rgb, fx_alpha(emissive && matter != 0));
}
