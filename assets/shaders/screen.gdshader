// Whole-screen look, applied over the world (not the HUD):
// soft vignette, a little contrast and saturation, and a chromatic aberration kick on big hits.
shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float saturation : hint_range(0.0, 2.0) = 1.12;
uniform float contrast : hint_range(0.5, 1.5) = 1.06;
// In screen pixels; pulsed by ScreenEffects.kick().
uniform float aberration = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 color;
	if (aberration > 0.01) {
		vec2 shift = (uv - 0.5) * SCREEN_PIXEL_SIZE * aberration * 2.0;
		color.r = texture(screen_texture, uv + shift).r;
		color.g = texture(screen_texture, uv).g;
		color.b = texture(screen_texture, uv - shift).b;
	} else {
		color = texture(screen_texture, uv).rgb;
	}
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(gray), color, saturation);
	color = (color - 0.5) * contrast + 0.5;
	vec2 centered = (uv - 0.5) * vec2(1.0, 0.75);
	float dark = smoothstep(0.32, 0.75, length(centered)) * vignette;
	COLOR = vec4(color * (1.0 - dark), 1.0);
}
