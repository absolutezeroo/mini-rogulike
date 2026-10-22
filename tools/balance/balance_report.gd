class_name BalanceReport
extends RefCounted
## What a balance run found: FLAGS (numbers that break a target), tables and raw data, written as
## report.md (for people: the flags first, numbered F1, F2..., then the tables, numbered by
## section: 1 Builds, 2 Monsters...), data.json (everything) and one CSV per table.
## Each table belongs to a section (SECTIONS); a run of several modes merges its reports with
## merge(), so --mode=all gives one report in the same order.

const ERROR := "error"
const WARN := "warn"
## The report's sections, in order (a table's `section` is one of these).
const SECTIONS := ["Builds", "Monsters", "Bosses", "Weapons", "Marginal values", "Economy", "Compound checks", "Content"]

## Shown at the top of report.md.
var title := "Balance report"
## Lines under the title (what was run, with which seed...).
var notes: PackedStringArray = []
## { severity, category, subject, value, target, message }.
var flags: Array[Dictionary] = []
## Ordered tables: { name, section, caption, columns: PackedStringArray, rows: Array (of Arrays), md_rows: int }.
var tables: Array[Dictionary] = []
## Everything else, written to data.json as is.
var data := {}
## Real seconds each mode took ({ "model": 1.2, ... }).
var timings := {}


## A number that breaks a target. `value` and `target` as text ("82 s", "40-100 s").
func flag(severity: String, category: String, subject: String, value: String, target: String, message: String) -> void:
	flags.append({
		"severity": severity, "category": category, "subject": subject,
		"value": value, "target": target, "message": message,
	})


## A table. `md_rows`: how many rows report.md shows (-1: all; the CSV always has them all).
## `json_rows` false: data.json keeps only the caption (the same rows are in `data` already).
func table(table_name: String, section: String, caption: String, columns: PackedStringArray, rows: Array, md_rows: int = -1, json_rows: bool = true) -> void:
	if not SECTIONS.has(section):
		push_warning("balance: unknown report section %s" % section)
	tables.append({ "name": table_name, "section": section, "caption": caption, "columns": columns, "rows": rows, "md_rows": md_rows, "json_rows": json_rows })


## Adds another report's flags, tables, data (under `key`) and notes.
func merge(other: BalanceReport, key: String) -> void:
	flags.append_array(other.flags)
	tables.append_array(other.tables)
	data[key] = other.data
	for note in other.notes:
		notes.append("%s: %s" % [key, note])
	timings.merge(other.timings)


func error_count() -> int:
	return flags.filter(func(f: Dictionary) -> bool: return f.severity == ERROR).size()


func warn_count() -> int:
	return flags.filter(func(f: Dictionary) -> bool: return f.severity == WARN).size()


## Errors first, then by category, then subject. Numbered F1, F2... in this order.
func sorted_flags() -> Array[Dictionary]:
	var result := flags.duplicate()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.severity != b.severity:
			return a.severity == ERROR
		if a.category != b.category:
			return a.category < b.category
		return a.subject.naturalnocasecmp_to(b.subject) < 0)
	for i in result.size():
		result[i]["id"] = "F%d" % (i + 1)
	return result


## Flags per category: { category: [errors, warnings] }.
func flag_counts() -> Dictionary:
	var result := {}
	for f in flags:
		if not result.has(f.category):
			result[f.category] = [0, 0]
		result[f.category][0 if f.severity == ERROR else 1] += 1
	return result


## Tables grouped by section in SECTIONS order, each numbered "2.3".
func numbered_tables() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var section_number := 0
	for section: String in SECTIONS + ["Other"]:
		var in_section := tables.filter(func(t: Dictionary) -> bool:
			return t.section == section or (section == "Other" and not SECTIONS.has(t.section)))
		if in_section.is_empty():
			continue
		section_number += 1
		var index := 0
		for t: Dictionary in in_section:
			index += 1
			var copy := t.duplicate()
			copy["number"] = "%d.%d" % [section_number, index]
			copy["section_number"] = section_number
			copy["section_title"] = section
			result.append(copy)
	return result


