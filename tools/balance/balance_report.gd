class_name BalanceReport
extends RefCounted
## What a balance run found: FLAGS (numbers that break a target), tables and raw data, written as
## report.md (for people: flags first, then tables), data.json (everything) and one CSV per table.

const ERROR := "error"
const WARN := "warn"

## Shown at the top of report.md.
var title := "Balance report"
## Lines under the title (what was run, with which seed...).
var notes: PackedStringArray = []
## { severity, category, subject, value, target, message, known }.
var flags: Array[Dictionary] = []
## Ordered tables: { name, caption, columns: PackedStringArray, rows: Array (of Arrays), md_rows: int }.
var tables: Array[Dictionary] = []
## Everything else, written to data.json as is.
var data := {}


## A number that breaks a target. `value` and `target` as text ("82 s", "40-100 s").
func flag(severity: String, category: String, subject: String, value: String, target: String, message: String) -> void:
	flags.append({
		"severity": severity, "category": category, "subject": subject,
		"value": value, "target": target, "message": message,
	})


## A table. `md_rows`: how many rows report.md shows (-1: all; the CSV always has them all).
func table(table_name: String, caption: String, columns: PackedStringArray, rows: Array, md_rows: int = -1) -> void:
	tables.append({ "name": table_name, "caption": caption, "columns": columns, "rows": rows, "md_rows": md_rows })


func error_count() -> int:
	return flags.filter(func(f: Dictionary) -> bool: return f.severity == ERROR).size()


func warn_count() -> int:
	return flags.filter(func(f: Dictionary) -> bool: return f.severity == WARN).size()


## Errors first, then by category.
func sorted_flags() -> Array[Dictionary]:
	var result := flags.duplicate()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.severity != b.severity:
			return a.severity == ERROR
		if a.category != b.category:
			return a.category < b.category
		return a.subject < b.subject)
	return result


func to_markdown() -> String:
	var lines := PackedStringArray()
	lines.append("# %s" % title)
	lines.append("")
	for note in notes:
		lines.append(note)
	lines.append("")
	lines.append("## FLAGS (%d errors, %d warnings)" % [error_count(), warn_count()])
	lines.append("")
	if flags.is_empty():
		lines.append("No target broken.")
	else:
		lines.append("| Severity | Category | Subject | Value | Target | What |")
		lines.append("|---|---|---|---|---|---|")
		for f in sorted_flags():
			lines.append("| %s | %s | %s | %s | %s | %s |" % [f.severity.to_upper(), f.category, _cell(f.subject), _cell(f.value), _cell(f.target), _cell(f.message)])
	lines.append("")
	for t in tables:
		lines.append("## %s" % t.caption)
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
		if shown < rows.size():
			lines.append("")
			lines.append("(%d more rows in %s.csv)" % [rows.size() - shown, t.name])
		lines.append("")
	return "\n".join(lines)


func to_json() -> String:
	var out := data.duplicate()
	out["flags"] = sorted_flags()
	out["notes"] = notes
	var table_data := {}
	for t in tables:
		var rows: Array = []
		var columns: PackedStringArray = t.columns
		for row: Array in t.rows:
			var entry := {}
			for i in mini(columns.size(), row.size()):
				entry[columns[i]] = row[i]
			rows.append(entry)
		table_data[t.name] = rows
	out["tables"] = table_data
	return JSON.stringify(out, "  ", false)


## Writes report.md, data.json and <table>.csv into `dir` (made if needed). Returns `dir`.
func write(dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	_write_file(dir.path_join("report.md"), to_markdown())
	_write_file(dir.path_join("data.json"), to_json())
	for t in tables:
		var lines := PackedStringArray()
		lines.append(",".join(_csv_row(Array(t.columns))))
		for row: Array in t.rows:
			lines.append(",".join(_csv_row(row)))
		_write_file(dir.path_join("%s.csv" % t.name), "\n".join(lines) + "\n")
	return dir


## A few lines for stdout: counts and the worst offenders.
func summary(max_lines: int = 12) -> String:
	var lines := PackedStringArray()
	lines.append("%s: %d errors, %d warnings" % [title, error_count(), warn_count()])
	var shown := 0
	for f in sorted_flags():
		if shown >= max_lines:
			lines.append("  ... %d more in report.md" % (flags.size() - shown))
			break
		lines.append("  [%s] %s | %s: %s (target %s)" % [f.severity.to_upper(), f.category, f.subject, f.value, f.target])
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
		if absf(number) >= 100.0:
			return "%.0f" % number
		if absf(number) >= 10.0:
			return "%.1f" % number
		return "%.2f" % number
	return str(value)


## "1.2 s" style helpers.
static func secs(value: float) -> String:
	return "inf" if is_inf(value) else "%.1f s" % value


static func pct(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)
