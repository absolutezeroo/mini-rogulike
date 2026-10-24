class_name Merchant
extends StaticBody2D
## The wandering merchant (ShopDef). Stand by them and press Interact ("Trade") to open the shop. Their stock is rolled
## when the floor is made; what you sell joins it. Rerolling the stock costs gold (more each
## time); a locked entry stays through rerolls, and if it isn't bought it waits at the next
## merchant at the same price (World.kept_stock).

const SIZE := 32.0
## The Interact button offers the shop from this close.
const OPEN_DISTANCE := 64.0

## One entry per item for sale: { item, price, locked }.
var stock: Array[Dictionary] = []
var def: ShopDef
## Rerolls paid at this merchant (the price grows with each).
var rerolls_done := 0

var _world: World
var _time := 0.0
## Where the hero presses Interact to trade.
var _spot := Interactable.new()


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
	_spot.verb = "Trade"  # i18n
	_spot.reach = OPEN_DISTANCE
	_spot.color = Palette.GOLD
	if def.sprite_sheet:
		var face := AtlasTexture.new()
		face.atlas = def.sprite_sheet
		face.region = Rect2(0, 0, 16, 16)
		_spot.icon = face
	_spot.used.connect(func(_by: Player) -> void: Events.shop_requested.emit(self))
	add_child(_spot)
	_roll_stock()


func _roll_stock() -> void:
	# What the hero locked at an earlier merchant waits here, same price.
	for kept in _world.kept_stock:
		stock.append(kept.duplicate())
	_world.kept_stock.clear()
	var held := stock.size()
	_roll_new()
	# A floor rebuilt from its seed rolls the same stock: the entry locked here before quitting
	# would be in it twice (once kept, once rolled again). The kept one stays.
	var kept_keys := stock.slice(0, held).map(func(entry: Dictionary) -> String: return _key(LootRoller.to_data(entry.item)))
	for i in range(stock.size() - 1, held - 1, -1):
		if kept_keys.has(_key(LootRoller.to_data(stock[i].item))):
			stock.remove_at(i)


## Fresh stock next to what is locked.
func _roll_new() -> void:
	var picked: Array[ItemDef] = []
	for i in 30:
		if picked.size() >= def.equipment_count + _world.boons.shop_extra_items:
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
	stock.append({ "item": item, "price": def.buy_price(item, _world.depth, _world.rules.shop_prices() * _world.boons.shop_price_scale), "locked": false })


func world_of() -> World:
	return _world


func reroll_price() -> int:
	return def.reroll_price(rerolls_done, _world.depth, _world.rules.shop_prices() * _world.boons.shop_price_scale)


## Pays for a new stock: everything not locked is replaced. False without the gold.
func reroll(player: Player) -> bool:
	if not player.spend_gold(reroll_price()):
		return false
	rerolls_done += 1
	stock = stock.filter(func(entry: Dictionary) -> bool: return entry.get("locked", false))
	_roll_new()
	Sfx.play_ui(Sfx.bank.coin)
	return true


## Locks (or unlocks) stock entry `index`: kept through rerolls and carried to the next merchant.
func toggle_lock(index: int) -> void:
	if index >= 0 and index < stock.size():
		stock[index].locked = not stock[index].get("locked", false)
		Sfx.play_ui(Sfx.bank.ui_click)


## The locked entries not bought (they move on with the hero).
func locked_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in stock:
		if entry.get("locked", false):
			result.append(entry)
	return result


## Buys stock entry `index` for `player`. Returns false if they can't (gold, full bag).
func sell_to(player: Player, index: int) -> bool:
	if index < 0 or index >= stock.size():
		return false
	var entry: Dictionary = stock[index]
	if not player.can_store(entry.item) or not player.spend_gold(entry.price):
		return false
	player.store(entry.item)
	stock.remove_at(index)
	_world.bought.append(LootRoller.to_data(entry.item))
	Events.item_bought.emit(entry.item)
	Sfx.play_ui(Sfx.bank.coin)
	Events.log_message(tr("Bought %s") % tr(entry.item.display_name), entry.item.rarity_color())
	return true


## What a save keeps of this merchant: its whole stock as it is now (rerolled, sold to, locked)
## and the rerolls paid (World.spent_data() "merchant").
func save_data() -> Dictionary:
	return {
		"stock": stock.map(func(entry: Dictionary) -> Dictionary:
			return { "item": LootRoller.to_data(entry.item), "price": entry.price, "locked": entry.get("locked", false) }),
		"rerolls": rerolls_done,
	}


## A resumed floor: the stock comes back as it was saved (save_data()), not as the seed rolls it.
## False (nothing changed) when `data` holds no stock.
func load_data(data: Variant) -> bool:
	if not data is Dictionary or not (data as Dictionary).get("stock") is Array:
		return false
	stock.clear()
	for entry: Variant in data.stock:
		if not entry is Dictionary:
			continue
		var item := LootRoller.from_data((entry as Dictionary).get("item"))
		var price: Variant = (entry as Dictionary).get("price", 0)
		if item and (price is float or price is int) and int(price) > 0:
			stock.append({ "item": item, "price": int(price), "locked": entry.get("locked", false) == true })
	var rerolls: Variant = (data as Dictionary).get("rerolls", 0)
	rerolls_done = maxi(int(rerolls), 0) if rerolls is float or rerolls is int else 0
	return true


## A resumed floor: the stock entry the hero already bought (saved form) is gone. False if none.
func forget_sold(saved_item: Variant) -> bool:
	var key := _key(saved_item)
	for i in stock.size():
		if _key(LootRoller.to_data(stock[i].item)) == key:
			stock.remove_at(i)
			return true
	return false


## A saved item as text, the same before and after a trip through a save file (numbers too).
static func _key(saved_item: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(saved_item)))


## Buys `item` from the player's bag (or belt).
## `from_belt`: sold from a belt row (take it from there, not from a copy in the bag).
func buy_from(player: Player, item: ItemDef, from_belt := false) -> bool:
	var price := def.sell_price(item, _world.depth)
	if price <= 0:
		return false
	var taken := (player.belt.remove(item) or player.inventory.remove(item)) if from_belt \
		else (player.inventory.remove(item) or player.belt.remove(item))
	if not taken:
		return false
	player.add_gold(price)
	_add(item)
	Sfx.play_ui(Sfx.bank.coin)
	Events.log_message(tr("Sold %s for %d gold") % [tr(item.display_name), price], Palette.GOLD)
	return true


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	PixelDraw.disc(self, Vector2(0, 12), 11.0, Color(0, 0, 0, 0.35), 1.0, 0.4)
	# A rug with the goods laid out.
	draw_rect(Rect2(-22, 4, 44, 14), Color("6d2f3a"))
	draw_rect(Rect2(-20, 6, 40, 10), Color("9c4a4a"))
	if def.sprite_sheet:
		var bob := roundf(sin(_time * 2.0))
		draw_texture_rect_region(def.sprite_sheet, Rect2(-16, -22 + bob, 32, 32), Rect2(0, 0, 16, 16))
	# A "$" over their head: a customer is welcome.
	Fonts.draw(self, Vector2(0, -30), "$", Fonts.BODY, Palette.GOLD, 0.5, Color.BLACK)
