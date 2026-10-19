shader_type canvas_item;
// A monster's warning, on a square around it turned toward its aim (+x):
//   shape 0: a circle (an area skill), 1: a cone (a melee swing), 2: a line (a shot).
// Faint hazard stripes crawl over the zone, a solid rim outlines it, and a stronger fill grows
// from the monster as the attack comes (`progress` 0..1), flashing just before it lands.

uniform int shape = 0;
uniform float radius = 60.0;
uniform float half_angle = 0.8;
uniform float line_width = 10.0;
uniform float progress = 0.0;
uniform vec4 color : source_color = vec4(1.0, 0.22, 0.2, 1.0);
uniform float pixel = 2.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec2 p = (floor(local / pixel) + 0.5) * pixel;
	float r = length(p);
	float rim;    // distance to the zone's edge, in pixels (negative: outside)
	float depth;  // how far out from the monster, 0..1 (for the growing fill)
	if (shape == 0) {
		rim = radius - r;
		depth = r / radius;
	} else if (shape == 1) {
		float angle = abs(atan(p.y, p.x));
		rim = min(radius - r, (half_angle - angle) * max(r, 1.0));
		depth = r / radius;
	} else {
		rim = min(min(radius - p.x, p.x), line_width * 0.5 - abs(p.y));
		depth = p.x / radius;
	}
	if (rim < 0.0) {
		discard;
	}
	float stripes = step(0.5, fract((p.x - p.y) / 14.0 - TIME * 1.2));
	float alpha = 0.14 + 0.08 * stripes;
	alpha += step(depth, progress) * (0.18 + 0.12 * progress);
	alpha = mix(alpha, 0.85, step(rim, pixel * 1.5) * (0.45 + 0.55 * progress));
	// The last instant: a flash.
	alpha += step(0.85, progress) * 0.25 * (0.5 + 0.5 * sin(TIME * 40.0));
	COLOR = vec4(mix(color.rgb, vec3(1.0, 0.85, 0.8), step(rim, pixel * 1.5) * progress * 0.4), alpha * color.a);
}
