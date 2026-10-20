shader_type canvas_item;
// Mist rolling over the plateau above the walls (see PlateauMist). The texture is the mask, one
// pixel per cell (filtered: soft edges): 0 on the floor and the cliff faces, thicker the further
// from the rim. Two layers of noise drift across it; pixel-sized steps and a dither keep it in
// the game's pixel art.

uniform vec4 deep_color : source_color = vec4(0.08, 0.06, 0.12, 1.0);
uniform vec4 wisp_color : source_color = vec4(0.55, 0.55, 0.65, 1.0);
// Most opacity, deep in the plateau.
uniform float density = 0.85;
// World pixels per mist pixel (the art is drawn at 2x).
uniform float pixel = 4.0;
// Drift, world pixels per second.
uniform vec2 wind = vec2(9.0, 4.0);
uniform float scale = 180.0;

varying vec2 world;

const mat4 BAYER = mat4(
	vec4(0.0, 8.0, 2.0, 10.0),
	vec4(12.0, 4.0, 14.0, 6.0),
	vec4(3.0, 11.0, 1.0, 9.0),
	vec4(15.0, 7.0, 13.0, 5.0));

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 3; i++) {
		sum += noise(p) * amp;
		p = p * 2.03 + vec2(17.1, 9.2);
		amp *= 0.5;
	}
	return sum;
}

void fragment() {
	float mask = texture(TEXTURE, UV).r;
	if (mask < 0.01) {
		discard;
	}
	vec2 p = floor(world / pixel) * pixel;
	float a = fbm((p + wind * TIME) / scale);
	float b = fbm((p - wind.yx * TIME * 0.7) / (scale * 0.6) + vec2(31.0, 7.0));
	float cloud = smoothstep(0.32, 0.78, a * 0.62 + b * 0.5);
	// A few flat bands, like the light: the dither decides between two of them.
	ivec2 cell = ivec2(mod(floor(world / pixel), 4.0));
	float threshold = (BAYER[cell.x][cell.y] + 0.5) / 16.0;
	float levels = 4.0;
	float band = floor(cloud * levels + threshold) / levels;
	vec3 color = mix(deep_color.rgb, wisp_color.rgb, band * 0.85);
	float alpha = mask * density * (0.88 + 0.12 * band);
	alpha = floor(alpha * 8.0 + threshold) / 8.0;
	COLOR = vec4(color, alpha);
}
