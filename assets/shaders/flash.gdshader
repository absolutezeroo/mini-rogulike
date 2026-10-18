// Hit flash: blends the sprite toward `flash_color` while keeping its shape (alpha).
// Put it on the rig's Visual node; children use the parent material.
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(color.rgb, flash_color.rgb, flash_amount), color.a);
}
