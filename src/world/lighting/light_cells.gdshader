shader_type canvas_item;
// The floor's light, one pixel per cell (half a tile), drawn into a small viewport that the
// LightField stretches over the floor (multiplied, nearest: flat steps). Lights that stay put
// come baked (`baked`); moving ones are added here, blocked by walls.

uniform sampler2D baked : filter_nearest;  // rgb: the lamp's color, a: its level / 15
uniform sampler2D walls : filter_nearest;  // r: 0 open, 0.5 cliff face, 1 plateau (in the mist)
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

bool is_mist(vec2 cell) {
	vec2 uv = cell / grid;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return true;
	}
	return texture(walls, uv).r > 0.75;
}

// Light reaching a plateau cell (in the mist) from `from`: over the floor and the cliff faces,
// then the mist, never out of it and in again (that is through a wall). Returns the mist cells
// crossed, -1 if blocked.
float through_mist(vec2 from, vec2 to) {
	vec2 d = from - to;
	int steps = int(ceil(max(abs(d.x), abs(d.y))));
	float misty = 1.0;
	bool entered = false;
	for (int k = steps - 1; k > 0; k--) {
		vec2 p = floor(to + d * (float(k) / float(steps))) + 0.5;
		if (is_mist(p)) {
			entered = true;
			misty += 1.0;
		} else if (entered) {
			return -1.0;
		}
	}
	return misty;
}

// True if a wall stands between the two cell centres. The cliff face `to` is on (its tile and
// the tile below it, two cells each) doesn't count: a face catches the light all the way up.
bool blocked(vec2 from, vec2 to) {
	vec2 d = from - to;
	vec2 tile = floor(to / 2.0);
	int steps = int(ceil(max(abs(d.x), abs(d.y))));
	for (int k = 1; k < steps; k++) {
		vec2 p = floor(to + d * (float(k) / float(steps)));
		vec2 t = floor(p / 2.0);
		bool own_face = t.x == tile.x && (t.y == tile.y || t.y == tile.y + 1.0);
		if (is_wall(p + 0.5) && !own_face) {
			return true;
		}
	}
	return false;
}

void fragment() {
	vec2 cell = floor(UV * grid) + 0.5;
	vec4 b = texture(baked, cell / grid);
	// Starting from the floor's own light: only lights that can brighten a cell are checked.
	float level = max(floor(b.a * 15.0 + 0.5), ambient_level);
	vec3 tint = b.rgb;
	// The plateau's mist catches the light from its edge, a level more lost every mist tile.
	bool misty = texture(walls, cell / grid).r > 0.75;
	for (int i = 0; i < light_count; i++) {
		vec2 at = lights[i].xy;
		float lit = lights[i].z - floor(length(at - cell) * 0.5);  // one level less per tile
		if (lit <= level) {
			continue;
		}
		if (misty) {
			float crossed = through_mist(at, cell);
			if (crossed < 0.0) {
				continue;
			}
			lit -= floor(crossed * 0.5);
			if (lit <= level) {
				continue;
			}
		} else if (blocked(at, cell)) {
			continue;
		}
		level = lit;
		tint = light_colors[i].rgb;
	}
	float strength = 0.0;
	if (level > ambient_level) {
		strength = tint_strength * (level - ambient_level) / max(15.0 - ambient_level, 1.0);
	}
	level = max(level, ambient_level);
	vec3 color = texture(ramp, vec2((level + 0.5) / 16.0, 0.5)).rgb;
	COLOR = vec4(color * mix(vec3(1.0), tint, strength), 1.0);
}
