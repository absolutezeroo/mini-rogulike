class_name FxLook
## The materials effects draw with (docs/vfx.md, "Shaders"): which shader a sheet's look asks for
## (VfxSheetDef.look: PLAIN, SHIMMER, GAS, RUNE, FLAME), in its element's ramp, writing the
## emissive mask when the element shines (fx.gdshaderinc). Materials that never change per node
## are shared, so effects alike batch.

const DITHER := preload("res://assets/shaders/dither_fade.gdshader")
const SPRITE := preload("res://assets/shaders/fx_sprite.gdshader")
const SHIMMER := preload("res://assets/shaders/shimmer.gdshader")
const GAS := preload("res://assets/shaders/gas.gdshader")
const RUNE := preload("res://assets/shaders/rune.gdshader")
const FLAME := preload("res://assets/shaders/flame.gdshader")
## Every shader an effect may use (warmed at load: ShaderWarmup).
const ALL: Array[Shader] = [DITHER, SPRITE, SHIMMER, GAS, RUNE, FLAME,
	preload("res://assets/shaders/glow_halo.gdshader"), preload("res://assets/shaders/blast.gdshader"),
	preload("res://assets/shaders/swing.gdshader"), preload("res://assets/shaders/telegraph.gdshader"),
	preload("res://assets/shaders/gas_pool.gdshader")]

static var _shared := {}


## Drawing in code (`_draw()`): translucent draws dithered, the emissive mask when `emissive`.
static func sprite(emissive: bool) -> ShaderMaterial:
	var key := "sprite/%s" % emissive
	if not _shared.has(key):
		var look := ShaderMaterial.new()
		look.shader = SPRITE
		look.set_shader_parameter("emissive", emissive)
		_shared[key] = look
	return _shared[key]


## A material of its own for a sheet played once (SheetVfx: its fade, its reveal and burn).
static func for_sheet(sheet: VfxSheetDef, element: VfxElementDef) -> ShaderMaterial:
	var look := ShaderMaterial.new()
	look.shader = _shader_of(sheet.look)
	_fill(look, sheet, element)
	return look


## A material for the pieces of a composed nova, shared by every piece of `element` (a rune's
## pieces each need their own: they draw themselves one after the other).
static func for_piece(sheet: VfxSheetDef, element: VfxElementDef) -> ShaderMaterial:
	if sheet.look == VfxSheetDef.Look.PLAIN:
		return sprite(element != null and element.emissive)
	if sheet.look == VfxSheetDef.Look.RUNE:
		return for_sheet(sheet, element)
	var key := "piece/%s/%s/%d" % [element.id if element else &"", sheet.resource_path, sheet.look]
	if not _shared.has(key):
		_shared[key] = for_sheet(sheet, element)
	return _shared[key]


## Flame tongues for a flame sheet (FlameVfx, a campfire), in fire's ramp unless told.
static func flame(element: VfxElementDef = null) -> ShaderMaterial:
	var fire := element if element else VfxElementDef.named(&"fire")
	var key := "flame/%s" % fire.id
	if not _shared.has(key):
		var look := ShaderMaterial.new()
		look.shader = FLAME
		look.set_shader_parameter("ramp", five(fire))
		look.set_shader_parameter("emissive", fire.emissive)
		_shared[key] = look
	return _shared[key]


## A rune's reveal and burn for a drawing of `radius` world units (a ring lying on the floor when
## `squash` < 1), in `element`'s ramp.
static func rune(element: VfxElementDef, radius: float, squash: float = 1.0) -> ShaderMaterial:
	var look := ShaderMaterial.new()
	look.shader = RUNE
	look.set_shader_parameter("radius", radius)
	look.set_shader_parameter("squash", squash)
	look.set_shader_parameter("head", element.core())
	look.set_shader_parameter("ember", element.shade(0.75))
	look.set_shader_parameter("emissive", element.emissive)
	look.set_shader_parameter("seed", randf() * 50.0)
	return look


## The element's ramp as five colors (shorter ramps repeat their last steps).
static func five(element: VfxElementDef) -> PackedColorArray:
	var colors := PackedColorArray()
	for i in 5:
		colors.append(element.shade(i / 4.0))
	return colors


static func _shader_of(look: VfxSheetDef.Look) -> Shader:
	match look:
		VfxSheetDef.Look.SHIMMER:
			return SHIMMER
		VfxSheetDef.Look.GAS:
			return GAS
		VfxSheetDef.Look.RUNE:
			return RUNE
		VfxSheetDef.Look.FLAME:
			return FLAME
	return DITHER


static func _fill(look: ShaderMaterial, sheet: VfxSheetDef, element: VfxElementDef) -> void:
	var shines := element != null and element.emissive
	look.set_shader_parameter("emissive", shines)
	if element == null:
		return
	match sheet.look:
		VfxSheetDef.Look.SHIMMER, VfxSheetDef.Look.GAS, VfxSheetDef.Look.FLAME:
			look.set_shader_parameter("ramp", five(element))
		VfxSheetDef.Look.RUNE:
			var size := Vector2(sheet.frame_size()) * sheet.texel
			look.set_shader_parameter("order_mode", 1 if sheet.glyph else 0)
			# A ring lies on the floor: an oval about as wide as the frame, as deep as 0.4 of it.
			look.set_shader_parameter("radius", size.y * 0.5 if sheet.glyph else size.x * 0.42)
			look.set_shader_parameter("squash", 1.0 if sheet.glyph else 0.4)
			look.set_shader_parameter("head", element.core())
			look.set_shader_parameter("ember", element.shade(0.75))
			look.set_shader_parameter("seed", randf() * 50.0)
