// The body shader: on the rig's Visual node (its sprites use the parent material), so a body's
// layers (body, armor, helmet, weapon) all wear it. Everything happens in the sprite's own texel
// space (an art pixel): positions come from the vertex in the sprite's local space (one unit = one
// texel, the Visual node scales it 2x), noise is per texel, colors are steps of the element ramps
// (BodyLook.ramps(): a row per element, core to edge), fades are a 4x4 Bayer dither. Nothing here
// blends two ramp colors or draws half a pixel (docs/vfx.md, "Shaders on bodies").
//  - Hit flash: blends the sprite toward `flash_color` while keeping its shape (alpha).
//  - Statuses (BodyLook): burn (heat crawling up the lower rim), chill (rime creeping in from the
//    edges, cold colors; frozen: a glint sweeping across), poison (a green wave up the body on
//    each tick), haunt (a pale flicker, a see-through rim), crackle (storm: forks on the rim for
//    a frame or two). Off (0) costs one uniform test each.
//  - Elite outline: a stepped rim of the rank's color around the silhouette.
//  - Deaths (`dissolve` 0..1, `death_style` from the killing element's DeathLookDef).
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_color : source_color = vec4(1.0, 0.85, 0.5, 1.0);
// Rare monsters (MonsterRankDef): colors turned around the color wheel, and a gleam sweeping
// across the body in whole art pixels.
uniform float hue_shift : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer : hint_range(0.0, 1.0) = 0.0;

// Every element's ramp, a row each, 5 steps from core (x 0) to edge (x 4).
uniform sampler2D ramps : filter_nearest, repeat_disable;
// The body's frame in the sprite's local space (art pixels): x, y, width, height.
uniform vec4 frame_rect = vec4(-8.0, -16.0, 16.0, 16.0);
// Statuses: strength (0 = off) and the ramp row of their element.
uniform float burn = 0.0;
uniform int burn_row = 0;
uniform float chill = 0.0;  // grows 0..1 while the chill lasts (rime creeping inward)
uniform float frozen = 0.0; // a heavy chill: thicker rime and a glint sweeping across
uniform int chill_row = 0;
uniform float poison = 0.0;
uniform float poison_wave = 2.0; // 0..1: a tick's wave rising up the body; above 1: none
uniform int poison_row = 0;
uniform float haunt = 0.0;
uniform int haunt_row = 0;
uniform float crackle = 0.0;
uniform int crackle_row = 0;
// An elite's rim (alpha 0: none), and whether it may draw outside the sprite's pixels (not with
// armor layers on: a helmet's rim would cover the face).
uniform vec4 outline_color : source_color = vec4(0.0);
uniform bool outer_rim = true;
// Deaths: 0 dissolve, 1 ash, 2 shatter, 3 melt, 4 scatter, 5 ascend, 6 implode, 7 wisp,
// 8 crumble (DeathLookDef.Style).
uniform int death_style = 0;
uniform int death_row = 0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

varying vec2 local;
// The node's modulate and vertex color alone. In a Godot 4 canvas shader the fragment's COLOR
// already holds the texture's color: multiplying a texture read by it squared every color (the
// bodies were drawn much darker than their art). Reads at other texels use this instead.
varying vec4 tint;

void vertex() {
	local = VERTEX;
	tint = COLOR;
}

