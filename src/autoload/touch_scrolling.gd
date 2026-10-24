extends Node
## Every list that scrolls (codex, shrine, bag, shop...) gets drag-to-scroll that works on
## phones (TouchScroll), as soon as it enters the tree, and follows the keyboard's or gamepad's
## focus (MenuNav): a button moved to off the list's edge scrolls into sight.


func _ready() -> void:
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is ScrollContainer and not node.has_meta(TouchScroll.META):
			node.set_meta(TouchScroll.META, true)  # claimed: entering the tree again adds none
			# (a weak reference: a list freed before the deferred call, built and dropped in the
			# same frame, would make the call fail with an engine error)
			_attach.call_deferred(weakref(node)))


func _attach(list: WeakRef) -> void:
	var container := list.get_ref() as ScrollContainer
	if container:
		TouchScroll.attach(container)
