shader_type canvas_item;
// A blow's arc (SwingVfx), drawn on a square around the attacker:
//   mode 0: a crescent sweeping over `arc` radians around `aim` (more than a turn for a spin),
//           its cutting edge bright, its body down the element's ramp, thinning toward the tail;
//   mode 1: a thrust, a streak shooting out along `aim` from `inner` (the hand, clear of the
//           wielder's body) to `radius`.
// The node is never turned: the shape turns with `aim`, but its pixels are 2x2 art pixels on
// the world's grid (like the art), so a diagonal swing has the same pixels as a straight one.
// `progress` moves the head (0..1), `fade` dissolves it pixel by pixel (ordered dithering).
// Colors are the steps of an element's ramp (`core` the bright edge, `light`, `body`, `edge`
// the dark inner rim); an enemy's blow adds the `danger` rim on its cutting edge.

uniform float radius = 40.0;
uniform float thickness = 16.0;
uniform float arc = 2.0;
uniform float aim = 0.0;
uniform float progress = 0.0;
uniform float fade = 0.0;
uniform float trail = 0.75;
uniform float inner = 0.0;
uniform vec4 core : source_color = vec4(0.95, 0.92, 0.95, 1.0);
uniform vec4 light : source_color = vec4(0.78, 0.78, 0.78, 1.0);
uniform vec4 body : source_color = vec4(0.55, 0.55, 0.55, 1.0);
uniform vec4 edge : source_color = vec4(0.31, 0.28, 0.29, 1.0);
uniform vec4 danger : source_color = vec4(0.0);  // alpha 0: a hero's blow
uniform int mode = 0;
uniform float pixel = 2.0;

varying vec2 world;
varying vec2 origin;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	origin = MODEL_MATRIX[3].xy;
}

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer(vec2 cell) {
	int index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	return (BAYER[index] + 0.5) / 16.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// The art pixel this fragment falls in, on the world's grid, then turned into the blow's
	// own frame (+x = the aim).
	vec2 cell = floor(world / pixel);
	vec2 d = (cell + 0.5) * pixel - origin;
	float c = cos(aim);
	float s = sin(aim);
	vec2 p = vec2(d.x * c + d.y * s, -d.x * s + d.y * c);
	float along;   // 0 = tail .. 1 = head
	float across;  // 0 = cutting edge .. 1 = inner side
	float rim;     // world units to the shape's outer side (where an enemy's warning rim goes)
	if (mode == 0) {
		float r = length(p);
		float start = -arc * 0.5;
		float head = start + arc * progress;
		float tail = max(head - min(arc * trail, 5.6), start);
		if (head <= tail) {
			discard;
		}
		// The angle unwrapped into [tail, tail + TAU): spins of more than a turn work.
		float angle = atan(p.y, p.x);
		angle += ceil((tail - angle) / 6.2831853) * 6.2831853;
		if (angle > head) {
			discard;
		}
		along = (angle - tail) / (head - tail);
		float width = thickness * (0.25 + 0.75 * along);
		across = (radius - r) / width;
		rim = radius - r;
	} else {
		float span = max(radius - inner, 1.0);
		float head = inner + span * progress;
		float tail = head - span * trail;
		if (p.x > head || p.x < tail || p.x < inner) {
			discard;
		}
		along = (p.x - tail) / max(head - tail, 1.0);
		float half_width = thickness * 0.5 * (0.2 + 0.8 * along);
		across = abs(p.y) / max(half_width, 1.0);
		rim = half_width - abs(p.y);
	}
	if (across < 0.0 || across > 1.0) {
		discard;
	}
	if (hash(cell) < fade) {
		discard;
	}
	// Thinning toward the tail and the inner side: dithered, never blurry.
	float presence = smoothstep(0.0, 0.4, along) * (1.0 - smoothstep(0.6, 1.0, across) * 0.6);
	if (presence < bayer(cell)) {
		discard;
	}
	// Bands down the ramp from the cutting edge in; the tail cools a step or two.
	float step_down = (1.0 - along) * 1.6 + fade * 2.0;
	float band = floor(across * 3.2 + step_down);
	vec4 color = band < 1.0 ? core : (band < 2.0 ? light : (band < 3.0 ? body : edge));
	if (along > 0.92 && across < 0.7) {
		color = core;  // the head, all bright
	}
	if (danger.a > 0.0 && rim < pixel * 1.5 && along < 0.92) {
		color = danger;  // an enemy's blow: a warning rim on its edge
	}
	COLOR = vec4(color.rgb, 1.0);
}
