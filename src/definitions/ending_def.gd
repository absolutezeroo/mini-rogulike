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
