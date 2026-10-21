extends Node
## Global signal bus (autoload "Events").
## Gameplay code emits, UI listens: neither side needs a reference to the other.

signal message_logged(text: String, color: Color)
signal depth_changed(depth: int)
signal monster_killed(monster: Monster)
## A monster spotted the hero for the first time (its bestiary page opens).
signal monster_noticed(monster: Monster)
## A goal was reached (souls already paid).
signal achievement_unlocked(achievement: AchievementDef)
## A hunter rank reached with a kind of monster, souls paid (see Bestiary).
signal bestiary_rank_reached(monster: MonsterDef, rank: int, souls: int)
## A bestiary challenge done and paid (see HuntTracker).
signal hunt_challenge_done(monster: MonsterDef, challenge: HuntChallenge)
## A daily or weekly quest finished and paid (see QuestBoard).
signal quest_completed(quest: Dictionary)
## Something worth counting happened (opened a chest, used an encounter, found an epic...):
## stat is an AchievementDef.STAT_KEYS value.
signal stat_counted(stat: String, amount: int)
## The hero walked up to an encounter (spring, altar...).
signal encounter_requested(encounter: Encounter)
## Something (an encounter...) grants a choice of perks: rarity is PerkDef.Rarity.
signal perk_offer_requested(rarity: int, title: String, subtitle: String)
## The hero walked up to the merchant.
signal shop_requested(merchant: Merchant)
## The hero walked up to the smith's forge.
signal forge_requested(forge: Forge)
## A soul set free by a kill reached the hero's lantern (see SoulWisp).
signal soul_gathered
## Something big happened near the hero: the camera shakes (0..1, see GameCamera.shake()).
signal screen_shake(amount: float)
## A short push of the camera (pixels, along `direction`): the weight of a blow, a shot's recoil.
signal camera_kick(direction: Vector2, pixels: float)
## The player entered a boss arena and the fight began.
signal boss_started(boss: Monster)
## The boss of the floor died: the arena opens and the stairs appear.
signal boss_defeated(boss: Monster)
## The hero walked into an ambush room: the exits closed, monsters are coming.
signal ambush_started(room: AmbushRoom)
## Every wave of the ambush is dead: the exits open.
signal ambush_cleared(room: AmbushRoom)
## A cracked wall broke and a secret room opened (SecretRoom).
signal secret_found(room: Node2D)
## The hero walked up to a pact door (PactRoom): its rule, reward and cost are shown.
signal pact_requested(pact: PactRoom)
## The hero walked into a sworn pact's room: the door sealed, its rule is watched.
signal pact_started(pact: PactRoom)
## The pact's rule was broken: its cost is paid (the fight goes on).
signal pact_broken(pact: PactRoom)
## The pact's last foe fell and the door opened (`pact.outcome`: kept or broken).
signal pact_ended(pact: PactRoom)


func log_message(text: String, color: Color = Color.WHITE) -> void:
	message_logged.emit(text, color)
