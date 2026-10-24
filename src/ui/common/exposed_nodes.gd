class_name ExposedNodes
extends RefCounted
## The nodes a panel builds in code and wants reachable as %Name from itself (tests, other
## scripts). A node's owner must already be its ancestor, so they are gathered while the panel
## is built (add()) and given their owner once it is (expose_to()). The one way the panels do
## it; a node already in place uses MenuWindow.expose() at once.

var _nodes: Array[Node] = []


## Gathers `node` (named `node_name` if given). Returns it.
func add(node: Node, node_name: String = "") -> Node:
	if not node_name.is_empty():
		node.name = node_name
	_nodes.append(node)
	return node


## Every node gathered becomes %Name of `scene_owner`.
func expose_to(scene_owner: Node) -> void:
	for node in _nodes:
		node.owner = scene_owner
		node.unique_name_in_owner = true
	_nodes.clear()
