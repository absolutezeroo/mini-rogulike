// Whole-screen look, applied over the world (not the HUD), in the game's pixel grid. The one
// shader of the game that reads the screen (one copy of it per frame, ScreenEffects): every
// distortion of space is done here, from a short list of stamps (DistortionStamp), never by a
// second screen-reading node.
//  - Space: heat rising above fire, a cold shimmer through a frost nova, ripples pulled in around
//    shadow and arcane, a blast's shockwave, the biome's own heat: each art pixel of the screen
//    reads a whole number of art pixels away, on the world's grid, so the art stays crisp.
//  - Color: the floor's grading, saturation and contrast; emissive effects (the emissive mask in
//    the alpha, fx.gdshaderinc) keep most of their true colors.
//  - Light: a stepped glow of bright pixels (no blur), a one-frame flash (lightning), a
//    dithered vignette, a blood moon; a chromatic aberration kick on big hits.
shader_type canvas_item;
render_mode blend_disabled;

#include "res://assets/shaders/fx.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float vignette : hint_range(0.0, 1.0) = 0.4;
uniform float saturation : hint_range(0.0, 2.0) = 1.12;
uniform float contrast : hint_range(0.5, 1.5) = 1.06;
// Size of one art pixel on screen, in UV (set by ScreenEffects from the camera zoom).
uniform vec2 art_pixel = vec2(0.00234, 0.00417);
// The world the screen shows: its top-left corner and its size, in world units (the camera).
uniform vec2 view_origin = vec2(0.0);
uniform vec2 view_size = vec2(853.0, 480.0);
// Brightness steps of the vignette (dithered between them).
uniform float vignette_steps = 4.0;
// In art pixels; pulsed by ScreenEffects.kick().
uniform float aberration = 0.0;
// The floor's mood (AmbienceDef, set by ScreenEffects.set_mood): shadows and highlights pulled
// toward two colors, bright things glowing, the air trembling with heat.
uniform vec3 shadow_tint : source_color = vec3(1.0);
uniform vec3 highlight_tint : source_color = vec3(1.0);
uniform float grade : hint_range(0.0, 1.0) = 0.0;
uniform float bloom : hint_range(0.0, 1.0) = 0.0;
uniform float haze : hint_range(0.0, 3.0) = 0.0;
// How much of the grading, saturation and moon emissive pixels are spared (1: all of it).
uniform float emissive_keep : hint_range(0.0, 1.0) = 0.75;
// The edges darken toward this color, beating like a heart; a great glow over the top (a
// blood moon...). Also from the mood.
uniform vec3 vignette_color : source_color = vec3(0.0);
uniform float vignette_pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 moon_color : source_color = vec4(1.0, 0.15, 0.1, 0.0);
// A one-frame flash (lightning): its color, alpha = strength (ScreenEffects.flash).
uniform vec4 flash : source_color = vec4(0.0);
// The distortion stamps (DistortionStamp), at most 8:
//   stamps[i] = world x, y, radius, strength (art pixels)
//   stamp_info[i] = kind (0 heat, 1 cold, 2 pull, 3 shock), height or width, seed, life left
uniform int stamp_count = 0;
uniform vec4 stamps[8];
uniform vec4 stamp_info[8];

// The four art pixels around (world units) a bright pixel glows into (bloom).
const vec2 GLOW_TAPS[4] = vec2[](vec2(2.0, 0.0), vec2(-2.0, 0.0), vec2(0.0, 2.0), vec2(0.0, -2.0));

// A heartbeat: two quick beats, then rest (0..1).
float heartbeat(float time) {
	float t = fract(time / 1.3);
	return max(exp(-pow(t * 14.0, 2.0)), 0.7 * exp(-pow((t - 0.2) * 14.0, 2.0)));
}

float wave(float x) {
	return sin(x) * 0.6 + sin(x * 2.3 + 1.7) * 0.4;
}

