shader_type canvas_item;
render_mode blend_disabled;
// An aura's glow on a floor (AuraVfx in a World): 1-bit like every effect there, its glowing
// pixels writing the emissive mark (fx.gdshaderinc). The drawing: aura_ground.gdshaderinc.

#include "res://assets/shaders/fx.gdshaderinc"
#define AURA_ALPHA fx_alpha(emissive)
#include "res://assets/shaders/aura_ground.gdshaderinc"
