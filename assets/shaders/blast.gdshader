shader_type canvas_item;
render_mode unshaded;
// A burst of energy (an explosion, a shot bursting): it swells fast with a bright heart,
// cools down its element's ramp to the dark rim, hollows out and breaks into licks, then the
// element's residue (smoke, mist, dust) thins out. Turbulent noise, flat bands of the ramp's
// exact colors (BlastVfx sets them from a VfxElementDef: fire is white-hot, yellow, orange, a
// dark red rim, grey smoke), ordered dithering between them, all in 2x2 art pixels.

uniform float radius = 40.0;
uniform float progress = 0.0;  // 0 -> 1 over its life
uniform vec4 core : source_color = vec4(1.0, 0.96, 0.85, 1.0);
uniform vec4 light : source_color = vec4(1.0, 0.88, 0.55, 1.0);
uniform vec4 body : source_color = vec4(1.0, 0.68, 0.36, 1.0);
uniform vec4 rim : source_color = vec4(0.56, 0.24, 0.34, 1.0);
uniform vec4 residue : source_color = vec4(0.23, 0.21, 0.26, 1.0);  // alpha 0: none
uniform float seed = 0.0;
uniform float pixel = 2.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
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

void fragment() {
	vec2 cell = floor(local / pixel);
	vec2 p = (cell + 0.5) * pixel;
	float r = length(p) / radius;
	float t = progress;
	// Flames licking outward: noise on the angle and the distance, moving out.
	vec2 polar = vec2(atan(p.y, p.x) * 2.5, r * 3.0 - t * 4.0);
	float n = noise(polar + seed) * 0.6 + noise(polar * 2.3 + seed * 1.7) * 0.4;
	float front = (1.0 - pow(1.0 - min(t * 1.6, 1.0), 3.0)) * (0.85 + 0.3 * n);
	float hollow = max(t - 0.35, 0.0) * 1.4 * (0.7 + 0.6 * n);
	if (r > front || r < hollow) {
		discard;
	}
	// Hotter at the heart and early on; cooler at the rim and as it dies.
	float heat = (1.0 - r / max(front, 0.01)) * 0.8 + (1.0 - t) * 0.55 + (n - 0.5) * 0.35 - t * 0.35;
	heat += (bayer(cell) - 0.5) * 0.12;
	vec4 c;
	if (heat > 0.95) {
		c = core;
	} else if (heat > 0.72) {
		c = light;
	} else if (heat > 0.48) {
		c = body;
	} else if (heat > 0.25) {
		c = rim;
	} else {
		// The residue, thinning out.
		float smoke = 0.55 * (1.0 - t) * residue.a;
		if (smoke < bayer(cell + 3.0)) {
			discard;
		}
		c = vec4(residue.rgb, 1.0);
	}
	c.a = 1.0;
	COLOR = c;
}
