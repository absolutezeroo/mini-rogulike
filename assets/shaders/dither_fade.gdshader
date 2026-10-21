shader_type canvas_item;
// Fades a sprite out by ordered dithering on its own texels instead of alpha: every art pixel is
// fully there or gone (a 4x4 Bayer matrix against `fade`), so a dissipating effect never shows
// colors from no palette or half-transparent pixels. Alpha is hard (1-bit) too.

uniform float fade : hint_range(0.0, 1.0) = 1.0; // 1 = all there, 0 = gone

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	ivec2 p = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
	float threshold = (BAYER[(p.y & 3) * 4 + (p.x & 3)] + 0.5) / 16.0;
	if (t.a < 0.5 || fade <= threshold) {
		discard;
	}
	// The tint (modulate) colors it; its alpha is ignored: pixels are there or not.
	COLOR = vec4(t.rgb * COLOR.rgb, 1.0);
}
