shader_type canvas_item;
// A shockwave rippling the picture: pixels near the expanding ring are pushed outward (whole
// screen pixels, so the art stays crisp), with a faint bright crest.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float radius = 20.0;
uniform float width = 16.0;
uniform float strength = 6.0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float r = length(local);
	float d = (r - radius) / width;
	float w = 1.0 - clamp(abs(d), 0.0, 1.0);
	if (w <= 0.0 || r < 1.0) {
		discard;
	}
	vec2 push = floor(normalize(local) * strength * w * w + 0.5);
	COLOR = texture(screen, SCREEN_UV - push * SCREEN_PIXEL_SIZE);
	COLOR.rgb += vec3(0.08) * w * w * strength / 6.0;
}
