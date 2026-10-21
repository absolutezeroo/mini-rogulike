shader_type canvas_item;
render_mode blend_premul_alpha;
// The glow around an emissive core (GlowHalo), as pixel art: never a blur, two flat bands of
// added light in the element's darker steps (a stronger inner one, a fainter outer one), like a
// hand-posterized light: each band solid, the edge between two bands a checker one art pixel
// wide (ordered dithering), on the world's grid, breathing by a whole pixel or flickering (storm)
// at 12 fps.
// Premultiplied with alpha 0 = pure added light that leaves the alpha (the emissive mask) of
// what it shines on alone. The node draws one square around its origin: the core.

#include "res://assets/shaders/fx.gdshaderinc"

uniform float inner = 6.0;   // radius of the inner band, world units
uniform float outer = 10.0;  // radius of the outer band
uniform vec4 inner_color : source_color = vec4(0.9, 0.43, 0.23, 1.0);
uniform vec4 outer_color : source_color = vec4(0.56, 0.24, 0.34, 1.0);
// How much of each band's color is added (0..1).
uniform float inner_density : hint_range(0.0, 1.0) = 0.45;
uniform float outer_density : hint_range(0.0, 1.0) = 0.22;
// 0: breathing (a pixel wider on the beat), 1: flicker (storm: on, on, off), 2: still.
uniform int pulse = 0;
// Dims it (a bright floor needs less glow than the dark).
uniform float strength : hint_range(0.0, 1.0) = 1.0;
// Under 1: an oval lying on the floor (a campfire's glow on the flagstones).
uniform float squash = 1.0;
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
	float r = length(d);
	float seed = hash(core * 0.37);
	float t = stepped_time(TIME + seed * 5.0, 12.0);
	float grow = 0.0;
	if (pulse == 0) {
		grow = step(0.5, fract(t * 1.5 + seed)) * pixel;
	} else if (pulse == 1 && hash(vec2(floor(t * 12.0), seed)) > 0.7) {
		discard;  // a dark frame, then it strikes again
	}
	// The band: 2 inner, 1 outer, 0 none; a checker over the art pixel on each band's edge.
	float checker = step(0.5, bayer(cell));
	float edge_in = inner + grow;
	float edge_out = outer + grow;
	float band = r < edge_in - pixel ? 2.0 : (r < edge_in + pixel ? 1.0 + checker : (r < edge_out - pixel ? 1.0 : (r < edge_out + pixel ? checker : 0.0)));
	if (band < 0.5) {
		discard;
	}
	vec3 color = band > 1.5 ? inner_color.rgb * inner_density : outer_color.rgb * outer_density;
	color *= strength;
	COLOR = vec4(color, 0.0);
}
