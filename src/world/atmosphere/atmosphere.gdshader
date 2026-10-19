shader_type canvas_item;
render_mode unshaded;
// The air of a floor, drawn over it in world space (it stays put while the camera moves), in
// 2x2 art pixels with ordered dithering, never blurry:
//   - leaf shadows drifting over the floor (canopy),
//   - low mist creeping over the floor,
//   - light dancing as if reflected by water (caustics),
//   - shafts of light falling from above (rays), over floor and walls alike.
// `floor_mask` (one texel per cell) keeps the ground effects off the wall tops.

uniform sampler2D floor_mask : filter_nearest;
uniform vec2 cells = vec2(1.0);
uniform float cell_size = 32.0;
uniform float pixel = 2.0;

uniform float canopy = 0.0;
uniform vec4 mist_color : source_color = vec4(0.0);
uniform vec2 mist_speed = vec2(8.0, 3.0);
uniform vec4 caustics_color : source_color = vec4(0.0);
uniform vec4 rays_color : source_color = vec4(0.0);
uniform float rays_angle = 0.4;
uniform float rays_density = 0.2;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer(vec2 cell) {
	int index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	return (BAYER[index] + 0.5) / 16.0;
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

float fbm(vec2 p) {
	return noise(p) * 0.65 + noise(p * 2.1 + 17.0) * 0.35;
}

bool on_floor(vec2 p) {
	ivec2 c = ivec2(floor(p / cell_size));
	if (c.x < 0 || c.y < 0 || float(c.x) >= cells.x || float(c.y) >= cells.y) {
		return false;
	}
	return texelFetch(floor_mask, c, 0).r > 0.5;
}

// Paints `layer` over `base` (plain alpha compositing).
vec4 over(vec4 base, vec4 layer) {
	float a = layer.a + base.a * (1.0 - layer.a);
	vec3 rgb = a > 0.0 ? (layer.rgb * layer.a + base.rgb * base.a * (1.0 - layer.a)) / a : vec3(0.0);
	return vec4(rgb, a);
}

void fragment() {
	vec2 p = (floor(world / pixel) + 0.5) * pixel;
	vec2 art = floor(world / pixel);
	float dither = bayer(art);
	bool ground = on_floor(p);
	vec4 c = vec4(0.0);

	if (canopy > 0.0 && ground) {
		float leaves = fbm(p / 70.0 + vec2(TIME * 0.05, TIME * 0.02));
		float shade = smoothstep(0.52, 0.62, leaves) * canopy;
		if (shade > dither) {
			c = over(c, vec4(0.05, 0.08, 0.02, 0.32));
		}
	}
	if (mist_color.a > 0.0 && ground) {
		float m = fbm(p / 110.0 + TIME * mist_speed / 110.0);
		m = m * 0.7 + fbm(p / 45.0 - TIME * mist_speed / 60.0) * 0.3;
		float amount = smoothstep(0.42, 0.75, m);
		if (amount > dither) {
			c = over(c, vec4(mist_color.rgb, mist_color.a * (0.5 + 0.5 * amount)));
		}
	}
	if (caustics_color.a > 0.0 && ground) {
		vec2 q = p / 34.0;
		float a = noise(q + vec2(TIME * 0.35, TIME * 0.2));
		float b = noise(q * 1.3 - vec2(TIME * 0.25, -TIME * 0.3) + 5.0);
		float web = 1.0 - abs(a - b) * 6.0;
		if (web > 0.55 + dither * 0.4) {
			c = over(c, caustics_color);
		}
	}
	if (rays_color.a > 0.0) {
		vec2 down = vec2(sin(rays_angle), cos(rays_angle));
		vec2 across = vec2(down.y, -down.x);
		float s = dot(p, across);
		float t = dot(p, down);
		// Shafts: a few bands across, swaying slowly, fading in and out along their length.
		float band = noise(vec2(s / 46.0 + TIME * 0.04, 0.0)) * 0.7 + noise(vec2(s / 17.0 - TIME * 0.09, 3.0)) * 0.3;
		float shaft = smoothstep(1.0 - rays_density, 1.0 - rays_density * 0.4, band);
		shaft *= 0.55 + 0.45 * noise(vec2(t / 160.0 + TIME * 0.05, s / 300.0));
		float glow = shaft * (ground ? 1.0 : 0.55);
		if (glow > dither) {
			c = over(c, rays_color);
		}
	}
	if (c.a <= 0.0) {
		discard;
	}
	COLOR = c;
}
