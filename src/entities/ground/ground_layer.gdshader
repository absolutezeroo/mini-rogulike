shader_type canvas_item;
// A ground over part of the floor (sand, moss...). `ground` is where it lies, smoothly scaled up
// from one texel per cell (rounded patches); noise roughens the edges so they look grown, not
// cut; a rim at the edge; the material's 16 px tile inside; all in 2x2 "art pixels".
// `floor_mask` (one texel per cell) cuts the walls out.

uniform sampler2D ground : filter_linear;
uniform sampler2D floor_mask : filter_nearest;
uniform vec2 cells = vec2(1.0);
uniform float cell_size = 32.0;
uniform sampler2D tiles : filter_nearest;
uniform vec2 tiles_size = vec2(16.0);
uniform vec4 fill = vec4(0.0, 0.0, 16.0, 16.0);
uniform vec4 fill_alt = vec4(0.0, 0.0, 16.0, 16.0);
uniform vec4 edge_color : source_color = vec4(0.5, 0.35, 0.2, 1.0);
uniform float roughness = 0.35;
uniform float pixel = 2.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
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

bool is_floor(ivec2 c) {
	if (c.x < 0 || c.y < 0 || float(c.x) >= cells.x || float(c.y) >= cells.y) {
		return false;
	}
	return texelFetch(floor_mask, c, 0).r > 0.5;
}

float ground_at(vec2 p) {
	float v = texture(ground, p / (cells * cell_size)).r;
	return v + (noise(p / 40.0) - 0.5) * roughness * 1.2 + (noise(p / 11.0) - 0.5) * roughness * 0.45;
}

void fragment() {
	vec2 p = (floor(local_pos / pixel) + 0.5) * pixel;  // the art pixel's middle
	ivec2 cell = ivec2(floor(p / cell_size));
	if (!is_floor(cell)) {
		discard;
	}
	if (ground_at(p) < 0.5) {
		discard;
	}
	// The rim: this pixel is ground, one a step away is not.
	float d = pixel * 1.5;
	bool rim = ground_at(p + vec2(d, 0.0)) < 0.5 || ground_at(p - vec2(d, 0.0)) < 0.5
		|| ground_at(p + vec2(0.0, d)) < 0.5 || ground_at(p - vec2(0.0, d)) < 0.5;
	if (rim) {
		COLOR = edge_color;
	} else {
		vec2 in_cell = fract(p / cell_size);
		vec4 region = hash(vec2(cell)) < 0.5 ? fill : fill_alt;
		vec2 uv = (region.xy + floor(in_cell * region.zw) + 0.5) / tiles_size;
		COLOR = texture(tiles, uv);
	}
	// The soft shadow at the foot of a cliff, as on the floor tiles.
	if (!is_floor(cell + ivec2(0, -1)) && fract(p.y / cell_size) * cell_size < 8.0) {
		COLOR.rgb *= 0.78;
	}
}
