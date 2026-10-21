// Pixel fog drifting over the floor, in screen space but moving with the camera (parallax),
// so it feels like it hangs in the room. One fog texel is one art pixel on screen (2 world
// units at the camera's 1.5 zoom: 3 canvas pixels), whatever the window's size.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.06);
uniform vec2 speed = vec2(6.0, 2.0);
uniform vec2 camera_offset = vec2(0.0);
// Canvas pixels (the 1280x720 base the window stretches) per fog texel: one art pixel.
uniform float pixel_scale = 3.0;
// The base canvas the project stretches (project settings, canvas_items / expand).
uniform vec2 base_size = vec2(1280.0, 720.0);

void fragment() {
	vec2 texture_size = vec2(textureSize(TEXTURE, 0));
	// Framebuffer pixels per canvas pixel (the stretch), so texels stay art pixels on any phone.
	vec2 screen = 1.0 / SCREEN_PIXEL_SIZE;
	float stretch = min(screen.x / base_size.x, screen.y / base_size.y);
	vec2 canvas_px = FRAGCOORD.xy / stretch;
	vec2 world_px = (canvas_px + camera_offset * 0.6 + TIME * speed) / pixel_scale;
	vec2 uv = fract(floor(world_px) / texture_size);
	float fog = texture(TEXTURE, uv).a;
	COLOR = vec4(tint.rgb, tint.a * fog);
}
