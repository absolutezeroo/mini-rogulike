shader_type canvas_item;
render_mode blend_add, unshaded;
// Emissive particles (embers, a candle's flame, fireflies, wisps): added light on the art's
// pixel grid, their fade stepping their brightness (pixel_particles.gdshaderinc).

#define GLOW
#include "res://assets/shaders/pixel_particles.gdshaderinc"