func to_markdown() -> String:
	var lines := PackedStringArray()
	lines.append("# %s" % title)
	lines.append("")
	for note in notes:
		lines.append("- " + note)
	lines.append("")
	var numbered := numbered_tables()
	lines.append("## Contents")
	lines.append("")
	lines.append("- FLAGS (%d errors, %d warnings)" % [error_count(), warn_count()])
	var last_section := ""
	for t in numbered:
		if t.section_title != last_section:
			last_section = t.section_title
			lines.append("- %d. %s" % [t.section_number, last_section])
		lines.append("  - %s %s" % [t.number, _cell(t.caption).left(110)])
	lines.append("")
	lines.append("## FLAGS (%d errors, %d warnings)" % [error_count(), warn_count()])
	lines.append("")
	if flags.is_empty():
		lines.append("No target broken.")
	else:
		lines.append("By category:")
		lines.append("")
		lines.append("| Category | Errors | Warnings |")
		lines.append("|---|---|---|")
		var counts := flag_counts()
		var categories := counts.keys()
		categories.sort()
		for c: String in categories:
			lines.append("| %s | %d | %d |" % [c, counts[c][0], counts[c][1]])
		lines.append("")
		lines.append("| # | Severity | Category | Subject | Value | Target | What |")
		lines.append("|---|---|---|---|---|---|---|")
		for f in sorted_flags():
			lines.append("| %s | %s | %s | %s | %s | %s | %s |" % [f.id, f.severity.to_upper(), f.category, _cell(f.subject), _cell(f.value), _cell(f.target), _cell(f.message)])
	lines.append("")
	last_section = ""
	for t in numbered:
		if t.section_title != last_section:
			last_section = t.section_title
			lines.append("# %d. %s" % [t.section_number, last_section])
			lines.append("")
		lines.append("## %s %s" % [t.number, t.caption])
		lines.append("")
		var columns: PackedStringArray = t.columns
		lines.append("| " + " | ".join(columns) + " |")
		var separator := PackedStringArray()
		for c in columns:
			separator.append("---")
		lines.append("|" + "|".join(separator) + "|")
		var rows: Array = t.rows
		var shown: int = rows.size() if t.md_rows < 0 else mini(t.md_rows, rows.size())
		for i in shown:
			var cells := PackedStringArray()
			for value: Variant in rows[i]:
				cells.append(_cell(_text(value)))
			lines.append("| " + " | ".join(cells) + " |")
		if rows.is_empty():
			lines.append("")
			lines.append("(no rows)")
		if shown < rows.size():
			lines.append("")
			lines.append("(%d more rows in %s.csv and data.json)" % [rows.size() - shown, t.name])
		lines.append("")
	return "\n".join(lines)


func to_json() -> String:
	var out := data.duplicate()
	out["title"] = title
	out["flags"] = sorted_flags()
	out["notes"] = notes
	out["timings_s"] = timings
	var table_data := {}
	for t in numbered_tables():
		var rows: Array = []
		var columns: PackedStringArray = t.columns
		if not t.get("json_rows", true):
			table_data[t.name] = { "number": t.number, "section": t.section_title, "caption": t.caption, "rows": "in csv/%s.csv and in data (same values)" % t.name }
			continue
		for row: Array in t.rows:
			var entry := {}
			for i in mini(columns.size(), row.size()):
				entry[columns[i]] = _json_value(row[i])
			rows.append(entry)
		table_data[t.name] = { "number": t.number, "section": t.section_title, "caption": t.caption, "rows": rows }
	out["tables"] = table_data
	return JSON.stringify(_json_value(out), "  ", false)


## JSON has no inf/nan: they become strings.
static func _json_value(value: Variant) -> Variant:
	if value is float:
		if is_inf(value):
			return "inf" if value > 0 else "-inf"
		if is_nan(value):
			return "nan"
		return value
	if value is Dictionary:
		var result := {}
		for k: Variant in value:
			result[k] = _json_value(value[k])
		return result
	if value is Array:
		return (value as Array).map(func(v: Variant) -> Variant: return _json_value(v))
	if value is PackedFloat32Array or value is PackedFloat64Array:
		return Array(value).map(func(v: Variant) -> Variant: return _json_value(v))
	return value


## Everything, to be read back by load_state() (a part run in another process, --jobs).
## Everything in memory, to keep (BalanceJobs) and rebuild with from_state().
func to_state() -> Dictionary:
	return { "title": title, "notes": notes, "flags": flags, "tables": tables, "data": data, "timings": timings }


static func from_state(state: Dictionary) -> BalanceReport:
	var report := BalanceReport.new()
	report.title = state.get("title", "?")
	report.notes = PackedStringArray(state.get("notes", []))
	for f: Dictionary in state.get("flags", []):
		report.flags.append(f)
	for t: Dictionary in state.get("tables", []):
		report.tables.append(t)
	report.data = state.get("data", {})
	report.timings = state.get("timings", {})
	return report


