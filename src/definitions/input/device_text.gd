class_name DeviceText
extends Resource
## A sentence that tells the player what to do, in the words of the device in hand: one for touch
## ("Tap the bag"), one for keys and gamepads ("Press {inventory} to open the bag": each
## {action} code becomes that action's key or button, see Prompts.fill()). Both are English keys,
## translated where shown.

@export_multiline var touch_text := ""
## Keyboard and gamepad. Empty: the touch sentence serves every device.
@export_multiline var button_text := ""


## The sentence for the device in use, translated, its codes filled.
func text() -> String:
	return Prompts.pick(touch_text, button_text)
