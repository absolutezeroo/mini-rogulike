// Colored vignette on the screen edges. `intensity` 0 = invisible.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.9, 0.1, 0.1, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 from_center = (UV - 0.5) * vec2(1.0, 0.75);
	float edge = smoothstep(0.25, 0.62, length(from_center));
	COLOR = vec4(tint.rgb, edge * intensity);
}
