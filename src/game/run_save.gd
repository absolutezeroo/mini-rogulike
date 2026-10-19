class_name RunSave
## The run in progress, kept on disk (user://run.json) so it survives the app being closed:
## a phone call, the system killing it in the background... Saved when a floor begins and when
## the app goes to the background. Resuming starts a fresh floor at the saved depth, with the hero
## exactly as saved. Erased when the hero dies.
##
## Content (items, perks, skills) is saved by resource path: renaming a .tres breaks old saves
## of runs in progress (only those, never the profile).

const PATH := "user://run.json"
const VERSION := 1

## Empty = nothing is read or written.
static var path := PATH


static func exists() -> bool:
	return not path.is_empty() and FileAccess.file_exists(path)


static func write(data: Dictionary) -> void:
	if path.is_empty():
		return
	data["version"] = VERSION
	SafeFile.write_json(path, data)


## The saved run, or an empty Dictionary if there is none (or it is damaged or too old).
static func read() -> Dictionary:
	if not exists():
		return {}
	var data: Variant = SafeFile.read_json(path)
	if not data is Dictionary or int(data.get("version", 0)) != VERSION:
		return {}
	# A hand-edited or damaged file must not crash the game: check the shapes we rely on.
	for key: String in ["player", "bosses", "offers"]:
		var expected := TYPE_DICTIONARY if key == "player" else TYPE_ARRAY
		if data.has(key) and typeof(data[key]) != expected:
			return {}
	return data


static func erase() -> void:
	for file in [path, path + ".tmp"]:
		if not path.is_empty() and FileAccess.file_exists(file):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(file) if file.begins_with("user://") else file)


# --- Content references ------------------------------------------------------

static func ref(resource: Resource) -> String:
	return resource.resource_path if resource else ""


## Loads a saved reference; null if it is empty or the file is gone.
static func load_ref(reference: Variant) -> Resource:
	var resource_path := str(reference) if reference != null else ""
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		return null
	return load(resource_path)


static func refs(resources: Array) -> Array:
	return resources.map(func(resource: Resource) -> String: return ref(resource))