vec3 rotate_hue(vec3 color, float turns) {
	// In YIQ: brightness kept, the color turned.
	mat3 to_yiq = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312));
	mat3 to_rgb = mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703));
	vec3 yiq = to_yiq * color;
	float angle = turns * 6.2831853;
	float c = cos(angle);
	float s = sin(angle);
	yiq.yz = vec2(yiq.y * c - yiq.z * s, yiq.y * s + yiq.z * c);
	return clamp(to_rgb * yiq, 0.0, 1.0);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float bayer(vec2 cell) {
	ivec2 p = ivec2(mod(cell, 4.0));
	return (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
}

vec3 ramp(int row, int step) {
	return texelFetch(ramps, ivec2(clamp(step, 0, 4), row), 0).rgb;
}

// The ramp step a sprite color takes when painted in an element: bright ones the core, the
// dark outline the edge.
int luma_step(vec3 c) {
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return l > 0.72 ? 0 : (l > 0.5 ? 1 : (l > 0.32 ? 2 : (l > 0.17 ? 3 : 4)));
}

bool in_frame(vec2 cell) {
	return cell.x >= frame_rect.x && cell.y >= frame_rect.y && cell.x < frame_rect.x + frame_rect.z && cell.y < frame_rect.y + frame_rect.w;
}

// Alpha of the texel `off` away from the one shown (`src`, at `uv`), transparent outside the
// frame (frames are packed side by side in their sheet: never read the neighbour's). A macro:
// TEXTURE can't be handed to a function.
#define ALPHA_AT(off) (in_frame(src + (off)) ? texture(TEXTURE, uv + (off) * px).a : 0.0)
// A transparent texel touching the silhouette (4 neighbours).
#define TOUCHES_BODY (max(max(ALPHA_AT(vec2(1.0, 0.0)), ALPHA_AT(vec2(-1.0, 0.0))), max(ALPHA_AT(vec2(0.0, 1.0)), ALPHA_AT(vec2(0.0, -1.0)))) > 0.5)

// Distance to the nearest edge between cells of a grid of `size` texels with jittered seeds:
// thin lines are cracks in ice or stone.
float cracks(vec2 cell, float size) {
	vec2 p = cell / size;
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			vec2 o = vec2(hash(i + g), hash(i + g + 17.0));
			float d = length(g + o - f);
			if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
		}
	}
	return (d2 - d1) * size;
}

