shader_type canvas_item;
// A weapon's swing, drawn on a square around the attacker turned toward the aim (+x):
//   mode 0: a crescent sweeping over `arc` radians, bright at its outer edge and its head,
//           thinning toward its tail;
//   mode 1: a thrust, a streak shooting out along +x.
// `progress` moves the head (0..1), `fade` dissolves it pixel by pixel. All in 2x2 art pixels.

uniform float radius = 40.0;
uniform float thickness = 16.0;
uniform float arc = 2.0;
uniform float progress = 0.0;
uniform float fade = 0.0;
uniform float trail = 0.75;
uniform vec4 color : source_color = vec4(0.8, 0.9, 1.0, 0.9);
uniform vec4 core : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform int mode = 0;
uniform float pixel = 2.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Ordered dithering (4x4 Bayer): soft gradients become crisp pixel patterns.
float bayer(vec2 cell) {
	int x = int(mod(cell.x, 4.0));
	int y = int(mod(cell.y, 4.0));
	int index = x + y * 4;
	int pattern[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(pattern[index]) + 0.5) / 16.0;
}

void fragment() {
	vec2 p = (floor(local / pixel) + 0.5) * pixel;
	float along;   // 0 = tail .. 1 = head
	float across;  // 0 = cutting edge .. 1 = inner side
	if (mode == 0) {
		float r = length(p);
		float angle = atan(p.y, p.x);
		float head = -arc * 0.5 + arc * progress;
		float tail = max(head - arc * trail, -arc * 0.5);
		if (angle > head || angle < tail || head <= tail) {
			discard;
		}
		along = (angle - tail) / (head - tail);
		float width = thickness * (0.2 + 0.8 * along);
		across = (radius - r) / width;
	} else {
		float head = radius * progress;
		float tail = head - radius * trail;
		if (p.x > head || p.x < tail) {
			discard;
		}
		along = (p.x - tail) / max(head - tail, 1.0);
		float half_width = thickness * 0.5 * (0.15 + 0.85 * along);
		across = abs(p.y) / max(half_width, 1.0);
	}
	if (across < 0.0 || across > 1.0) {
		discard;
	}
	if (hash(floor(p / pixel)) < fade) {
		discard;
	}
	// A white cutting edge, the weapon's color behind it; at the head, all white.
	vec4 c = across < 0.28 || along > 0.93 ? core : color;
	// Thinning out toward the tail and the inner side: dithered, never blurry.
	float presence = smoothstep(0.0, 0.45, along) * (1.0 - smoothstep(0.55, 1.0, across) * 0.7);
	if (presence < bayer(floor(p / pixel))) {
		discard;
	}
	COLOR = c;
}