// Where the art pixel at `cell` (centre `p`, world units) reads from, in art pixels, for stamp
// `i`. Also adds to `crest` (a shockwave's faint bright front).
vec2 stamp_offset(int i, vec2 cell, vec2 p, inout float crest) {
	vec4 s = stamps[i];
	vec4 info = stamp_info[i];
	int kind = int(info.x + 0.5);
	vec2 local = p - s.xy;
	float t = stepped_time(TIME, 15.0);
	if (kind == 0) {
		// Heat: rows of art pixels sliding sideways above the fire, the waves climbing; weaker
		// toward the top and the sides, the edge ragged (dithered), never a smooth fade.
		float height = info.y;
		if (local.y > s.z * 0.25 || local.y < -height || abs(local.x) > s.z) {
			return vec2(0.0);
		}
		float up = clamp(-local.y / height, 0.0, 1.0);
		float side = abs(local.x) / s.z;
		if ((1.0 - side) * (1.0 - up * 0.6) < bayer(cell)) {
			return vec2(0.0);
		}
		float amount = s.w * (1.0 - up * 0.5) * info.w;
		return vec2(floor(wave(cell.y * 0.9 + t * 9.0 + info.z) * amount + 0.5), 0.0);
	}
	float r = length(local);
	if (r > s.z || r < 0.5) {
		return vec2(0.0);
	}
	if (kind == 1) {
		// Cold: facets of 3x3 art pixels catch the light askew, like ice: each shifted a pixel
		// one way, a few at a time, only on the nova's front.
		float band = 1.0 - abs(r / s.z - 0.75) * 3.0;
		vec2 facet = floor(cell / 3.0);
		float roll = hash(facet + floor(t * 8.0) * 7.31 + info.z);
		if (band <= 0.0 || roll > band * 0.3 * info.w) {
			return vec2(0.0);
		}
		float way = floor(hash(facet * 1.7 + roll) * 4.0);
		vec2 jitter = way < 1.0 ? vec2(1.0, 0.0) : (way < 2.0 ? vec2(-1.0, 0.0) : (way < 3.0 ? vec2(0.0, 1.0) : vec2(0.0, -1.0)));
		return jitter * max(floor(s.w + 0.5), 1.0);
	}
	vec2 out_dir = local / r;
	if (kind == 2) {
		// Pull: rings of the picture drawn in toward the heart (shadow, arcane), moving inward.
		float d = r / s.z;
		float ripple = wave(d * 9.0 + t * 8.0 + info.z);
		return floor(out_dir * ripple * s.w * (1.0 - d) * info.w + 0.5);
	}
	// Shock: a ring running out, pushing the picture outward, with a faint bright crest.
	float d = (r - info.y) / max(info.z, 1.0);
	float w = 1.0 - clamp(abs(d), 0.0, 1.0);
	if (w <= 0.0) {
		return vec2(0.0);
	}
	crest = max(crest, step(0.6, w) * info.w);
	return -floor(out_dir * s.w * w * w + 0.5);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// The art pixel this screen pixel shows, on the world's grid.
	vec2 world = view_origin + uv * view_size;
	vec2 cell = floor(world / 2.0);
	vec2 centre = (cell + 0.5) * 2.0;
	vec2 offset = vec2(0.0);
	float crest = 0.0;
	if (haze > 0.0) {
		// The biome's heat: rows of art pixels sliding sideways by whole pixels, in slow waves.
		offset.x += floor(wave(cell.y * 0.21 + TIME * 2.2) * wave(cell.y * 0.05 - TIME * 0.7) * haze + 0.5);
	}
	for (int i = 0; i < stamp_count; i++) {
		offset += stamp_offset(i, cell, centre, crest);
	}
	uv += offset * art_pixel;
	vec4 sampled;
	float shift = floor(aberration + 0.5);
	if (shift >= 1.0) {
		vec2 split = sign(uv - 0.5) * art_pixel * shift;
		sampled = texture(screen_texture, uv);
		sampled.r = texture(screen_texture, uv + split).r;
		sampled.b = texture(screen_texture, uv - split).b;
	} else {
		sampled = texture(screen_texture, uv);
	}
	vec3 color = sampled.rgb;
	// Emissive effects wrote the mark in their alpha (alpha 0: nothing was drawn there).
	float keep = (sampled.a > 0.2 && sampled.a < 0.5) ? emissive_keep : 0.0;
	if (bloom > 0.0) {
		// Stepped glow: a bright art pixel bleeds into the darker art pixels around it, a flat
		// rim one art pixel wide in its own color (never inside bright shapes, never a blur).
		vec3 glow = vec3(0.0);
		float best = 0.0;
		for (int i = 0; i < 4; i++) {
			vec3 near = texture(screen_texture, (centre + GLOW_TAPS[i] - view_origin) / view_size).rgb;
			float bright = max(near.r, max(near.g, near.b));
			if (bright > best) {
				best = bright;
				glow = near;
			}
		}
		float self_bright = max(color.r, max(color.g, color.b));
		if (best > 0.82 && self_bright < best - 0.3) {
			color += glow * (0.12 + 0.3 * bloom);
		}
	}
	color += vec3(0.08) * crest;
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	if (grade > 0.0) {
		vec3 tint = mix(shadow_tint, highlight_tint, smoothstep(0.12, 0.7, gray));
		color = mix(color, color * tint, grade * (1.0 - keep));
	}
	color = mix(vec3(gray), color, mix(saturation, max(saturation, 1.0), keep));
	color = (color - 0.5) * contrast + 0.5;

	// Vignette computed per art pixel, in flat dithered steps instead of a smooth gradient.
	vec2 screen_cell = floor(SCREEN_UV / art_pixel);
	vec2 centered = (screen_cell * art_pixel + art_pixel * 0.5 - 0.5) * vec2(1.0, 0.75);
	float beat = heartbeat(TIME) * vignette_pulse;
	float reach = 0.3 - beat * 0.08;
	float dark = smoothstep(reach, 0.75, length(centered)) * vignette * (1.0 + beat * 0.8);
	dark = floor(dark * vignette_steps + bayer(screen_cell)) / vignette_steps;
	if (moon_color.a > 0.0) {
		// The moon's glow from above the top of the screen, breathing slowly, in dithered steps.
		vec2 from_moon = (screen_cell * art_pixel - vec2(0.5, -0.25)) * vec2(1.6, 1.0);
		float glow = pow(clamp(1.0 - length(from_moon) / 0.85, 0.0, 1.0), 2.2);
		glow *= moon_color.a * (0.85 + 0.15 * sin(TIME * 0.7) + beat * 0.25) * (1.0 - keep);
		glow = floor(glow * 6.0 + bayer(screen_cell)) / 6.0;
		color = mix(color, color + moon_color.rgb * 0.55, glow);
		color = mix(color, moon_color.rgb * gray * 1.4, glow * 0.15);
	}
	color = mix(color, vignette_color, clamp(dark, 0.0, 1.0));
	// Lightning: one frame, the whole picture lifted toward the flash, bright parts most.
	color = mix(color, max(color, flash.rgb * (0.45 + gray)), flash.a);
	COLOR = vec4(color, 1.0);
}
