class_name AttackCharge
extends RefCounted
## The hero's charge on the attack button (Player): how long it is held, how full the charge
## is. A tap is a basic attack and never charges: the charge starts only after `delay` seconds
## of holding, then fills over the weapon's charge time; letting go when it is full unleashes
## the weapon's charged attack, earlier lets it go to waste. Rolling (or any skill), a weapon
## swap or a fall cancels it, and the button must be let go before a new charge starts.
## Being hit does not: holding the blow is the risk.

enum State {
	## The button is up.
	IDLE,
	## Held, not yet past the delay (a tap so far).
	HELD,
	## Past the delay: filling.
	CHARGING,
	## Full: waiting for the release.
	FULL,
	## Cancelled while held: nothing until the button is let go.
	SPENT,
}

var state := State.IDLE
## Seconds the button has been held.
var held := 0.0
## 0..1 while charging.
var ratio := 0.0
## Seconds since the charge was full (the flash, the pulse).
var full_time := 0.0


## Down this frame.
func press() -> void:
	state = State.HELD
	held = 0.0
	ratio = 0.0
	full_time = 0.0


## Still held for `delta` seconds: starts charging after `delay`, fills over `charge_time`.
## Returns the state it moved into this frame, or -1 when it stayed.
func hold(delta: float, delay: float, charge_time: float) -> int:
	if state == State.IDLE:
		press()  # held without a press seen (a menu closed over the button): counts from now
	held += delta
	match state:
		State.HELD:
			if held >= delay:
				state = State.CHARGING
				ratio = clampf((held - delay) / maxf(charge_time, 0.01), 0.0, 1.0)
				return State.CHARGING
		State.CHARGING:
			ratio = clampf((held - delay) / maxf(charge_time, 0.01), 0.0, 1.0)
			if ratio >= 1.0:
				state = State.FULL
				full_time = 0.0
				return State.FULL
		State.FULL:
			full_time += delta
	return -1


## Let go: true when the charge was full (the charged attack goes off).
func release() -> bool:
	var fire := state == State.FULL
	reset()
	return fire


## Rolled, swapped weapons, fell: the charge is lost until the button is let go.
func cancel() -> void:
	if state == State.IDLE:
		return
	state = State.SPENT
	ratio = 0.0
	full_time = 0.0


func reset() -> void:
	state = State.IDLE
	held = 0.0
	ratio = 0.0
	full_time = 0.0


## Charging or full (the hero is slower, the gauge shows).
func is_charging() -> bool:
	return state == State.CHARGING or state == State.FULL


func is_full() -> bool:
	return state == State.FULL
