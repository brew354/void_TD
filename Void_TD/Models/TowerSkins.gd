## TowerSkins.gd — Persisted tower color overrides
class_name TowerSkins

# Special named skins
const DUCKY_COLOR: Color = Color(1.0, 0.88, 0.0)   # Rubber duck yellow
const DOGGO_COLOR: Color = Color(0.72, 0.42, 0.12) # Warm dog brown

# Maps TowerType int → Color override.  Missing key = use default color.
static var overrides: Dictionary = {}

const _SAVE_PATH = "user://void_td_save.cfg"
const _SECTION    = "skins"

static func load_from_disk() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(_SAVE_PATH) != OK:
		return
	overrides.clear()
	if not cfg.has_section(_SECTION):
		return
	for key in cfg.get_section_keys(_SECTION):
		var val = cfg.get_value(_SECTION, key)
		if val is Color:
			overrides[int(key)] = val

static func set_color(tower_idx: int, color: Color) -> void:
	overrides[tower_idx] = color
	_save()

static func reset_color(tower_idx: int) -> void:
	overrides.erase(tower_idx)
	_save()

static func get_color(tower_idx: int, default_color: Color) -> Color:
	return overrides.get(tower_idx, default_color)

static func _save() -> void:
	var cfg = ConfigFile.new()
	cfg.load(_SAVE_PATH)          # preserve existing data (high score, etc.)
	for idx in overrides:
		cfg.set_value(_SECTION, str(idx), overrides[idx])
	# Remove keys that were reset
	if cfg.has_section(_SECTION):
		for key in cfg.get_section_keys(_SECTION):
			if not overrides.has(int(key)):
				cfg.erase_section_key(_SECTION, key)
	cfg.save(_SAVE_PATH)
