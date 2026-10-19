class_name GameMenus
extends CanvasLayer
## The game's panels (bag, perk choice, shop, encounter, pause, end of run): which one is open,
## what Back closes, and putting the end-of-run screen above the rest. The Game decides when
## they open and pauses the game around them.

@onready var inventory: InventoryPanel = $InventoryPanel
@onready var perks: PerkChoicePanel = $PerkChoicePanel
@onready var game_over: GameOverPanel = $GameOverPanel
@onready var shop: ShopPanel = $ShopPanel
@onready var encounter: EncounterPanel = $EncounterPanel
@onready var pause: PauseMenu = $PauseMenu
## Dev tools: debug builds only (null otherwise).
var debug: DebugPanel


func _ready() -> void:
	if DebugPanel.is_available():
		debug = DebugPanel.new()
		debug.name = "DebugPanel"
		add_child(debug)


func any_open() -> bool:
	return _panels().any(func(panel: Control) -> bool: return panel.visible)


## The phone's back button (or Escape): closes the panel that can be closed. False if none was open.
func back() -> bool:
	if debug and debug.visible:
		debug.close()
	elif pause.visible:
		pause.back()
	elif inventory.visible:
		inventory.close()
	elif shop.visible:
		shop.close()
	elif encounter.visible:
		encounter.close()
	else:
		return false
	return true


func hide_all() -> void:
	for panel in _panels():
		panel.hide()


## Closes everything and puts `panel` above it all (the end of the run).
func show_on_top(panel: Control) -> void:
	hide_all()
	panel.move_to_front()


func _panels() -> Array[Control]:
	var panels: Array[Control] = [inventory, perks, game_over, shop, encounter, pause]
	if debug:
		panels.append(debug)
	return panels
