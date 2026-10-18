class_name ShrinePanel
extends Control
## The shrine: spend souls on permanent upgrades and unlocks.

const ROW_SCENE: PackedScene = preload("res://src/ui/title/upgrade_row.tscn")

var _upgrades: Array[UpgradeDef] = []

@onready var _souls: Label = %Souls
@onready var _rows: VBoxContainer = %Rows


func _ready() -> void:
	hide()
	%CloseButton.pressed.connect(func() -> void:
		Sfx.play_ui(Sfx.bank.ui_close)
		hide())
	Profile.changed.connect(_refresh)


func open(upgrades: Array[UpgradeDef]) -> void:
	_upgrades = upgrades
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for upgrade in upgrades:
		var row := ROW_SCENE.instantiate() as UpgradeRow
		_rows.add_child(row)
		row.setup(upgrade)
		row.buy_requested.connect(_buy)
	_refresh()
	show()


func _buy(upgrade: UpgradeDef) -> void:
	if Profile.buy(upgrade):
		Sfx.play_ui(Sfx.bank.perk_chosen)


func _refresh() -> void:
	_souls.text = "Souls: %d" % Profile.souls
	for row: UpgradeRow in _rows.get_children():
		row.refresh()
