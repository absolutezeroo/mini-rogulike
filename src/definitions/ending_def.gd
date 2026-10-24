class_name EndingDef
extends Resource
## One of the true endings, chosen when the last form of the final fight falls (FinaleDef.endings,
## the EndingPanel): its button, the line under it, then its text on the victory screen. The
## choice is kept in the profile (Profile.ending) and counted (`stat`) for its achievement.

@export var id: StringName
## The button that chooses it (a verb that starts something: "Ring the bell").
@export var choice: String
## Under the button: what it means, in a line.
@export var hint: String
## The victory screen's title for this ending.
@export var title: String
## The victory screen's story: the ending told, a few short lines.
@export_multiline var text: String
## The profile counter it adds one to (AchievementDef.STAT_KEYS: its achievement reads it).
@export var stat: String
@export var color: Color = Color(1, 0.86, 0.45)
## Under its victory screen (null: SoundBank.victory_music).
@export var music: AudioStream

## What it does to the Nameless Keeper (Profile.keeper, KeeperSnapshot): TAKE, the hero becomes
## him (taken now, waiting at the bottom of the next runs instead of Tôma and the Maw, replacing
## any other); FREE, the one waiting is freed (the bottom is Tôma's and the Maw's again).
enum KeeperChange { NONE, TAKE, FREE }
@export var keeper_change: KeeperChange = KeeperChange.NONE

@export_group("After the Nameless Keeper")
## Its line and its story when the fight was against the Nameless Keeper (FinaleDef.keeper):
## Tôma is not there any more. Empty: the usual ones.
@export var keeper_hint: String
@export_multiline var keeper_text: String


## Its hint under the button: after the Nameless Keeper (`keeper`) its own, if it has one.
func hint_for(keeper: bool) -> String:
	return keeper_hint if keeper and not keeper_hint.is_empty() else hint


## Its story on the victory screen: after the Nameless Keeper its own, if it has one.
func text_for(keeper: bool) -> String:
	return keeper_text if keeper and not keeper_text.is_empty() else text
