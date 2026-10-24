class_name CosmeticUnlock
extends Resource
## What opens a cosmetic (CosmeticDef.unlock), read from the profile. A new kind of condition is
## a new subclass (WinUnlock...), never a branch here.


## Met by this profile.
func is_met() -> bool:
	return true


## The condition in a sentence, translated ("Win a descent on Keeper.").
func describe() -> String:
	return ""
