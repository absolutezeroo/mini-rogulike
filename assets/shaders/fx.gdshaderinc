// Shared by the effect shaders (docs/vfx.md, "Shaders"): the art pixel a fragment falls in on
// the world's grid, ordered dithering, a stepped value noise, and how an effect writes itself.
//
// The grid trick: `world` is the fragment's position in the world (MODEL_MATRIX * VERTEX), so
// floor(world / pixel) is the art pixel (2x2 world units) it belongs to, wherever the node is
// and however big its quad. Everything (noise, dither, rings, distance) is computed per art
// pixel, so a shader never draws a pixel smaller than the art's.
//
// COLOR in fragment() already is the texel times the tint (Godot multiplies them before the
// shader runs): use COLOR, or texture() alone, never texture() * COLOR (the ramp squared: darker).
//
// The emissive mask: effects are drawn with blending off (they are 1-bit: a pixel is there or
// discarded), so they also write their alpha. An emissive effect (fire, frost, holy...) writes
// EMISSIVE_ALPHA instead of 1; the screen pass (screen.gdshader) reads it back and keeps those
// pixels out of most of the floor's color grading, so frost stays cyan in a warm biome. Any
// opaque thing drawn over it later writes 1 again (the game's viewport is transparent, see
// ScreenEffects), so a monster in front of a crystal is graded like the rest.

const float EMISSIVE_ALPHA = 0.3333;
const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// 4x4 ordered dither threshold of an art pixel (0..1).
float bayer(vec2 cell) {
	int index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	return (BAYER[index] + 0.5) / 16.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Value noise between lattice points (smooth: quantize what you make of it).
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Time in steps of `fps` (effects move at the hand-animated 12-20 fps, never every frame).
float stepped_time(float time, float fps) {
	return floor(time * fps) / fps;
}

// The alpha an effect writes: the emissive mark for a glowing one, 1 for matter.
float fx_alpha(bool emissive) {
	return emissive ? EMISSIVE_ALPHA : 1.0;
}
