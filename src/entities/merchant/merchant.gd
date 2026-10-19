class_name Merchant
extends StaticBody2D
## The wandering merchant (ShopDef). Walk up to them to open the shop. Their stock is rolled
## when the floor is made; what you sell joins it.

const SIZE := 32.0
## The shop opens from this close, and opens again only after walking this far away.
const OPEN_DISTANCE := 46.0
const REARM_DISTANCE := 90.0

## One entry per item for sale: { item, price }.
var stock: Array[Dictionary] = []
var def: ShopDef

var _world: World
var _armed := true
var _time := 0.0


func setup(shop: ShopDef, world: World) -> void:
	def = shop
	_world = world
	collision_layer = Layers.WORLD
	collision_mask = 0
	add_to_group("merchants")
	var shape := CircleShape2D.new()
	shape.radius = 11.0
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0, 4)
	add_child(collision)
	_roll_stock()


func _roll_stock() -> void:
	var picked: Array[ItemDef] = []
	for i in 30:
		if picked.size() >= def.equipment_count:
			break
		var item := _world.pick_random_item()
		if item is EquipmentDef and not picked.has(item):
			picked.append(item)
	for item in picked:
		_add(_world.roll_item(item, def.quality))
	var others := 0
	for i in 30:
		if others >= def.consumable_count:
			break
		var item := _world.pick_random_item()
		if item is ConsumableDef:
			_add(item)
			others += 1
	if _world.rng.randf() < def.tome_chance:
		for i in 30:
			var item := _world.pick_random_item()
			if item is SkillTomeDef:
				_add(item)
				break


func _add(item: ItemDef) -> void:
	var extra := _world.difficulty.shop_prices if _world.difficulty else 1.0
	stock.append({ "item": item, "price": def.buy_price(item, _world.depth, extra) })


## Buys stock entry `index` for `player`. Returns false if they can't (gold, full bag).
func sell_to(player: Player, index: int) -> bool:
	if index < 0 or index >= stock.size():
		return false
	var entry: Dictionary = stock[index]
	if player.inventory.is_full() or not player.spend_gold(entry.price):
		return false
	player.inventory.add(entry.item)
	stock.remove_at(index)
	Sfx.play_ui(Sfx.bank.coin)
	Events.log_message("Bought %s" % entry.item.display_name, entry.item.rarity_color())
	return true


## Buys `item` from the player's bag.
func buy_from(player: Player, item: ItemDef) -> bool:
	var price := def.sell_price(item, _world.depth)
	if price <= 0 or not player.inventory.remove(item):
		return false
	player.add_gold(price)
	_add(item)
	Sfx.play_ui(Sfx.bank.coin)
	Events.log_message("Sold %s for %d gold" % [item.display_name, price], Color("ffd166"))
	return true


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	var player := _world.player
	if player == null or player.is_dead:
		return
	var distance := global_position.distance_to(player.global_position)
	if _armed and distance <= OPEN_DISTANCE:
		_armed = false
		Events.shop_requested.emit(self)
	elif distance >= REARM_DISTANCE:
		_armed = true


func _draw() -> void:
	draw_set_transform(Vector2(0, 12), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
	# A rug with the goods laid out.
	draw_rect(Rect2(-22, 4, 44, 14), Color("6d2f3a"))
	draw_rect(Rect2(-20, 6, 40, 10), Color("9c4a4a"))
	if def.sprite_sheet:
		var bob := roundf(sin(_time * 2.0))
		draw_texture_rect_region(def.sprite_sheet, Rect2(-16, -22 + bob, 32, 32), Rect2(0, 0, 16, 16))
	# A "$" over their head while they wait for a customer.
	if not _armed:
		return
	var font := Fonts.MAIN
	draw_string_outline(font, Vector2(-4, -30), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
	draw_string(font, Vector2(-4, -30), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffd166"))
