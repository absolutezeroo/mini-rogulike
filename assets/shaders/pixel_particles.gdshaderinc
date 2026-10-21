// Particles on the art's pixel grid (docs/vfx.md), shared by pixel_particles.gdshader and its
// glowing twin. CPUParticles2D draws each particle as a quad at any sub-pixel position: here
// every corner snaps to the world's 2-unit grid, so a particle covers whole art pixels at grid
// positions (its size must be an even number of units: the scenes' scale steps are).
// Its fade (the color ramp's alpha) is never a translucent square:
//   - `per_particle` off: ordered dithering by art pixel (smoke and dust dissolve pixel by pixel);
//   - `per_particle` on: each particle is fully there or gone, fewer of them as the alpha drops
//     (one-pixel motes would twinkle as they cross the dither pattern);
//   - GLOW (added light): the alpha steps its brightness instead.

uniform float pixel = 2.0;
uniform bool per_particle = false;

varying vec2 world;
varying flat float seed;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	vec2 at = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 snapped = round(at / pixel) * pixel;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(snapped, 0.0, 1.0)).xy;
	world = snapped;
	seed = fract(float(INSTANCE_ID) * 0.6180339 + 0.31);
}

void fragment() {
	vec4 c = COLOR * texture(TEXTURE, UV);
#ifdef GLOW
	COLOR = vec4(c.rgb * c.a, 1.0);
#else
	vec2 cell = floor(world / pixel);
	int index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	float threshold = per_particle ? seed : (BAYER[index] + 0.5) / 16.0;
	if (c.a < threshold) {
		discard;
	}
	COLOR = vec4(c.rgb, 1.0);
#endif
}
