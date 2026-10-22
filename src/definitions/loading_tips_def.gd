class_name LoadingTipsDef
extends Resource
## The tips shown while a run loads (SceneLoader): one at random each time.

@export_multiline var tips: PackedStringArray = []
## Tips about a control, in the words of the device in use (DeviceText: tap / press [E]).
@export var control_tips: Array[DeviceText] = []


## A tip at random, translated, for the device in use.
func pick() -> String:
	var count := tips.size() + control_tips.size()
	if count == 0:
		return ""
	var at := randi() % count
	if at < tips.size():
		return TranslationServer.tr(tips[at])
	return control_tips[at - tips.size()].text()
