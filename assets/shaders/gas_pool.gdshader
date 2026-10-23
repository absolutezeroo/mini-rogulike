shader_type canvas_item;
render_mode blend_disabled;
// A pool of venomous gas lying on the ground (GasPoolVfx: poison's novas, Spore Cloud, Toxic
// Bloom). One cloud, not a ring of lumps: it wells out to its radius in the first eighth of its
// life, lies there churning, then sinks and thins away. Its rim is where the area ends (the
// telegraph's circle): a crisp band of the ramp's brightest steps on top, the dark edge under
// it where it sags, so it reads on the desert as on the moss; its body is the murk with patches
// welling a step greener and holes the floor shows through, drifting (gas, not a carpet). Every
// value per art pixel of the world's grid, time stepped, only the ramp and its residue
// (docs/vfx.md, "Shaders").
// The same gas lies along a trail (a dash: `shape` 1, a segment) or an arc (a sweep: `shape` 2):
// then `radius` is how far it reaches either side of that spine, every pixel reads its distance
// to the nearest point of the spine instead of the centre, and the gas wells out along it from
// its start to its end over the first `sweep` of its life.

#include "res://assets/shaders/fx.gdshaderinc"

// The poison ramp, core to edge (FxLook.five), and its residue (the murk).
uniform vec4 ramp[5];
uniform vec4 residue : source_color = vec4(0.37, 0.44, 0.38, 1.0);
uniform float radius = 40.0;
// 0 -> 1 over its life (GasPoolVfx).
uniform float progress = 0.0;
uniform float seed = 0.0;
uniform bool emissive = true;
uniform float fps = 8.0;
// 0: a disc around the node; 1: along the segment from -axis to +axis; 2: along the arc of
// `arc_radius` around the node, from the angle `arc_from` over `arc_span` (radians).
uniform int shape = 0;
uniform vec2 axis = vec2(0.0);
uniform float arc_radius = 0.0;
uniform float arc_from = 0.0;
uniform float arc_span = 0.0;
// The share of its life the gas takes to well out from the spine's start to its end.
uniform float sweep = 0.0;

varying vec2 local;

void vertex() {
	local = VERTEX;  // the node sits on the grid (PixelDraw.snap): its cells are the world's
}

// The point of the pool's spine nearest `p` (xy) and how far along the spine it lies (z, 0..1):
// the centre for a disc.
vec3 spine(vec2 p) {
	if (shape == 1) {
		vec2 from = -axis;
		float along = clamp(dot(p - from, axis * 2.0) / max(dot(axis, axis) * 4.0, 0.001), 0.0, 1.0);
		return vec3(from + axis * 2.0 * along, along);
	}
	if (shape == 2) {
		float rel = mod(atan(p.y, p.x) - arc_from, 6.28318);
		if (rel > arc_span) {
			rel = (rel - arc_span < 6.28318 - rel) ? arc_span : 0.0;  // the nearer end
		}
		float angle = arc_from + rel;
		return vec3(vec2(cos(angle), sin(angle)) * arc_radius, rel / max(arc_span, 0.001));
	}
	return vec3(0.0);
}

void fragment() {
	vec2 cell = floor(local / 2.0);
	vec3 nearest = spine((cell + 0.5) * 2.0);
	vec2 p = (cell + 0.5) * 2.0 - nearest.xy;  // from the spine (the centre for a disc)
	float d = length(p);
	// Along a trail or an arc, each part of it wells out a little after the one before.
	float t = (progress - nearest.z * sweep) / (1.0 - sweep);
	if (t < 0.0) {
		discard;
	}
	float tt = stepped_time(TIME, fps);
	// Welling out: the edge reaches the radius in the first eighth (ease out), then crawls.
	float grow = 1.0 - pow(1.0 - min(t / 0.13, 1.0), 3.0);
	vec2 dir = p / max(d, 0.001);
	float lump = noise(dir * max(radius / 9.0, 2.0) + nearest.xy * 0.12 + vec2(seed, tt * 0.5));
	// The rim lies just inside the radius (never wider than the area it hit), in lumps (shallower
	// on a thin trail).
	float edge = radius * (0.35 + 0.65 * grow) - 1.0 - floor(lump * clamp(radius / 10.0, 1.0, 3.0)) * 2.0;
	if (d > edge + 2.0) {
		discard;
	}
	float sink = clamp((t - 0.45) / 0.55, 0.0, 1.0);  // the last half: sinking, thinning away
	float churn = noise(cell * 0.3 + vec2(seed * 1.3, tt * 1.6));
	vec3 color;
	if (d > edge) {
		// The dark edge where it sags (its lower side), outlining it on bright floors.
		if (p.y < radius * 0.1 * (dir.x * dir.x) - 2.0 || hash(cell + seed) < sink * 1.3) {
			discard;
		}
		color = ramp[4].rgb;
	} else if (d > edge - 2.0) {
		// The rim: a sickly glow, its brightest steps on top, greener underneath; it breaks up
		// pixel by pixel as the gas sinks.
		if (hash(cell + seed * 2.0) < sink * 1.15 - 0.05) {
			discard;
		}
		if (churn > 0.72 && p.y < 0.0) {
			color = ramp[0].rgb;
		} else if (p.y < radius * 0.3 || churn > 0.5) {
			color = ramp[1].rgb;
		} else {
			color = ramp[2].rgb;
		}
	} else {
		// The body: low-lying gas, its wisps drawn out sideways (it crawls along the ground),
		// the floor showing through between them, more toward the middle and as it thins; the
		// murk, patches welling a step greener, the deep green where it is thickest; brighter
		// while it wells out.
		vec2 drift = vec2(tt * 1.4 + seed, -tt * 0.35);
		float wisps = noise(vec2(cell.x * 0.17, cell.y * 0.5) + drift);
		float middle = clamp(1.0 - d / max(edge, 1.0), 0.0, 1.0);
		float thin = 0.47 + sink * 0.65 + middle * 0.2 - (d > edge - 6.0 ? 0.22 : 0.0);
		if (wisps < thin) {
			discard;
		}
		color = residue.rgb;
		if (churn > 0.68) {
			color = t < 0.2 ? ramp[1].rgb : ramp[2].rgb;
		} else if (wisps > thin + 0.3) {
			color = ramp[3].rgb;  // the thick of a wisp
		}
	}
	COLOR = vec4(color, fx_alpha(emissive));
}
