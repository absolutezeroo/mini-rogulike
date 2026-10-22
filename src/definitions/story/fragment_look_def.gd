class_name FragmentLookDef
extends Resource
## How a fragment lies on the floor (Fragment): its picture (a scrap, a bone tablet, a tied
## letter...), the element its glow and motes are drawn in (docs/vfx.md: the element's ramp,
## stepped, dithered), and the word on the Interact button. One per kind of fragment, in
## data/story/fragment_looks/.

@export var icon: Texture2D
@export var icon_tint: Color = Color.WHITE
## The glow's ramp and motes (spirit for a soul's scrap, fire for a pyre's tablet...).
@export var element: VfxElementDef
## On the Interact button.
@export var verb: String = "Read"
