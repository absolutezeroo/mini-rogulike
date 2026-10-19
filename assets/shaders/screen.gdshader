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
// The floor's mood (AmbienceDef, set by ScreenEffects.set_mood): shadows and highlights pulled
// toward two colors, bright things glowing, the air trembling with heat.
uniform vec3 shadow_tint : source_color = vec3(1.0);
uniform vec3 highlight_tint : source_color = vec3(1.0);
uniform float grade : hint_range(0.0, 1.0) = 0.0;
uniform float bloom : hint_range(0.0, 1.0) = 0.0;
uniform float haze : hint_range(0.0, 3.0) = 0.0;
// The edges darken toward this color, beating like a heart; a great glow over the top (a
// blood moon...). Also from the mood.
uniform vec3 vignette_color : source_color = vec3(0.0);
uniform float vignette_pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec4 moon_color : source_color = vec4(1.0, 0.15, 0.1, 0.0);

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// 4x4 ordered dither threshold for a pixel cell.
float bayer(vec2 cell) {
	int index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	return (BAYER[index] + 0.5) / 16.0;
}

// A heartbeat: two quick beats, then rest (0..1).
float heartbeat(float time) {
	float t = fract(time / 1.3);
	return max(exp(-pow(t * 14.0, 2.0)), 0.7 * exp(-pow((t - 0.2) * 14.0, 2.0)));
}

float wave(float x) {
	return sin(x) * 0.6 + sin(x * 2.3 + 1.7) * 0.4;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (haze > 0.0) {
		// Heat: rows of art pixels sliding sideways by whole pixels, in slow waves.
		float row = floor(uv.y / art_pixel.y);
		float shift = floor(wave(row * 0.21 + TIME * 2.2) * wave(row * 0.05 - TIME * 0.7) * haze + 0.5);
		uv.x += shift * art_pixel.x;
	}
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
	if (bloom > 0.0) {
		// Bright neighbours bleed into this pixel: lights, fire and gold glow.
		vec3 glow = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			float angle = float(i) * 0.785398;
			vec2 offset = vec2(cos(angle), sin(angle)) * art_pixel * (i % 2 == 0 ? 2.0 : 4.0);
			vec3 near = texture(screen_texture, uv + offset).rgb;
			float bright = max(near.r, max(near.g, near.b));
			glow += near * max(bright - 0.86, 0.0) * 4.0;  // only what really shines
		}
		color += glow * bloom * 0.35;
	}
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	if (grade > 0.0) {
		vec3 tint = mix(shadow_tint, highlight_tint, smoothstep(0.12, 0.7, gray));
		color = mix(color, color * tint, grade);
	}
	color = mix(vec3(gray), color, saturation);
	color = (color - 0.5) * contrast + 0.5;

	// Vignette computed per art pixel, in flat dithered steps instead of a smooth gradient.
	vec2 cell = floor(uv / art_pixel);
	vec2 centered = (cell * art_pixel + art_pixel * 0.5 - 0.5) * vec2(1.0, 0.75);
	float beat = heartbeat(TIME) * vignette_pulse;
	float reach = 0.3 - beat * 0.08;
	float dark = smoothstep(reach, 0.75, length(centered)) * vignette * (1.0 + beat * 0.8);
	dark = floor(dark * vignette_steps + bayer(cell)) / vignette_steps;
	if (moon_color.a > 0.0) {
		// The moon's glow from above the top of the screen, breathing slowly, in dithered steps.
		vec2 from_moon = (cell * art_pixel - vec2(0.5, -0.25)) * vec2(1.6, 1.0);
		float glow = pow(clamp(1.0 - length(from_moon) / 0.85, 0.0, 1.0), 2.2);
		glow *= moon_color.a * (0.85 + 0.15 * sin(TIME * 0.7) + beat * 0.25);
		glow = floor(glow * 6.0 + bayer(cell)) / 6.0;
		color = mix(color, color + moon_color.rgb * 0.55, glow);
		color = mix(color, moon_color.rgb * gray * 1.4, glow * 0.15);
	}
	COLOR = vec4(mix(color, vignette_color, clamp(dark, 0.0, 1.0)), 1.0);
}
