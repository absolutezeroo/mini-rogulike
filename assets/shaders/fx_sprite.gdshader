shader_type canvas_item;
render_mode blend_disabled;
// Effects drawn in code (`_draw()`: nova pieces, shots, flames) on the art's grid: anything drawn
// translucent is dithered per art pixel of the world (each pixel there or not), never blended,
// and an emissive one writes the emissive mask in its alpha (fx.gdshaderinc) so the floor's
// grading leaves most of its colors alone.

#include "res://assets/shaders/fx.gdshaderinc"

uniform bool emissive = false;
uniform float pixel = 2.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = COLOR;  // the texel, already tinted (fx.gdshaderinc)
	if (c.a < bayer(floor(world / pixel))) {
		discard;
	}
	COLOR = vec4(c.rgb, fx_alpha(emissive));
}
