class_name MarkDeed
extends DeedCondition
## Something the run did, or did not do, before the warden fell (RunState.marks, set by
## RunRecords from the events): "bought" (anything from the merchant), "secret" (a secret room
## opened), "hidden_floor" (been down the Nameless Charnel), "oath" (an oath sworn), "cursed"
## (a cursed floor crossed), "encounter:<id>" (an encounter used: "encounter:spirit_spring"),
## "bitten" (the Maw's jaw closed on the hero: WeakPointTrait).

@export var mark: StringName
## True: the run must have it. False: it must not (a run that bought nothing).
@export var present: bool = true


func achieved(kill: Dictionary) -> bool:
	var marks: Dictionary = kill.get("marks", {})
	return marks.has(String(mark)) == present
