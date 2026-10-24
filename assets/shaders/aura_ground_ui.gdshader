shader_type canvas_item;
render_mode blend_mix;
// An aura's glow out of a floor (AuraVfx on a sprite: the title's hero, the Wardrobe's preview):
// drawn over what is under it like any picture, so a window opened over it hides it (written
// with blending off, it showed through the windows of the title's transparent viewport). The
// drawing: aura_ground.gdshaderinc.

#include "res://assets/shaders/fx.gdshaderinc"
#define AURA_ALPHA 1.0
#include "res://assets/shaders/aura_ground.gdshaderinc"