func save_state(path: String) -> void:
	var state := { "title": title, "notes": Array(notes), "flags": flags, "tables": tables.map(func(t: Dictionary) -> Dictionary:
		var copy := t.duplicate()
		copy.columns = Array(t.columns)
		return copy), "data": data, "timings": timings }
	_write_file(path, JSON.stringify(_json_value(state)))


static func load_state(path: String) -> BalanceReport:
	var text := FileAccess.get_file_as_string(path)
	var state: Variant = JSON.parse_string(text)
	if not state is Dictionary:
		return null
	var report := BalanceReport.new()
	report.title = state.get("title", "?")
	report.notes = PackedStringArray(state.get("notes", []))
	for f: Dictionary in state.get("flags", []):
		report.flags.append(f)
	for t: Dictionary in state.get("tables", []):
		t.columns = PackedStringArray(t.columns)
		t.md_rows = int(t.md_rows)
		# JSON made every number a float: whole ones back to ints (an act, a count).
		t.rows = (t.rows as Array).map(func(row: Array) -> Array:
			return row.map(func(v: Variant) -> Variant:
				if v is float and is_finite(v) and v == floorf(v) and absf(v) < 1e9:
					return int(v)
				return v))
		report.tables.append(t)
	report.data = state.get("data", {})
	report.timings = state.get("timings", {})
	return report


## Writes report.md, data.json and <table>.csv into `dir` (made if needed). Returns `dir`.
func write(dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	_write_file(dir.path_join("report.md"), to_markdown())
	_write_file(dir.path_join("data.json"), to_json())
	DirAccess.make_dir_recursive_absolute(dir.path_join("csv"))
	for t in tables:
		var lines := PackedStringArray()
		lines.append(",".join(_csv_row(Array(t.columns))))
		for row: Array in t.rows:
			lines.append(",".join(_csv_row(row)))
		_write_file(dir.path_join("csv").path_join("%s.csv" % t.name), "\n".join(lines) + "\n")
	return dir


## A few lines for stdout: counts per category and the worst offenders.
func summary(max_lines: int = 12) -> String:
	var lines := PackedStringArray()
	lines.append("%s: %d errors, %d warnings, %d tables" % [title, error_count(), warn_count(), tables.size()])
	var counts := flag_counts()
	var categories := counts.keys()
	categories.sort()
	for c: String in categories:
		lines.append("  %-34s %3d errors %4d warnings" % [c, counts[c][0], counts[c][1]])
	var shown := 0
	for f in sorted_flags():
		if shown >= max_lines:
			lines.append("  ... %d more in report.md" % (flags.size() - shown))
			break
		lines.append("  %s [%s] %s | %s: %s (target %s)" % [f.id, f.severity.to_upper(), f.category, f.subject, f.value, f.target])
		shown += 1
	return "\n".join(lines)


static func _write_file(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("balance: can't write %s" % path)
		return
	file.store_string(text)
	file.close()


static func _csv_row(row: Array) -> PackedStringArray:
	var cells := PackedStringArray()
	for value: Variant in row:
		var text := _text(value)
		if text.contains(",") or text.contains("\"") or text.contains("\n"):
			text = "\"" + text.replace("\"", "\"\"") + "\""
		cells.append(text)
	return cells


static func _cell(text: String) -> String:
	return text.replace("|", "/").replace("\n", " ")


## Numbers rounded for reading (the JSON keeps them whole).
static func _text(value: Variant) -> String:
	if value is float:
		var number := value as float
		if is_inf(number):
			return "inf"
		if is_nan(number):
			return "-"
		if absf(number) >= 100.0:
			return "%.0f" % number
		if absf(number) >= 10.0:
			return "%.1f" % number
		return "%.2f" % number
	if value is PackedStringArray:
		return ", ".join(value)
	return str(value)


## "1.2 s" style helpers.
static func secs(value: float) -> String:
	return "inf" if is_inf(value) else "%.1f s" % value


static func pct(value: float) -> String:
	if is_inf(value) or is_nan(value):
		return "-"
	return "%d%%" % roundi(value * 100.0)


## "+12%" / "-3%".
static func delta(value: float) -> String:
	if is_inf(value) or is_nan(value):
		return "-"
	return "%+d%%" % roundi(value * 100.0)
