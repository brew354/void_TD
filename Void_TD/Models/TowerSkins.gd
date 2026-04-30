## TowerSkins.gd — Persisted tower cosmetics, shop, and loadout
class_name TowerSkins

# Maps TowerType int → Color override.  Missing key = use default color.
static var overrides: Dictionary = {}
# Maps TowerType int → skin name string (e.g. "void").  Missing = no named skin.
static var named_skins: Dictionary = {}
# Set of unlocked code strings → true
static var unlocked_codes: Dictionary = {}
# Set of purchased skin keys → true  (e.g. "ducky_0", "tesla_tower")
static var purchased_skins: Dictionary = {}
# Player coin balance
static var coins: int = 0
# Equipped tower loadout — array of TowerType ints.  Empty = default (all base towers).
static var loadout: Array = []

const _SAVE_PATH   = "user://void_td_save.cfg"
const _SECTION     = "skins"
const _CODES_SEC   = "codes"
const _NAMED_SEC   = "named_skins"
const _SHOP_SEC    = "shop"
const _LOADOUT_SEC = "loadout"
const _META_SEC    = "meta"
const SAVE_VERSION := 1
const MAX_LOADOUT  := 5

const BASE_TOWER_TYPES: Array = [0, 1, 2, 3, 4]

const VOID_COLOR := Color(0.25, 0.0, 0.5)
const VOID_TOWERS: Array = [0, 2, 4]

const DUCKY_COLOR := Color(1.0, 0.85, 0.0)
const DUCKY_TOWERS: Array = [0]

const COIN_REWARD_WIN  := 150
const COIN_REWARD_LOSE := 50

# Replace with your deployed Cloudflare Worker URL before release
const CODE_SERVER_URL := "https://void-td-codes.YOUR_SUBDOMAIN.workers.dev"

static var _dirty: bool = false

# ── Load ──────────────────────────────────────────────────────────────────────

static func load_from_disk() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(_SAVE_PATH) != OK:
		return
	overrides.clear()
	named_skins.clear()
	unlocked_codes.clear()
	purchased_skins.clear()
	loadout.clear()
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
	if cfg.has_section(_LOADOUT_SEC):
		var count: int = cfg.get_value(_LOADOUT_SEC, "count", 0)
		for li in count:
			var val = cfg.get_value(_LOADOUT_SEC, str(li), -1)
			if val >= 0:
				loadout.append(int(val))
	_validate_loadout()

# ── Skins ─────────────────────────────────────────────────────────────────────

static func set_color(tower_idx: int, color: Color) -> void:
	overrides[tower_idx] = color
	named_skins.erase(tower_idx)
	_mark_dirty()

static func reset_color(tower_idx: int) -> void:
	overrides.erase(tower_idx)
	named_skins.erase(tower_idx)
	_mark_dirty()

static func get_color(tower_idx: int, default_color: Color) -> Color:
	if named_skins.has(tower_idx):
		var skin_name: String = named_skins[tower_idx]
		if skin_name == "void":
			return VOID_COLOR
		if skin_name == "ducky":
			return DUCKY_COLOR
	return overrides.get(tower_idx, default_color)

static func set_named_skin(tower_idx: int, skin_name: String) -> void:
	named_skins[tower_idx] = skin_name
	overrides.erase(tower_idx)
	_mark_dirty()

static func clear_named_skin(tower_idx: int) -> void:
	named_skins.erase(tower_idx)
	_mark_dirty()

# ── Codes ─────────────────────────────────────────────────────────────────────

static func unlock_code_local(code: String) -> void:
	unlocked_codes[code] = true
	_save_now()

static func is_code_unlocked(code: String) -> bool:
	return unlocked_codes.has(code)

# ── Shop (monetary — always save immediately) ────────────────────────────────

static func add_coins(amount: int) -> void:
	coins += amount
	_save_now()

static func purchase_skin(skin_key: String, cost: int) -> bool:
	if coins < cost or purchased_skins.has(skin_key):
		return false
	coins -= cost
	purchased_skins[skin_key] = true
	_save_now()
	return true

static func has_skin(skin_key: String) -> bool:
	return purchased_skins.has(skin_key)

# ── Loadout ───────────────────────────────────────────────────────────────────

static func equip_tower(tower_idx: int) -> bool:
	if tower_idx in loadout:
		return false
	if loadout.size() >= MAX_LOADOUT:
		return false
	loadout.append(tower_idx)
	_mark_dirty()
	return true

static func unequip_tower(tower_idx: int) -> void:
	loadout.erase(tower_idx)
	_mark_dirty()

static func is_tower_equipped(tower_idx: int) -> bool:
	if loadout.is_empty():
		return tower_idx in _default_equipped()
	return tower_idx in loadout

static func get_equipped_types() -> Array:
	if loadout.is_empty():
		return _default_equipped()
	return loadout.duplicate()

static func _default_equipped() -> Array:
	var result := BASE_TOWER_TYPES.duplicate()
	if purchased_skins.has("tesla_tower"):
		result.append(5)
	return result

static func materialize_loadout() -> void:
	if not loadout.is_empty():
		return
	loadout = _default_equipped()
	_mark_dirty()

# ── Loadout validation ────────────────────────────────────────────────────────

static func _validate_loadout() -> void:
	var valid_types := BASE_TOWER_TYPES.duplicate()
	if purchased_skins.has("tesla_tower"):
		valid_types.append(5)
	var seen := {}
	var cleaned := []
	for t in loadout:
		if t in valid_types and not seen.has(t):
			cleaned.append(t)
			seen[t] = true
	if cleaned.size() != loadout.size():
		loadout = cleaned
		_save_now()
	else:
		loadout = cleaned

# ── Save (dirty-flag batching) ────────────────────────────────────────────────

static func _mark_dirty() -> void:
	_dirty = true

static func save_if_dirty() -> void:
	if _dirty:
		_save_now()

static func _save_now() -> void:
	_dirty = false
	var cfg = ConfigFile.new()
	cfg.load(_SAVE_PATH)
	cfg.set_value(_META_SEC, "version", SAVE_VERSION)
	for idx in overrides:
		cfg.set_value(_SECTION, str(idx), overrides[idx])
	if cfg.has_section(_SECTION):
		for key in cfg.get_section_keys(_SECTION):
			if not overrides.has(int(key)):
				cfg.erase_section_key(_SECTION, key)
	for code in unlocked_codes:
		cfg.set_value(_CODES_SEC, code, true)
	if cfg.has_section(_NAMED_SEC):
		for key in cfg.get_section_keys(_NAMED_SEC):
			if not named_skins.has(int(key)):
				cfg.erase_section_key(_NAMED_SEC, key)
	for idx in named_skins:
		cfg.set_value(_NAMED_SEC, str(idx), named_skins[idx])
	cfg.set_value(_SHOP_SEC, "coins", coins)
	for skin_key in purchased_skins:
		cfg.set_value(_SHOP_SEC, skin_key, true)
	if cfg.has_section(_LOADOUT_SEC):
		for key in cfg.get_section_keys(_LOADOUT_SEC):
			cfg.erase_section_key(_LOADOUT_SEC, key)
	cfg.set_value(_LOADOUT_SEC, "count", loadout.size())
	for li in loadout.size():
		cfg.set_value(_LOADOUT_SEC, str(li), loadout[li])
	cfg.save(_SAVE_PATH)
