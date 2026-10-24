class_name FeedbackCategoryDef
extends Resource
## One kind of message the player can send from "Send feedback" (FeedbackDef, the Feedback
## autoload; docs/online.md "Player feedback"): a bug, an idea, something else. Each is a Talo
## feedback category: it must exist in the dashboard (Feedback > Categories) with exactly this
## internal name; until it does, Talo answers 404 and the messages wait on the player's device.

## The game's own id (the dialog's buttons, the tests).
@export var id: StringName
## Talo's internal name (never renamed: the dashboard and the data must keep matching).
@export var internal_name: String
## Its button in the form (translated where shown; plain words, it is a rule).
@export var display_name: String
## What the text field asks for while it is empty (translated where shown).
@export var hint: String
