// Pixel fog drifting over the floor, in screen space but moving with the camera (parallax),
// so it feels like it hangs in the room.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.06);
uniform vec2 speed = vec2(6.0, 2.0);
uniform vec2 camera_offset = vec2(0.0);
// Screen pixels per fog texture pixel.
uniform float pixel_scale = 4.0;

void fragment() {
	vec2 texture_size = vec2(textureSize(TEXTURE, 0));
	vec2 screen_px = FRAGCOORD.xy;
	vec2 world_px = screen_px / pixel_scale + (camera_offset * 0.6 + TIME * speed) / pixel_scale;
	vec2 uv = fract(floor(world_px) / texture_size);
	float fog = texture(TEXTURE, uv).a;
	COLOR = vec4(tint.rgb, tint.a * fog);
}
