shader_type canvas_item;
render_mode blend_disabled;
// Flame tongues on a flame sheet (FlameVfx: braziers; a campfire's flames): the sheet's own
// frames give the shape, and a stepped noise scrolling up through it (at 12 fps, per texel)
// moves the heat inside: tongues of a step hotter or cooler on the fire's ramp climbing it, the
// dark tips flickering away. Never a pixel outside the frame's flame (copies of a flame
// overlap). Only the ramp's colors, hard pixels.

#include "res://assets/shaders/fx.gdshaderinc"

// The fire's ramp, core to edge (VfxElementDef.ramp).
uniform vec4 ramp[5];  // FxLook.five(element), as they are
uniform bool emissive = true;
uniform float fps = 12.0;
// How fast the heat climbs, texels per second.
uniform float climb = 7.0;

varying vec2 origin;

void vertex() {
	origin = MODEL_MATRIX[3].xy;
}

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
	vec2 texel = floor(UV / TEXTURE_PIXEL_SIZE);
	vec2 one = TEXTURE_PIXEL_SIZE;
	vec2 at = (texel + 0.5) * one;
	vec4 c = texture(TEXTURE, at);
	float seed = hash(floor(origin / 8.0)) * 31.0;
	float t = stepped_time(TIME, fps);
	// Heat climbing: narrow tongues (stretched up), moving up the flame.
	float heat = noise(vec2(texel.x * 0.7 + seed, texel.y * 0.4 + t * climb * 0.4));
	if (c.a < 0.5) {
		discard;  // never outside its frame's flame: copies of it overlap
	}
	int index = ramp_index(c.rgb);
	vec4 above = texture(TEXTURE, at - vec2(0.0, one.y));
	if (above.a < 0.5 && index >= 3 && heat < 0.3) {
		discard;  // the tip eaten: the flame's edge flickers
	}
	// Hotter or cooler patches climbing through it, a step at most; the white heart stays.
	if (index >= 1) {
		index += heat > 0.62 ? -1 : (heat < 0.3 ? 1 : 0);
	}
	index = clamp(index, 0, 4);
	COLOR = vec4(ramp[index].rgb, fx_alpha(emissive));
}
