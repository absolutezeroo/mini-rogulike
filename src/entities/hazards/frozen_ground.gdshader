shader_type canvas_item;
// Ice over a frozen room: pale frost with cracks and a few glints, in chunky pixels,
// fading out at the room's edges. Drawn on the ground, under everything that walks.

uniform vec4 area = vec4(0.0);   // x, y, width, height in world space
uniform float edge = 24.0;
uniform vec4 frost : source_color = vec4(0.78, 0.9, 1.0, 0.5);
uniform float pixel = 2.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Distance to the nearest edge between Voronoi cells: thin lines = cracks in the ice.
float cracks(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.0));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void fragment() {
	vec2 p = floor(world_pos / pixel) * pixel;
	float n = noise(p * 0.025) * 0.65 + noise(p * 0.08) * 0.35;
	vec3 color = mix(frost.rgb * 0.92, vec3(0.97, 0.99, 1.0), n);
	float a = frost.a * (0.75 + 0.4 * n);
	if (cracks(p * 0.022) < 0.05) {
		color = vec3(1.0);
		a = min(1.0, a + 0.3);
	}
	float glint = hash(floor(p / 6.0));
	if (glint > 0.993) {
		a = min(1.0, a + 0.6 * abs(sin(TIME * 2.5 + glint * 60.0)));
		color = vec3(1.0);
	}
	vec2 inside = min(world_pos - area.xy, area.xy + area.zw - world_pos);
	float border = clamp(min(inside.x, inside.y) / edge, 0.0, 1.0);
	border = floor(border * 4.0 + 0.5) / 4.0;
	COLOR = vec4(color, a * border);
}
