shader_type canvas_item;
// Volumetric mist over the plateau (see PlateauMist). Drawn into a small viewport, one pixel per
// art pixel of the view, then laid over the world. For each pixel, a ray goes down through the
// mist's height in slices, nearest first (the camera looks down from the south, 3/4 view: a
// slice `h` high shows `h * height` pixels further up the screen). Each slice reads:
//   - how thick the mist is there (`mask`: 0 on the floor and cliff faces, thicker inland),
//   - a 3D noise drifting with the wind and rising slowly (the mist's shape),
//   - the light there (`light`: the floor's light, lamps and torches included).
// Densities add up (Beer-Lambert); lit mist glows (the light scatters in it), unlit mist stays
// dark. Upper slices are thinner and lighter, so it reads as a volume; near the edge of the view
// they lean outward a little (perspective), so it shifts as the camera moves.

uniform sampler2D mask : filter_linear;
uniform vec2 mask_origin;       // world position of the mask's top-left corner
uniform vec2 mask_size;         // world size the mask covers
uniform sampler2D light : filter_linear;
uniform vec2 light_origin;
uniform vec2 light_size;
uniform vec4 outside_light : source_color = vec4(0.3, 0.3, 0.35, 1.0);

uniform vec2 view_origin;       // world position of this viewport's top-left pixel
uniform vec2 view_pixels = vec2(8.0);  // this viewport's size
uniform float pixel = 2.0;      // world pixels per mist pixel
uniform vec2 camera;            // world position of the screen's centre

uniform vec4 deep_color : source_color = vec4(0.08, 0.06, 0.12, 1.0);
uniform vec4 wisp_color : source_color = vec4(0.55, 0.55, 0.65, 1.0);
uniform float density = 0.85;
uniform float height = 44.0;    // world pixels, top of the mist
uniform float perspective = 0.05;
uniform int slices = 6;
uniform vec2 wind = vec2(9.0, 4.0);
uniform float scale = 150.0;
uniform float glow = 1.6;       // how much a lit mist brightens (light scattering)

const mat4 BAYER = mat4(
	vec4(0.0, 8.0, 2.0, 10.0),
	vec4(12.0, 4.0, 14.0, 6.0),
	vec4(3.0, 11.0, 1.0, 9.0),
	vec4(15.0, 7.0, 13.0, 5.0));

float hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash(i), hash(i + vec3(1, 0, 0)), u.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), u.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}

float clouds(vec3 p) {
	return noise(p) * 0.6 + noise(p * 2.07 + vec3(11.0, 5.0, 3.0)) * 0.3 + noise(p * 4.1 + vec3(3.0, 17.0, 9.0)) * 0.1;
}

vec3 light_at(vec2 world) {
	vec2 uv = (world - light_origin) / light_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return outside_light.rgb;
	}
	return texture(light, uv).rgb;
}

float thickness_at(vec2 world) {
	vec2 uv = (world - mask_origin) / mask_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 1.0;
	}
	return texture(mask, uv).r;
}

void fragment() {
	vec2 px = floor(UV * view_pixels);
	vec2 world = view_origin + (px + 0.5) * pixel;
	float t = TIME;
	vec3 sum = vec3(0.0);
	float through = 1.0;  // light still coming through
	float step_height = 1.0 / float(slices);
	for (int i = 0; i < slices; i++) {
		float h = 1.0 - (float(i) + 0.5) * step_height;  // from the top down: nearest first
		// The ground point under this slice: lower on screen the higher it is, and leaning
		// away from the screen's centre (perspective).
		vec2 ground = world + vec2(0.0, h * height) + (world - camera) * h * perspective;
		float thick = thickness_at(ground);
		if (thick < 0.01) {
			continue;
		}
		vec3 p = vec3((ground + wind * t * (0.6 + h)) / scale, h * 1.7 + t * 0.03);
		float shape = smoothstep(0.28 + h * 0.3, 0.85, clouds(p));
		// Thick at the bottom, wispy on top.
		float d = thick * density * (0.35 + 0.65 * shape) * (1.5 - h) * step_height * 3.5;
		float taken = 1.0 - exp(-d);
		// Light scatters in the mist: a soft average around the point, not the floor's steps.
		vec3 lit = light_at(ground) * 2.0;
		for (int k = 0; k < 8; k++) {
			float angle = float(k) * 0.785 + float(i) * 0.39;
			lit += light_at(ground + vec2(cos(angle), sin(angle)) * 22.0);
		}
		lit /= 10.0;
		float bright = dot(lit, vec3(0.299, 0.587, 0.114));
		vec3 base = mix(deep_color.rgb, wisp_color.rgb, clamp(h * 0.7 + shape * 0.4, 0.0, 1.0));
		vec3 color = base * lit * (1.0 + glow * bright * bright);
		sum += through * taken * color;
		through *= 1.0 - taken;
		if (through < 0.02) {
			break;
		}
	}
	float alpha = 1.0 - through;
	if (alpha < 0.01) {
		discard;
	}
	// Flat steps, dithered, like the rest of the light.
	ivec2 cell = ivec2(mod(px, 4.0));
	float threshold = (BAYER[cell.x][cell.y] + 0.5) / 16.0;
	float stepped = floor(alpha * 7.0 + threshold) / 7.0;
	COLOR = vec4(sum / max(alpha, 0.001), stepped);
}
