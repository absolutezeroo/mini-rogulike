// Rig shader, on the Visual node (children use the parent material).
//  - Hit flash: blends the sprite toward `flash_color` while keeping its shape (alpha).
//  - Dissolve: pixels vanish in a random order, with a glowing edge (deaths).
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_color : source_color = vec4(1.0, 0.85, 0.5, 1.0);

// Same value for every screen pixel of one art pixel, so the dissolve stays pixelated.
float pixel_noise(vec2 uv, vec2 pixel_size) {
	vec2 cell = floor(uv / pixel_size);
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
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
