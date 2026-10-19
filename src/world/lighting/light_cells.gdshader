shader_type canvas_item;
// The floor's light, one pixel per cell (half a tile), drawn into a small viewport that the
// LightField stretches over the floor (multiplied, nearest: flat steps). Lights that stay put
// come baked (`baked`); moving ones are added here, blocked by walls.

uniform sampler2D baked : filter_nearest;  // rgb: the lamp's color, a: its level / 15
uniform sampler2D walls : filter_nearest;  // r: 0 open, 0.5 cliff face, 1 plateau
uniform sampler2D ramp : filter_nearest;   // 16 x 1: the color of each level
uniform vec2 grid = vec2(1.0);
uniform float ambient_level = 15.0;
uniform float tint_strength = 0.4;
uniform int light_count = 0;
uniform vec4 lights[24];        // x, y (cell centre), level, 0
uniform vec4 light_colors[24];  // the lamp's color, brightest channel at 1

bool is_wall(vec2 cell) {
	return texture(walls, cell / grid).r > 0.25;
}

// True if a wall stands between the two cell centres. The wall tile `to` is on (two cells
// each way) doesn't count: a wall catches the light on its whole tile, its cliff face.
bool blocked(vec2 from, vec2 to) {
	vec2 d = from - to;
	vec2 tile = floor(to / 2.0);
	int steps = int(ceil(max(abs(d.x), abs(d.y))));
	for (int k = 1; k < steps; k++) {
		vec2 p = floor(to + d * (float(k) / float(steps)));
		if (is_wall(p + 0.5) && floor(p / 2.0) != tile) {
			return true;
		}
	}
	return false;
}

void fragment() {
	vec2 cell = floor(UV * grid) + 0.5;
	vec4 b = texture(baked, cell / grid);
	float level = floor(b.a * 15.0 + 0.5);
	vec3 tint = b.rgb;
	// The plateau stays in the floor's own light.
	int count = texture(walls, cell / grid).r > 0.75 ? 0 : light_count;
	for (int i = 0; i < count; i++) {
		vec2 at = lights[i].xy;
		float lit = lights[i].z - floor(length(at - cell) * 0.5);  // one level less per tile
		if (lit > level && !blocked(at, cell)) {
			level = lit;
			tint = light_colors[i].rgb;
		}
	}
	float strength = 0.0;
	if (level > ambient_level) {
		strength = tint_strength * (level - ambient_level) / max(15.0 - ambient_level, 1.0);
	}
	level = max(level, ambient_level);
	vec3 color = texture(ramp, vec2((level + 0.5) / 16.0, 0.5)).rgb;
	COLOR = vec4(color * mix(vec3(1.0), tint, strength), 1.0);
}
