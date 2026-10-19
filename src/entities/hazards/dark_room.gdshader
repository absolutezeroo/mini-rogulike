shader_type canvas_item;
render_mode unshaded;
// Darkness over a room, with a hole of light around the hero and soft edges at the doors.
// Stepped falloff, like the rest of the lighting.

uniform vec4 shade : source_color = vec4(0.01, 0.01, 0.03, 0.96);
uniform vec2 hero = vec2(0.0);
uniform float radius = 80.0;
uniform vec4 area = vec4(0.0);   // x, y, width, height in world space
uniform float edge = 24.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float d = distance(world_pos, hero);
	float seen = 1.0 - smoothstep(radius * 0.45, radius, d);
	vec2 inside = min(world_pos - area.xy, area.xy + area.zw - world_pos);
	float border = clamp(min(inside.x, inside.y) / edge, 0.0, 1.0);
	float a = shade.a * border * (1.0 - seen);
	a = floor(a * 6.0 + 0.5) / 6.0;
	COLOR = vec4(shade.rgb, a);
}
