shader_type canvas_item;
render_mode blend_disabled;
// Fades a sprite out by ordered dithering on its own texels instead of alpha: every art pixel is
// fully there or gone (a 4x4 Bayer matrix against `fade`), so a dissipating effect never shows
// colors from no palette or half-transparent pixels. Alpha is hard (1-bit) too, so blending is
// off: an `emissive` sheet writes the emissive mark in its alpha (fx.gdshaderinc), which keeps
// its colors out of the floor's grading (screen.gdshader).

#include "res://assets/shaders/fx.gdshaderinc"

uniform float fade : hint_range(0.0, 1.0) = 1.0; // 1 = all there, 0 = gone
uniform bool emissive = false;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec2 p = floor(UV / TEXTURE_PIXEL_SIZE);
	if (t.a < 0.5 || fade <= bayer(p)) {
		discard;
	}
	// COLOR comes in as the texel already tinted (modulate): never multiply the texture by it
	// again (that squares the ramp's colors, darker). Its alpha is ignored: there or not.
	COLOR = vec4(COLOR.rgb, fx_alpha(emissive));
}
