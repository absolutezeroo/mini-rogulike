// Rig shader, on the Visual node (children use the parent material).
//  - Hit flash: blends the sprite toward `flash_color` while keeping its shape (alpha).
//  - Dissolve: pixels vanish in a random order, with a glowing edge (deaths).
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_color : source_color = vec4(1.0, 0.85, 0.5, 1.0);
// Rare monsters (MonsterRankDef): colors turned around the color wheel, and a gleam sweeping
// across the body in whole art pixels.
uniform float hue_shift : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer : hint_range(0.0, 1.0) = 0.0;

vec3 rotate_hue(vec3 color, float turns) {
	// In YIQ: brightness kept, the color turned.
	mat3 to_yiq = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312));
	mat3 to_rgb = mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703));
	vec3 yiq = to_yiq * color;
	float angle = turns * 6.2831853;
	float c = cos(angle);
	float s = sin(angle);
	yiq.yz = vec2(yiq.y * c - yiq.z * s, yiq.y * s + yiq.z * c);
	return clamp(to_rgb * yiq, 0.0, 1.0);
}

// Same value for every screen pixel of one art pixel, so the dissolve stays pixelated.
float pixel_noise(vec2 uv, vec2 pixel_size) {
	vec2 cell = floor(uv / pixel_size);
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	if (hue_shift > 0.0) {
		color.rgb = rotate_hue(color.rgb, hue_shift);
	}
	if (shimmer > 0.0) {
		vec2 cell = floor(UV / TEXTURE_PIXEL_SIZE);
		float band = fract((cell.x + cell.y) * 0.04 - TIME * 0.45);
		color.rgb += vec3(0.55) * step(band, 0.06) * shimmer * color.a;
	}
	color.rgb = mix(color.rgb, flash_color.rgb, flash_amount);
	if (dissolve > 0.0) {
		float noise = pixel_noise(UV, TEXTURE_PIXEL_SIZE);
		if (noise < dissolve) {
			color.a = 0.0;
		} else if (noise < dissolve + 0.12) {
			color.rgb = dissolve_color.rgb;
		}
	}
	COLOR = color;
}
