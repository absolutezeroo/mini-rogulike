// Whole-screen look, applied over the world (not the HUD), in the game's pixel grid:
// a dithered vignette, a little contrast and saturation, and a chromatic aberration kick
// on big hits that splits the colors by whole art pixels.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float vignette : hint_range(0.0, 1.0) = 0.4;
uniform float saturation : hint_range(0.0, 2.0) = 1.12;
uniform float contrast : hint_range(0.5, 1.5) = 1.06;
// Size of one art pixel on screen, in UV (set by ScreenEffects from the camera zoom).
uniform vec2 art_pixel = vec2(0.00234, 0.00417);
// Brightness steps of the vignette (dithered between them).
uniform float vignette_steps = 4.0;
// In art pixels; pulsed by ScreenEffects.kick().
uniform float aberration = 0.0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// 4x4 ordered dither threshold for a pixel cell.
float bayer(vec2 cell) {
	int index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	return (BAYER[index] + 0.5) / 16.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 color;
	float shift = floor(aberration + 0.5);
	if (shift >= 1.0) {
		vec2 offset = sign(uv - 0.5) * art_pixel * shift;
		color.r = texture(screen_texture, uv + offset).r;
		color.g = texture(screen_texture, uv).g;
		color.b = texture(screen_texture, uv - offset).b;
	} else {
		color = texture(screen_texture, uv).rgb;
	}
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(gray), color, saturation);
	color = (color - 0.5) * contrast + 0.5;

	// Vignette computed per art pixel, in flat dithered steps instead of a smooth gradient.
	vec2 cell = floor(uv / art_pixel);
	vec2 centered = (cell * art_pixel + art_pixel * 0.5 - 0.5) * vec2(1.0, 0.75);
	float dark = smoothstep(0.3, 0.75, length(centered)) * vignette;
	dark = floor(dark * vignette_steps + bayer(cell)) / vignette_steps;
	COLOR = vec4(color * (1.0 - clamp(dark, 0.0, 1.0)), 1.0);
}
