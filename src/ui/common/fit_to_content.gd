class_name FitToContent
## Cards are Buttons drawn around a container: a Button doesn't grow with what is inside it, so
## long text would spill out of the frame. grow() makes `card` tall enough for `inside` (wrapped
## labels know their height only once they have their width).
##
## A wrapped label not laid out yet (no width: the panel was hidden, or the layout not done)
## reports a huge height, one letter a line: measured then, the card grew thousands of pixels
## tall and stayed so, pushing the perk choice's buttons off the screen. So nothing is measured
## while the card is hidden or before `inside` has a real width, the card can shrink back to its
## base height, and it is measured again each time `inside` changes size or what it needs.

const BASE_META := &"fit_base_height"


static func grow(card: Control, inside: Control) -> void:
	if not is_instance_valid(card) or not is_instance_valid(inside) or not card.is_inside_tree():
		return
	if not card.has_meta(BASE_META):
		card.set_meta(BASE_META, card.custom_minimum_size.y)
	if not card.is_visible_in_tree() or inside.size.x < card.custom_minimum_size.x * 0.5:
		return  # not laid out (hidden containers don't place their children): a wrapped label would answer one letter a line
	var needed := maxf(float(card.get_meta(BASE_META)), ceilf(inside.get_combined_minimum_size().y))
	if not is_equal_approx(needed, card.custom_minimum_size.y):
		card.custom_minimum_size.y = needed


## Grows `card` now and whenever `inside` is resized or its needs change (the panel shown at
## last and its labels given their width, a new text). Fire and forget: safe to call again.
static func grow_later(card: Control, inside: Control) -> void:
	if not is_instance_valid(card) or not is_instance_valid(inside):
		return
	var refit := grow.bind(card, inside)
	if not inside.resized.is_connected(refit):
		inside.resized.connect(refit)
	if not inside.minimum_size_changed.is_connected(refit):
		inside.minimum_size_changed.connect(refit, CONNECT_DEFERRED)
	if not card.is_inside_tree():
		return
	var tree := card.get_tree()
	for i in 3:
		await tree.process_frame
		if not is_instance_valid(card) or not is_instance_valid(inside):
			return  # gone meanwhile (a rerolled card)
		grow(card, inside)
