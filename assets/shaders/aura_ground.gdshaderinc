// An aura's glow on the ground at the hero's feet (AuraVfx, AuraDef): an oval lying on the floor,
// drawn per art pixel of the world's grid (never half a pixel), in its ramps' steps only (never a
// blend of two), sparse by ordered dithering so the floor and a telegraph read through it, its
// time stepped (`fps`), breathing a pixel wider on the beat (docs/vfx.md, "Auras").
//  - RAYS (0): a ring of light, a dithered glow fading outward, eight rays turning slowly.
//  - POOL (1): a pool of dark, its edge crawling, a darker step at the rim.
//  - EMBERS (2): a smouldering core of the accent's dark, a ring of embers flaring and dying in turn.
// The node draws one rectangle around its origin, the feet (AuraVfx).


// Its colors, steps of its ramps picked in its data (AuraDef "Colors"): the brightest (a ring, a
// ray), the glow, the dim (an outer glow, the pool's rim), the deep (the pool, the embers' core),
// and the spark (an ember flaring).
uniform vec4 bright : source_color;
uniform vec4 glow : source_color;
uniform vec4 dim : source_color;
uniform vec4 deep : source_color;
uniform vec4 spark : source_color;
uniform int pattern = 0;
uniform float radius = 18.0;  // world units, half the width
uniform float squash = 0.45;  // height over width
uniform float density = 0.55; // share of art pixels lit inside
uniform float breath = 2.4;   // seconds of a breath
uniform bool emissive = true;
uniform bool still = false;   // fewer effects: no breath, no turning, no flicker
uniform float fps = 10.0;
uniform float pixel = 2.0;

varying vec2 world;
varying vec2 origin;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	origin = MODEL_MATRIX[3].xy;
}

void fragment() {
	vec2 cell = floor(world / pixel);
	vec2 core = floor(origin / pixel + 0.5) * pixel;  // a crossing of the grid
	vec2 d = (cell + 0.5) * pixel - core;
	d.y /= squash;
	float r = length(d) / radius;  // 1 on the rim
	vec2 way = length(d) > 0.0 ? normalize(d) : vec2(1.0, 0.0);
	float t = still ? 0.0 : stepped_time(TIME, fps);
	float grow = still ? 0.0 : step(0.5, fract(t / breath)) * pixel / radius;
	float rim = 1.0 + grow;
	float ring = pixel / radius;  // an art pixel, in r
	float th = bayer(cell);
	vec3 color = vec3(0.0);
	bool on = false;
	if (pattern == 0) {
		// The ring of light.
		if (abs(r - rim) < ring * 0.6) {
			on = true;
			color = bright.rgb;
		}
		// Eight rays turning, from the inner glow out past the ring.
		float turn = fract(atan(way.y, way.x) / 6.2831853 * 8.0 + t * 0.06);
		if (!on && r > 0.3 && r < rim + ring * 2.5 && turn < 0.1 && th < density + 0.3) {
			on = true;
			color = r > rim ? bright.rgb : glow.rgb;
		}
		// The glow, thinning outward.
		if (!on && r < rim && th < density * (1.05 - r)) {
			on = true;
			color = r < 0.45 ? glow.rgb : dim.rgb;
		}
	} else if (pattern == 1) {
		// The edge crawls (noise round the circle, read on a circle: no seam).
		float crawl = noise(way * 2.2 + vec2(t * 0.7, -t * 0.4)) * 0.28;
		float edge = rim - crawl;
		if (r < edge && r > edge - ring * 1.2) {
			on = true;
			color = dim.rgb;
		} else if (r < edge && th < density * (1.1 - 0.6 * r)) {
			on = true;
			color = deep.rgb;
		}
		// A few drops of dark beyond the edge, coming and going.
		if (!on && r < rim + ring * 3.0 && r > edge && hash(cell + floor(t * 2.0)) > 0.93) {
			on = true;
			color = deep.rgb;
		}
	} else {
		// The smouldering core: the accent's dark, sparse.
		if (r < 0.72 * rim && th < density * 0.55 * (1.0 - r)) {
			on = true;
			color = deep.rgb;
		}
		// The ring of embers: each pixel flares and dies on its own beat.
		if (!on && r > 0.74 * rim && r < rim + ring * 0.5) {
			float flare = hash(cell + floor(t * 3.0 + hash(cell) * 3.0));
			if (flare > 1.0 - density * 0.85) {
				on = true;
				color = flare > 0.9 ? spark.rgb : (flare > 0.75 ? bright.rgb : glow.rgb);
			} else if (th < 0.35) {
				on = true;
				color = deep.rgb;
			}
		}
		// Sparks leaping off the ring.
		if (!on && r >= rim + ring * 0.5 && r < rim + ring * 3.0 && hash(cell + floor(t * 4.0)) > 0.96) {
			on = true;
			color = spark.rgb;
		}
	}
	if (!on) {
		discard;
	}
	COLOR = vec4(color, AURA_ALPHA);
}
