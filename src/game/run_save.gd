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
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the run: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


## The saved run, or an empty Dictionary if there is none (or it is damaged or too old).
static func read() -> Dictionary:
	if not exists():
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("version", 0)) != VERSION:
		return {}
	return data


static func erase() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path) if path.begins_with("user://") else path)


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
