shader_type canvas_item;
render_mode blend_disabled;
// Poison gas, so a cloud never reads as a bush on grass: its surface churns (patches a step
// lighter or darker welling up through it at 8 fps), its top catches a sickly glowing rim in the
// ramp's brightest steps, and its body lets the floor show through in small holes drifting
// with it (a cloud is not solid). Only the element's ramp, hard pixels (docs/vfx.md).

#include "res://assets/shaders/fx.gdshaderinc"

// The poison ramp, core to edge (VfxElementDef.ramp).
uniform vec4 ramp[5];  // FxLook.five(element), as they are
uniform bool emissive = true;
uniform float fps = 8.0;
// How much of the body the floor shows through, in drifting holes of a few pixels (0..1).
uniform float thin = 0.3;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// The ramp step `color` is, or -1 when it is not on the ramp (the murk, the residue).
int ramp_index(vec3 color) {
	for (int i = 0; i < 5; i++) {
		vec3 d = color - ramp[i].rgb;
		if (dot(d, d) < 0.002) {
			return i;
		}
	}
	return -1;
}

void fragment() {
	vec2 one = TEXTURE_PIXEL_SIZE;
	vec2 texel = floor(UV / one);
	vec2 at = (texel + 0.5) * one;
	vec4 c = texture(TEXTURE, at);
	if (c.a < 0.5) {
		discard;
	}
	vec2 cell = floor(world / 2.0);
	float t = stepped_time(TIME, fps);
	int index = ramp_index(c.rgb);
	bool top = texture(TEXTURE, at - vec2(0.0, one.y)).a < 0.5;
	bool side = texture(TEXTURE, at - vec2(one.x, 0.0)).a < 0.5 || texture(TEXTURE, at + vec2(one.x, 0.0)).a < 0.5;
	// Welling up: patches rising slowly through the cloud.
	float churn = noise(vec2(cell.x * 0.5, cell.y * 0.5 + t * 2.5));
	vec3 color = c.rgb;
	if (top) {
		// The glowing rim: the brightest steps, broken where the churn sinks.
		color = churn > 0.72 ? ramp[0].rgb : (churn > 0.4 ? ramp[1].rgb : ramp[2].rgb);
	} else {
		if (churn > 0.64) {
			// A patch welling up a step lighter (the grey murk turns a sickly green).
			color = index >= 2 ? ramp[index - 1].rgb : (index < 0 ? ramp[2].rgb : color);
		}
		// See-through: the floor shows through the body here and there, drifting with the gas.
		if (!side && noise(cell * 0.45 + vec2(t * 1.5, -t)) < thin) {
			discard;
		}
	}
	COLOR = vec4(color, fx_alpha(emissive));
}
