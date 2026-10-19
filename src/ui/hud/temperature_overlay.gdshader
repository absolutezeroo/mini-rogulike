shader_type canvas_item;
// The screen's edges when the hero is cold (frost creeping in) or hot (a burning haze).
// `cold` and `heat` go from 0 (nothing) to 1 (frozen / burning up).

uniform float cold : hint_range(0.0, 1.0) = 0.0;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform vec2 aspect = vec2(16.0, 9.0);

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
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// Chunky pixels, like the game.
	vec2 uv = floor(UV * aspect * 24.0) / (aspect * 24.0);
	vec2 c = (uv - 0.5) * 2.0;
	float edge = max(abs(c.x), abs(c.y)) * 0.6 + length(c) * 0.4;
	vec4 result = vec4(0.0);
	if (cold > 0.0) {
		float n = fbm(uv * aspect * 0.9);
		float reach = 1.12 - cold * 0.42;
		float mask = smoothstep(reach, reach + 0.14, edge + (n - 0.5) * 0.45);
		float crystal = step(0.72, fbm(uv * aspect * 3.0 + 7.0));
		vec3 ice = mix(vec3(0.72, 0.86, 1.0), vec3(1.0), crystal * 0.8 + n * 0.3);
		result = vec4(ice, mask * (0.4 + 0.35 * cold));
	}
	if (heat > 0.0) {
		float wave = fbm(uv * aspect * 0.7 + vec2(0.0, TIME * 0.6));
		float reach = 1.1 - heat * 0.45;
		float mask = smoothstep(reach, reach + 0.3, edge + (wave - 0.5) * 0.3);
		vec3 haze = mix(vec3(1.0, 0.35, 0.1), vec3(1.0, 0.75, 0.3), wave);
		vec4 hot = vec4(haze, mask * (0.25 + 0.3 * heat) * (0.85 + 0.15 * sin(TIME * 5.0)));
		result = hot.a > result.a ? hot : result;
	}
	COLOR = result;
}
