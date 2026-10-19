extends Node
## Global signal bus (autoload "Events").
## Gameplay code emits, UI listens: neither side needs a reference to the other.

signal message_logged(text: String, color: Color)
signal depth_changed(depth: int)
signal monster_killed(monster: Monster)
## A goal was reached (souls already paid).
signal achievement_unlocked(achievement: AchievementDef)
## Something worth counting happened (opened a chest, used an encounter, found an epic...):
## stat is an AchievementDef.STAT_KEYS value.
signal stat_counted(stat: String, amount: int)
## The hero walked up to an encounter (spring, altar...).
signal encounter_requested(encounter: Encounter)
## Something (an encounter...) grants a choice of perks: rarity is PerkDef.Rarity.
signal perk_offer_requested(rarity: int, title: String, subtitle: String)
## The hero walked up to the merchant.
signal shop_requested(merchant: Merchant)
## A soul set free by a kill reached the hero's lantern (see SoulWisp).
signal soul_gathered
## Something big happened near the hero: the camera shakes (0..1, see GameCamera.shake()).
signal screen_shake(amount: float)
## The player entered a boss arena and the fight began.
signal boss_started(boss: Monster)
## The boss of the floor died: the arena opens and the stairs appear.
signal boss_defeated(boss: Monster)
## The hero walked into an ambush room: the exits closed, monsters are coming.
signal ambush_started(room: AmbushRoom)
## Every wave of the ambush is dead: the exits open.
signal ambush_cleared(room: AmbushRoom)


func log_message(text: String, color: Color = Color.WHITE) -> void:
	message_logged.emit(text, color)
