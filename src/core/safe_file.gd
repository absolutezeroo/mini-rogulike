class_name SafeFile
## Saves that survive the app being killed mid-write: the new content goes to a temporary file
## first, then replaces the old one in one step. A half-written file never replaces a good one.


## Writes `data` as JSON to `path`. Returns false (and warns) if it could not.
static func write_json(path: String, data: Variant) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var dir := DirAccess.open(temp.get_base_dir())
	if dir == null:
		return false
	if dir.rename(temp, path) != OK:
		# Some file systems won't replace a file in one step: replace it in two.
		dir.remove(path)
		if dir.rename(temp, path) != OK:
			push_warning("Could not save %s" % path)
			return false
	return true


## The JSON in `path`, or null if it is missing or damaged. Falls back on a temporary file
## left by a write that was cut short.
static func read_json(path: String) -> Variant:
	for candidate in [path, path + ".tmp"]:
		if FileAccess.file_exists(candidate):
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
			if data != null:
				return data
	return null
