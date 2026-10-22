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

varying vec2 local;

void vertex() {
	local = VERTEX;  // the node sits on the grid (PixelDraw.snap): its cells are the world's
}

void fragment() {
	vec2 cell = floor(local / 2.0);
	vec2 p = (cell + 0.5) * 2.0;
	float d = length(p);
	float t = progress;
	float tt = stepped_time(TIME, fps);
	// Welling out: the edge reaches the radius in the first eighth (ease out), then crawls.
	float grow = 1.0 - pow(1.0 - min(t / 0.13, 1.0), 3.0);
	vec2 dir = p / max(d, 0.001);
	float lump = noise(dir * max(radius / 9.0, 2.0) + vec2(seed, tt * 0.5));
	// The rim lies just inside the radius (never wider than the area it hit), in lumps.
	float edge = radius * (0.35 + 0.65 * grow) - 1.0 - floor(lump * 3.0) * 2.0;
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
