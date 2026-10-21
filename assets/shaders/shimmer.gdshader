shader_type canvas_item;
render_mode blend_disabled;
// A column of light shimmering (Smite's holy column): bands of light a step brighter climbing it
// at 12 fps, its sides flickering a pixel in and out; dithered away at the end of its life like
// every sheet (`fade`). Only the ramp's colors, hard pixels.

#include "res://assets/shaders/fx.gdshaderinc"

uniform vec4 ramp[5];  // FxLook.five(element), as they are
uniform bool emissive = true;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float fps = 12.0;
// Texels between two bands climbing the column, and their speed (texels per second).
uniform float band_gap = 9.0;
uniform float climb = 40.0;

int ramp_index(vec3 color) {
	int best = 0;
	float nearest = 10.0;
	for (int i = 0; i < 5; i++) {
		vec3 d = color - ramp[i].rgb;
		float distance = dot(d, d);
		if (distance < nearest) {
			nearest = distance;
			best = i;
		}
	}
	return best;
}

void fragment() {
	vec2 one = TEXTURE_PIXEL_SIZE;
	vec2 texel = floor(UV / one);
	vec2 at = (texel + 0.5) * one;
	vec4 c = texture(TEXTURE, at);
	if (c.a < 0.5 || fade <= bayer(texel)) {
		discard;
	}
	float t = stepped_time(TIME, fps);
	int index = ramp_index(c.rgb);
	bool left = texture(TEXTURE, at - vec2(one.x, 0.0)).a < 0.5;
	bool right = texture(TEXTURE, at + vec2(one.x, 0.0)).a < 0.5;
	if (left != right && hash(vec2(texel.y, floor(t * fps))) < 0.22) {
		discard;  // the column's edge flickering
	}
	// A band of light climbing.
	if (mod(texel.y + t * climb, band_gap) < 1.5 && index >= 1) {
		index -= 1;
	}
	COLOR = vec4(ramp[index].rgb, fx_alpha(emissive));
}