void fragment() {
	// Most bodies most of the time: nothing on them but maybe a flash. The cheap path (the
	// shader as it was before statuses), no texel reads, no noise.
	if (dissolve <= 0.0 && burn <= 0.0 && chill <= 0.0 && poison <= 0.0 && haunt <= 0.0 && crackle <= 0.0 && outline_color.a <= 0.0) {
		vec4 plain = texture(TEXTURE, UV) * tint;
		if (hue_shift > 0.0) {
			plain.rgb = rotate_hue(plain.rgb, hue_shift);
		}
		if (shimmer > 0.0) {
			float band = fract((floor(local.x) + floor(local.y)) * 0.04 - TIME * 0.45);
			plain.rgb += vec3(0.55) * step(band, 0.06) * shimmer * plain.a;
		}
		COLOR = vec4(mix(plain.rgb, flash_color.rgb, flash_amount), plain.a);
	} else {
		vec2 px = TEXTURE_PIXEL_SIZE;
		vec2 cell = floor(local);
		float bottom = frame_rect.y + frame_rect.w;
		float height = max(frame_rect.w, 1.0);
		vec2 center = vec2(frame_rect.x + floor(frame_rect.z * 0.5), bottom - floor(height * 0.45));
		float frame12 = floor(TIME * 12.0);
		float p = dissolve;
		bool dying = p > 0.0;

		// Deaths that move pixels pick, for each texel, which texel of the sprite it shows (whole
		// texels, so the art stays on its grid).
		vec2 src = cell;
		if (dying) {
			if (death_style == 3) {
				// Melt: each column sags toward the feet (some faster), the base spreading.
				float row = bottom - 1.0 - cell.y;
				float sag = min(p * (0.75 + 0.45 * hash(vec2(cell.x, 3.0))), 0.95);
				float from_row = floor((row + 0.5) / (1.0 - sag));
				float spread = p * 0.45 * clamp(1.0 - row / (height * 0.35), 0.0, 1.0);
				float from_x = center.x + floor((cell.x + 0.5 - center.x) * (1.0 - spread));
				src = vec2(from_x, bottom - 1.0 - from_row);
			} else if (death_style == 6) {
				// Implode: everything drawn toward one dark point.
				vec2 d = cell + 0.5 - center;
				src = floor(center + d / max(1.0 - p * 0.94, 0.04));
			} else if (death_style == 7) {
				// Wisp: the body rises and wavers like smoke.
				float sway = floor(sin((cell.y - frame_rect.y) * 0.8 + frame12 * 0.9) * p * 2.4 + 0.5);
				src = cell + vec2(sway, floor(p * 7.0));
			} else if (death_style == 8) {
				// Crumble: columns slump down, each at its own pace.
				float fall = floor(p * p * height * (0.35 + 0.7 * hash(vec2(floor(cell.x / 2.0), 9.0))));
				src = cell - vec2(0.0, fall);
			}
		}
		vec2 uv = UV + (src - cell) * px;
		vec4 color = vec4(0.0);
		if (src == cell || in_frame(src)) {
			color = texture(TEXTURE, uv) * tint;
		}
		bool opaque = color.a > 0.5;
		// From the feet (0) to the top of the frame (1), and the dither threshold of this texel.
		float h = clamp((bottom - cell.y - 0.5) / height, 0.0, 1.0);
		float b = bayer(cell);
		float noise = hash(cell);
		int lstep = luma_step(color.rgb);

		if (hue_shift > 0.0) {
			color.rgb = rotate_hue(color.rgb, hue_shift);
		}
		if (shimmer > 0.0) {
			float band = fract((cell.x + cell.y) * 0.04 - TIME * 0.45);
			color.rgb += vec3(0.55) * step(band, 0.06) * shimmer * color.a;
		}

		// --- Statuses (only on the sprite's own pixels) ---
		bool statuses = burn > 0.0 || chill > 0.0 || poison > 0.0 || haunt > 0.0 || crackle > 0.0;
		int edge = 9;
		if (opaque && (statuses || dying)) {
			// Art pixels to the nearest transparent one along the four axes: 1 on the rim, up to
			// `reach`, `reach` + 1 deeper in.
			int reach = frozen > 0.5 || (dying && death_style == 2) ? 4 : 3;
			edge = reach + 1;
			for (int k = 1; k <= 4; k++) {
				if (k > reach) {
					break;
				}
				float d = float(k);
				if (min(min(ALPHA_AT(vec2(d, 0.0)), ALPHA_AT(vec2(-d, 0.0))), min(ALPHA_AT(vec2(0.0, d)), ALPHA_AT(vec2(0.0, -d)))) < 0.5) {
					edge = k;
					break;
				}
			}
		}
		if (opaque && chill > 0.0) {
			// Cold: the colors drained toward a blue grey (a step, not a fade).
			float grey = dot(color.rgb, vec3(0.299, 0.587, 0.114));
			color.rgb = mix(color.rgb, vec3(grey) * vec3(0.84, 0.95, 1.12), chill > 0.3 ? 0.5 : 0.3);
			// Rime from the edges inward, one art pixel more as it lasts, jagged per texel. The
			// outline stays dark (the ice's dark edge), lit only on the top: the silhouette
			// still reads on a bright floor.
			int reach = frozen > 0.5 ? 4 : 2 + int(floor(chill * 1.6 + noise * 0.9));
			if (edge <= reach) {
				// Cyan steps mostly (near-white reads beige under a torch).
				int s = clamp(lstep, 1, 3);
				if (edge == 1) {
					s = ALPHA_AT(vec2(0.0, -1.0)) < 0.5 ? 1 : 4;
				} else if (edge == 2 && ALPHA_AT(vec2(0.0, -2.0)) < 0.5) {
					s = 0;  // the lit cap, like the frost shards' top left
				} else if (mod(cell.x + cell.y * 2.0, 5.0) < 1.0) {
					s = max(s - 1, 0);  // facets
				}
				color.rgb = ramp(chill_row, s);
			}
			if (frozen > 0.5) {
				// A glint sweeping across the ice every two seconds, two art pixels wide.
				float sweep = mod(floor(TIME * 24.0), 48.0) - 8.0;
				float diagonal = (cell.x - frame_rect.x) + (bottom - cell.y);
				if (abs(diagonal - sweep * 0.75 - 4.0) < 1.0) {
					color.rgb = ramp(chill_row, 0);
				} else if (abs(diagonal - sweep * 0.75 - 6.0) < 1.0 && edge <= reach) {
					color.rgb = ramp(chill_row, 1);
				}
			}
		}
		if (opaque && poison > 0.0) {
			// A sickly rim, sparse.
			if (edge == 1 && b < 0.2) {
				color.rgb = ramp(poison_row, 3);
			}
			// Each tick, a wave of green rising up the body, its crest bright, its wake dithered.
			if (poison_wave <= 1.0) {
				float row = bottom - 1.0 - cell.y;
				float crest = floor(poison_wave * (height + 6.0)) - 3.0 + (hash(vec2(floor(cell.x / 2.0), 7.0)) > 0.5 ? 1.0 : 0.0);
				float behind = crest - row;
				if (behind >= 0.0 && behind < 2.0) {
					color.rgb = ramp(poison_row, clamp(lstep - 1, 0, 2));
				} else if (behind >= 2.0 && behind < 4.0 && b < 0.6) {
					color.rgb = ramp(poison_row, clamp(lstep, 1, 3));
				} else if (behind >= 4.0 && behind < 7.0 && b < 0.25) {
					color.rgb = ramp(poison_row, 3);
				}
			}
		}
		if (opaque && burn > 0.0) {
			// Heat crawling up the lower rim: tongues two art pixels wide, each its own height,
			// changing ten times a second; bright at the base, red at the tips. No wash of orange.
			float lick = floor(TIME * 10.0);
			float column = floor((cell.x - frame_rect.x) / 2.0);
			float tongue = (0.16 + 0.36 * hash(vec2(column, lick))) * burn;
			bool rim = edge <= 1;
			if (h < tongue && (rim || (h < tongue * 0.5 && b < 0.5))) {
				float s = h / tongue;
				int st = s < 0.34 ? 1 : (s < 0.7 ? 2 : 3);
				if (rim && hash(cell + lick) > 0.86) {
					st = 0;  // a white-hot crackle
				}
				color.rgb = ramp(burn_row, st);
			} else if (rim && h < 0.85 && hash(cell * 1.7 + lick) > 0.93) {
				color.rgb = ramp(burn_row, 3);  // an ember crawling up the outline
			}
		}
		if (opaque && haunt > 0.0) {
			// Pale for a frame now and then (under two a second), the rim half there.
			bool pale = hash(vec2(frame12, 5.0)) > 0.86;
			if (pale) {
				color.rgb = ramp(haunt_row, clamp(lstep, 0, 3));
			}
			if (edge == 1) {
				// Its darker steps: the see-through rim still outlines it on a bright floor.
				color.rgb = ramp(haunt_row, pale ? 2 : 3);
				if (b < 0.35 + 0.25 * hash(vec2(frame12, 9.0))) {
					color.a = 0.0;
				}
			}
		}

		color.rgb = mix(color.rgb, flash_color.rgb, flash_amount);

		// --- Over the flash: a storm's crackle, an elite's rim ---
		if (crackle > 0.0) {
			float strike = floor(TIME * 60.0);
			if (opaque) {
				// Forks running down the body: a jagged line from a random column.
				float x0 = frame_rect.x + 3.0 + floor((frame_rect.z - 6.0) * hash(vec2(strike, 2.0)));
				float zig = floor(sin((cell.y + strike) * 1.9) * 1.6 + 0.5);
				if (cell.x == x0 + zig && hash(vec2(cell.y, strike)) > 0.2) {
					color.rgb = ramp(crackle_row, 0);
				} else if (edge <= 1 && hash(cell + strike) > 0.45) {
					color.rgb = ramp(crackle_row, hash(cell - strike) > 0.7 ? 0 : 1);
				}
			} else if (outer_rim && TOUCHES_BODY && hash(cell + strike * 3.0) > 0.5) {
				color = vec4(ramp(crackle_row, 2), 1.0);
			}
		}
		if (outline_color.a > 0.0 && !opaque && outer_rim && !dying) {
			// The rank's rim: one art pixel around the silhouette, and a second one dithered on the
			// beat (stepped, under two beats a second).
			if (TOUCHES_BODY) {
				color = vec4(outline_color.rgb, 1.0);
			} else if (mod(floor(TIME * 3.0), 2.0) < 1.0 && b < 0.5) {
				float far = max(max(ALPHA_AT(vec2(2.0, 0.0)), ALPHA_AT(vec2(-2.0, 0.0))),
						max(ALPHA_AT(vec2(0.0, 2.0)), ALPHA_AT(vec2(0.0, -2.0))));
				far = max(far, max(max(ALPHA_AT(vec2(1.0, 1.0)), ALPHA_AT(vec2(-1.0, 1.0))),
						max(ALPHA_AT(vec2(1.0, -1.0)), ALPHA_AT(vec2(-1.0, -1.0)))));
				if (far > 0.5) {
					color = vec4(outline_color.rgb * 0.7, 1.0);
				}
			}
		}

		// --- Deaths ---
		if (dying && color.a > 0.0) {
			if (death_style == 1) {
				// Ash: burnt away from the feet up behind a ragged ember edge; above it the body chars.
				float front = p * 1.3 - 0.12;
				float at = h + noise * 0.14;
				if (at < front) {
					color.a = 0.0;
				} else if (at < front + 0.05) {
					color.rgb = ramp(death_row, 0);
				} else if (at < front + 0.11) {
					color.rgb = ramp(death_row, 1 + int(noise * 2.0));
				} else if (at < front + 0.19) {
					color.rgb = ramp(death_row, 3);
				} else if (b < p * 1.6) {
					color.rgb = ramp(death_row, 4) * (lstep >= 3 ? 0.55 : 0.8);
				}
			} else if (death_style == 2) {
				// Shatter: frozen from the edges in (the pieces fly off at half way: ShatterVfx).
				int reach = int(floor(p * 18.0));
				if (p >= 0.5) {
					color.a = 0.0;
				} else if (edge <= reach) {
					int s = clamp(lstep - 1, 0, 3);
					if (edge == 1 && ALPHA_AT(vec2(0.0, -1.0)) < 0.5) {
						s = 0;
					}
					if (p > 0.28 && cracks(cell - frame_rect.xy, 5.0) < 0.55) {
						s = 4;  // the cracks it will break along
					}
					color.rgb = ramp(death_row, s);
				}
			} else if (death_style == 3) {
				// Melt: green takes the body from the top down, then it dithers into its puddle.
				if (b < p * 2.0 - h * 0.6) {
					color.rgb = ramp(death_row, clamp(lstep, 1, 4));
				}
				if (b < (p - 0.7) * 3.3) {
					color.a = 0.0;
				}
			} else if (death_style == 4) {
				// Scatter: a white flash, then flickering in the storm's colors while its pixels fly
				// apart (the sparks: Vfx.pop).
				if (p < 0.14) {
					color.rgb = ramp(death_row, 0);
				} else {
					float gone = (p - 0.14) * 1.35;
					if (noise < gone) {
						color.a = 0.0;
					} else if (noise < gone + 0.12 || mod(frame12, 2.0) < 1.0) {
						color.rgb = ramp(death_row, noise < gone + 0.12 ? 0 : clamp(lstep, 1, 3));
					}
				}
			} else if (death_style == 5) {
				// Ascend: brightening into light, lifted away from the feet up into motes.
				if (b < p * 2.6) {
					color.rgb = ramp(death_row, clamp(lstep - 1, 0, 3));
				}
				float at = h + noise * 0.25;
				float front = p * 1.35 - 0.2;
				if (at < front) {
					color.a = 0.0;
				} else if (at < front + 0.08) {
					color.rgb = ramp(death_row, 0);
				}
			} else if (death_style == 6) {
				// Implode: a dark core with a bright rim, down to one dark point, then nothing.
				int s = edge <= 1 ? 3 : (b < p * 1.8 ? 1 : 2);
				color.rgb = ramp(death_row, s);
				if (p > 0.9) {
					color.a = 0.0;
				}
			} else if (death_style == 7) {
				// Wisp: pale, wavering, dithering away from the feet first.
				color.rgb = ramp(death_row, clamp(lstep, 0, 2) + (edge <= 1 ? 1 : 0));
				if (b < p * 1.5 - h * 0.45) {
					color.a = 0.0;
				}
			} else if (death_style == 8) {
				// Crumble: turned to stone and cracking, slumping, then gone in dust.
				if (b < p * 3.0) {
					color.rgb = ramp(death_row, clamp(lstep, 1, 4));
				}
				if (cracks(cell - frame_rect.xy, 4.0) < 0.5 && p > 0.15) {
					color.rgb = ramp(death_row, 4);
				}
				if (b < (p - 0.6) * 2.5) {
					color.a = 0.0;
				}
			} else {
				// Dissolve: pixels vanish in a random order, with a glowing edge.
				float n = hash(cell + vec2(0.37, 0.71));
				if (n < p) {
					color.a = 0.0;
				} else if (n < p + 0.12) {
					color.rgb = dissolve_color.rgb;
				}
			}
		}
		if (dying && death_style == 6 && p > 0.82) {
			// The point it was sucked into: two art pixels of the dark core in a bright rim.
			vec2 d = abs(cell + 0.5 - center - vec2(0.5));
			if (d.x < 1.0 && d.y < 1.0) {
				color = vec4(ramp(death_row, 0), 1.0);
			} else if (d.x < 2.0 && d.y < 2.0 && p < 0.97 && b < 0.6) {
				color = vec4(ramp(death_row, 3), 1.0);
			}
		}
		COLOR = color;
	}
}
