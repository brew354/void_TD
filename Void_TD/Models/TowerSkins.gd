## TowerSkins.gd — Persisted tower color overrides
class_name TowerSkins

# Maps TowerType int → Color override.  Missing key = use default color.
static var overrides: Dictionary = {}
# Maps TowerType int → skin name string (e.g. "void").  Missing = no named skin.
static var named_skins: Dictionary = {}
# Set of unlocked code strings → true
static var unlocked_codes: Dictionary = {}
# Set of purchased skin keys → true  (e.g. "ducky_0")
static var purchased_skins: Dictionary = {}
# Player coin balance
static var coins: int = 0

const _SAVE_PATH  = "user://void_td_save.cfg"
const _SECTION    = "skins"
const _CODES_SEC  = "codes"
const _NAMED_SEC  = "named_skins"
const _SHOP_SEC   = "shop"

const VOID_COLOR := Color(0.25, 0.0, 0.5)
const VOID_TOWERS: Array = [0, 2, 4]

const DUCKY_COLOR := Color(1.0, 0.85, 0.0)
const DUCKY_TOWERS: Array = [0]

const COIN_REWARD_WIN  := 150
const COIN_REWARD_LOSE := 50

static func load_from_disk() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(_SAVE_PATH) != OK:
		return
	overrides.clear()
	named_skins.clear()
	unlocked_codes.clear()
	purchased_skins.clear()
	if cfg.has_section(_SECTION):
		for key in cfg.get_section_keys(_SECTION):
			var val = cfg.get_value(_SECTION, key)
			if val is Color:
				overrides[int(key)] = val
	if cfg.has_section(_CODES_SEC):
		for key in cfg.get_section_keys(_CODES_SEC):
			unlocked_codes[key] = true
	if cfg.has_section(_NAMED_SEC):
		for key in cfg.get_section_keys(_NAMED_SEC):
			var val = cfg.get_value(_NAMED_SEC, key)
			if val is String:
				named_skins[int(key)] = val
	if cfg.has_section(_SHOP_SEC):
		for key in cfg.get_section_keys(_SHOP_SEC):
			if key == "coins":
				coins = cfg.get_value(_SHOP_SEC, key, 0)
			else:
				purchased_skins[key] = true

static func set_color(tower_idx: int, color: Color) -> void:
	overrides[tower_idx] = color
	named_skins.erase(tower_idx)
	_save()

static func reset_color(tower_idx: int) -> void:
	overrides.erase(tower_idx)
	named_skins.erase(tower_idx)
	_save()

static func get_color(tower_idx: int, default_color: Color) -> Color:
	if named_skins.has(tower_idx):
		var skin_name: String = named_skins[tower_idx]
		if skin_name == "void":
			return VOID_COLOR
		if skin_name == "ducky":
			return DUCKY_COLOR
	return overrides.get(tower_idx, default_color)

const CODE_SERVER_URL := "http://localhost:5050"

static func unlock_code_local(code: String) -> void:
	unlocked_codes[code] = true
	_save()

static func is_code_unlocked(code: String) -> bool:
	return unlocked_codes.has(code)

static func set_named_skin(tower_idx: int, skin_name: String) -> void:
	named_skins[tower_idx] = skin_name
	overrides.erase(tower_idx)
	_save()

static func clear_named_skin(tower_idx: int) -> void:
	named_skins.erase(tower_idx)
	_save()

static func add_coins(amount: int) -> void:
	coins += amount
	_save()

static func purchase_skin(skin_key: String, cost: int) -> bool:
	if coins < cost or purchased_skins.has(skin_key):
		return false
	coins -= cost
	purchased_skins[skin_key] = true
	_save()
	return true

static func has_skin(skin_key: String) -> bool:
	return purchased_skins.has(skin_key)

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
	# Save unlocked codes
	for code in unlocked_codes:
		cfg.set_value(_CODES_SEC, code, true)
	# Save named skins
	if cfg.has_section(_NAMED_SEC):
		for key in cfg.get_section_keys(_NAMED_SEC):
			if not named_skins.has(int(key)):
				cfg.erase_section_key(_NAMED_SEC, key)
	for idx in named_skins:
		cfg.set_value(_NAMED_SEC, str(idx), named_skins[idx])
	# Save shop data (coins + purchased skins)
	cfg.set_value(_SHOP_SEC, "coins", coins)
	for skin_key in purchased_skins:
		cfg.set_value(_SHOP_SEC, skin_key, true)
	cfg.save(_SAVE_PATH)
