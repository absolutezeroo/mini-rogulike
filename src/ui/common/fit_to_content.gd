class_name FitToContent
## Cards are Buttons drawn around a container: a Button doesn't grow with what is inside it, so
## long text would spill out of the frame. grow() makes `card` tall enough for `inside` (wrapped
## labels know their height only once they have their width: call it a frame after filling).


static func grow(card: Control, inside: Control) -> void:
	if not is_instance_valid(card) or not card.is_inside_tree():
		return
	var needed := inside.get_combined_minimum_size().y
	if needed > card.size.y:
		card.custom_minimum_size.y = ceilf(needed)


## The same, two frames from now (layout first, then the wrapping), and again once more in
## case growing changed the wrapping. Fire and forget.
static func grow_later(card: Control, inside: Control) -> void:
	if not card.is_inside_tree():
		return
	var tree := card.get_tree()
	for i in 3:
		await tree.process_frame
		if not is_instance_valid(card) or not is_instance_valid(inside):
			return  # gone meanwhile (a rerolled card)
		grow(card, inside)
