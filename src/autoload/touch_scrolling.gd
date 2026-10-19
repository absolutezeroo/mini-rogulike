extends Node
## Every list that scrolls (codex, shrine, bag, shop...) gets drag-to-scroll that works on
## phones (TouchScroll), as soon as it enters the tree.


func _ready() -> void:
	get_tree().node_added.connect(func(node: Node) -> void:
		if node is ScrollContainer and not node.has_meta(&"touch_scroll"):
			node.set_meta(&"touch_scroll", true)
			TouchScroll.attach.call_deferred(node))
