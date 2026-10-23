class_name TimeText
## Run times as speedrunners read them: "4:05.3", "1:02:07.45".


## `decimals`: digits after the seconds (0, 1 or 2). Hours only when there are some.
static func of(seconds: float, decimals: int = 2) -> String:
	var steps := int(pow(10, clampi(decimals, 0, 2)))
	var total := int(floor(maxf(seconds, 0.0) * steps + 0.0001))  # cut, never round up
	var fraction := total % steps
	var whole := int(total / float(steps))
	var text := "%d:%02d" % [int(whole / 60.0), whole % 60]
	if whole >= 3600:
		text = "%d:%02d:%02d" % [int(whole / 3600.0), int(whole / 60.0) % 60, whole % 60]
	if decimals > 0:
		text += "." + str(fraction).pad_zeros(clampi(decimals, 0, 2))
	return text


## A split against the record: "-0:05.2" (ahead) or "+0:12.0" (behind).
static func delta(seconds: float, decimals: int = 1) -> String:
	return ("-" if seconds < 0.0 else "+") + of(absf(seconds), decimals)
