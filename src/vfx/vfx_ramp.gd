class_name VfxRamp
## Palette swap: paints a sheet in an element's ramp by luminance, so one drawing serves several
## elements without new art (the energy orb is ice-cyan; recolored it is a green venom drop or a
## violet arcane bolt). The brightest shade of the sheet takes the ramp's core, the darkest its
## edge, the shades between spread over the ramp in order; alpha becomes hard (1-bit).
## Done once per sheet and ramp on the CPU and cached, so every pixel is an exact ramp color
## (a shader blending per pixel can't promise that) and drawing it costs nothing more.
## Offline, tools/vfx/recolor.py does the same for sheets worth committing.

static var _cache := {}


## `texture` painted in `ramp` (cached). The texture itself if it can't be read or the ramp is
## empty.
static func recolor(texture: Texture2D, ramp: PackedColorArray) -> Texture2D:
	if texture == null or ramp.is_empty():
		return texture
	var key := "%d|%s" % [texture.get_rid().get_id(), ",".join(Array(ramp).map(func(c: Color) -> String: return c.to_html(false)))]
	if _cache.has(key):
		return _cache[key]
	var image := texture.get_image()
	var result: Texture2D = texture
	if image != null and not image.is_empty():
		result = ImageTexture.create_from_image(recolor_image(image, ramp))
	_cache[key] = result
	return result


## `image` painted in `ramp` (core first), by luminance rank. Pure: also used by the tests.
## Works on the bytes (8 bits per channel), so every pixel is exactly a ramp color.
static func recolor_image(source: Image, ramp: PackedColorArray) -> Image:
	var image := source.duplicate() as Image
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var data := image.get_data()
	# The distinct shades of the opaque pixels, brightest first.
	var levels := {}
	for i in range(0, data.size(), 4):
		if data[i + 3] >= 128:
			levels[_luma(data[i], data[i + 1], data[i + 2])] = true
	var shades := levels.keys()
	shades.sort()
	shades.reverse()
	var index_of := {}
	var last := ramp.size() - 1
	for i in shades.size():
		index_of[shades[i]] = roundi(float(i) / maxf(shades.size() - 1, 1.0) * last)
	var bytes: Array[PackedInt32Array] = []
	for color in ramp:
		bytes.append(PackedInt32Array([roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0)]))
	for i in range(0, data.size(), 4):
		if data[i + 3] < 128:
			data[i] = 0
			data[i + 1] = 0
			data[i + 2] = 0
			data[i + 3] = 0
			continue
		var rgb := bytes[index_of[_luma(data[i], data[i + 1], data[i + 2])]]
		data[i] = rgb[0]
		data[i + 1] = rgb[1]
		data[i + 2] = rgb[2]
		data[i + 3] = 255
	return Image.create_from_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, data)


## Perceived brightness of an 8-bit color (whole steps: near-equal shades count as one).
static func _luma(r: int, g: int, b: int) -> int:
	return roundi(0.299 * r + 0.587 * g + 0.114 * b)
