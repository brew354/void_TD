## MenuScene.gd — Title screen
class_name MenuScene
extends Node2D

const SAVE_PATH       = "user://void_td_save.cfg"
const GameMode        = preload("res://Models/GameMode.gd")
const TowerDefinition = preload("res://Models/TowerDefinition.gd")
const TowerSkins      = preload("res://Models/TowerSkins.gd")

# Palette offered in the skins panel
const _PALETTE: Array = [
	Color(1.0, 1.0, 1.0),    # White
	Color(1.0, 0.2, 0.2),    # Red
	Color(1.0, 0.6, 0.1),    # Orange
	Color(1.0, 0.95, 0.1),   # Yellow
	Color(0.15, 0.85, 0.2),  # Green
	Color(0.1,  0.9,  0.9),  # Cyan
	Color(0.2,  0.5,  1.0),  # Blue
	Color(0.6,  0.1,  1.0),  # Purple
	Color(1.0,  0.2,  0.85), # Pink
]

const _DEFAULT_COLORS: Array = [
	Color(1.0, 1.0, 1.0),  # Laser Turret  — natural sprite (no tint)
	Color(1.0, 1.0, 1.0),  # Plasma Cannon — natural sprite (no tint)
	Color(1.0, 1.0, 1.0),  # Void-Seeker   — natural sprite (no tint)
	Color(1.0, 1.0, 1.0),  # Titan Mech    — natural sprite (no tint)
	Color(1.0, 1.0, 1.0),  # Void Stunner  — natural sprite (no tint)
]

var _title: Label
var _stars: Array = []
var _time: float = 0.0
var _skin_panel: Node2D = null
var _codes_panel: Node2D = null
var _codes_input: LineEdit = null
var _codes_msg: Label = null
var _codes_submit_btn: Button = null
var _http_request: HTTPRequest = null
var _void_buttons: Array = []         # Array[Button] one per tower row (null if not applicable)
var _ducky_buttons: Array = []        # Array[Button] one per tower row (null if not applicable)
var _shop_panel: Node2D = null
var _shop_coins_lbl: Label = null

# ── Ambient music synthesis ───────────────────────────────────────────────────
const _MIX_RATE   := 22050.0
# Frequencies: deep bass A1, E2, A2, slight detune for chorus
const _FREQS: Array = [55.0, 82.41, 110.03, 146.85, 220.07]
const _AMPS:  Array = [0.26, 0.14,  0.18,   0.09,   0.07]
var _ambient_player: AudioStreamPlayer = null
var _ambient_pb: AudioStreamGeneratorPlayback = null
var _osc_phase: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
var _lfo_t: float = 0.0
var _skin_previews: Array = []        # Array[ColorRect]  one per tower row
var _swatch_borders: Array = []       # Array[Array[ColorRect]]  [tower][palette]

func _ready() -> void:
	TowerSkins.load_from_disk()

	var vp := get_viewport_rect().size

	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.size = vp
	bg.position = Vector2.ZERO
	add_child(bg)

	# Twinkling star field
	for i in range(160):
		var star = ColorRect.new()
		var sz = randf_range(1.0, 3.0)
		star.size = Vector2(sz, sz)
		star.position = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
		star.color = Color(randf_range(0.6, 1.0), randf_range(0.2, 0.5), 1.0)
		add_child(star)
		_stars.append(star)

	# Title
	_title = Label.new()
	_title.text = "VOID_TD"
	_title.position = Vector2(0, 180)
	_title.size = Vector2(1334, 100)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 72)
	_title.add_theme_color_override("font_color", Color(0.8, 0.1, 1.0))
	_title.modulate.a = 0.0
	add_child(_title)

	var sub = Label.new()
	sub.text = "a void tower defense game"
	sub.position = Vector2(0, 286)
	sub.size = Vector2(1334, 36)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.75, 0.4, 1.0))
	sub.modulate.a = 0.0
	add_child(sub)

	var made_by = Label.new()
	made_by.text = "made by Findog_Games"
	made_by.position = Vector2(0, 320)
	made_by.size = Vector2(1334, 36)
	made_by.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	made_by.add_theme_font_size_override("font_size", 18)
	made_by.add_theme_color_override("font_color", Color(0.55, 0.45, 0.7))
	made_by.modulate.a = 0.0
	add_child(made_by)

	# Campaign button
	var btn_campaign = Button.new()
	btn_campaign.text = "CAMPAIGN"
	btn_campaign.size = Vector2(240, 60)
	btn_campaign.position = Vector2(1334 / 2.0 - 260, 420)
	btn_campaign.add_theme_font_size_override("font_size", 26)
	btn_campaign.modulate.a = 0.0
	btn_campaign.pressed.connect(_on_start_campaign)
	add_child(btn_campaign)

	# Endless button
	var btn_endless = Button.new()
	btn_endless.text = "ENDLESS"
	btn_endless.size = Vector2(240, 60)
	btn_endless.position = Vector2(1334 / 2.0 + 20, 420)
	btn_endless.add_theme_font_size_override("font_size", 26)
	btn_endless.modulate.a = 0.0
	btn_endless.pressed.connect(_on_start_endless)
	add_child(btn_endless)

	# Mode descriptions
	var lbl_c = Label.new()
	lbl_c.text = "20 Assaults · Defeat The Void"
	lbl_c.position = Vector2(1334 / 2.0 - 280, 488)
	lbl_c.size = Vector2(280, 28)
	lbl_c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_c.add_theme_font_size_override("font_size", 15)
	lbl_c.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	lbl_c.modulate.a = 0.0
	add_child(lbl_c)

	var lbl_e = Label.new()
	lbl_e.text = "Survive as long as possible"
	lbl_e.position = Vector2(1334 / 2.0, 488)
	lbl_e.size = Vector2(280, 28)
	lbl_e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_e.add_theme_font_size_override("font_size", 15)
	lbl_e.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
	lbl_e.modulate.a = 0.0
	add_child(lbl_e)

	# Skins / Shop / Codes buttons — side by side
	var btn_skins = Button.new()
	btn_skins.text = "SKINS"
	btn_skins.size = Vector2(140, 44)
	btn_skins.position = Vector2(1334 / 2.0 - 225, 528)
	btn_skins.add_theme_font_size_override("font_size", 20)
	btn_skins.modulate.a = 0.0
	btn_skins.pressed.connect(_on_skins_btn)
	add_child(btn_skins)

	var btn_shop = Button.new()
	btn_shop.text = "SHOP"
	btn_shop.size = Vector2(140, 44)
	btn_shop.position = Vector2(1334 / 2.0 - 70, 528)
	btn_shop.add_theme_font_size_override("font_size", 20)
	btn_shop.modulate.a = 0.0
	btn_shop.pressed.connect(_on_shop_btn)
	add_child(btn_shop)

	var btn_codes = Button.new()
	btn_codes.text = "CODES"
	btn_codes.size = Vector2(140, 44)
	btn_codes.position = Vector2(1334 / 2.0 + 85, 528)
	btn_codes.add_theme_font_size_override("font_size", 20)
	btn_codes.modulate.a = 0.0
	btn_codes.pressed.connect(_on_codes_btn)
	add_child(btn_codes)

	# High score display
	var cfg = ConfigFile.new()
	cfg.load(SAVE_PATH)
	var hs: int = cfg.get_value("game", "high_score", 0)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(_title,       "modulate:a", 1.0, 1.2)
	tween.tween_property(sub,          "modulate:a", 1.0, 0.8).set_delay(0.9)
	tween.tween_property(made_by,      "modulate:a", 1.0, 0.8).set_delay(1.1)
	tween.tween_property(btn_campaign, "modulate:a", 1.0, 0.8).set_delay(1.6)
	tween.tween_property(btn_endless,  "modulate:a", 1.0, 0.8).set_delay(1.6)
	tween.tween_property(lbl_c,        "modulate:a", 1.0, 0.8).set_delay(1.8)
	tween.tween_property(lbl_e,        "modulate:a", 1.0, 0.8).set_delay(1.8)
	tween.tween_property(btn_skins,    "modulate:a", 1.0, 0.8).set_delay(2.0)
	tween.tween_property(btn_shop,     "modulate:a", 1.0, 0.8).set_delay(2.0)
	tween.tween_property(btn_codes,    "modulate:a", 1.0, 0.8).set_delay(2.0)

	if hs > 0:
		var hs_lbl = Label.new()
		hs_lbl.text = "Best Score: %d" % hs
		hs_lbl.position = Vector2(0, 588)
		hs_lbl.size = Vector2(1334, 36)
		hs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hs_lbl.add_theme_font_size_override("font_size", 22)
		hs_lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
		hs_lbl.modulate.a = 0.0
		add_child(hs_lbl)
		tween.tween_property(hs_lbl, "modulate:a", 1.0, 0.8).set_delay(2.2)

	_build_skin_panel()
	_build_shop_panel()
	_build_codes_panel()
	_start_ambient_music()

func _build_skin_panel() -> void:
	_skin_panel = Node2D.new()
	_skin_panel.visible = false
	add_child(_skin_panel)

	# ── Full-screen background ────────────────────────────────────────────────
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.0, 0.08)
	bg.size = get_viewport_rect().size
	bg.position = Vector2.ZERO
	_skin_panel.add_child(bg)

	# ── Header ────────────────────────────────────────────────────────────────
	const HEADER_H: float = 68.0
	var header = ColorRect.new()
	header.color = Color(0.15, 0.0, 0.26)
	header.size = Vector2(1334, HEADER_H)
	header.position = Vector2.ZERO
	_skin_panel.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = "Tower Skins"
	title_lbl.size = Vector2(1334, HEADER_H)
	title_lbl.position = Vector2.ZERO
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	_skin_panel.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.size = Vector2(44, 44)
	close_btn.position = Vector2(1334 - 52, 12)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(func(): _skin_panel.visible = false)
	_skin_panel.add_child(close_btn)

	# ── Layout constants ──────────────────────────────────────────────────────
	const ROW_H:    float = 130.0
	const SW_SZ:    float = 52.0   # swatch size
	const SW_GAP:   float = 8.0
	const LM:       float = 173.0  # left margin (symmetric with right)
	const NAME_W:   float = 180.0
	const PREV_SZ:  float = 52.0
	const SP_W:     float = 90.0   # special skin button width
	const DEF_X:    float = 1059.0 # Default button x (fixed for all rows)
	const DEF_W:    float = 102.0

	# Vertically center the 4 rows in the space below the header
	var rows_total: float = ROW_H * 5.0
	var row_start_y: float = HEADER_H + (750.0 - HEADER_H - rows_total) / 2.0

	var tower_labels = ["Laser Turret", "Plasma Cannon", "Void-Seeker", "Titan Mech", "Void Stunner"]

	_void_buttons.clear()
	_ducky_buttons.clear()
	for ti in 5:
		var row_y: float = row_start_y + ti * ROW_H
		var item_y: float = row_y + (ROW_H - SW_SZ) / 2.0   # vertically center items in row

		# Subtle row separator
		if ti > 0:
			var sep = ColorRect.new()
			sep.color = Color(0.2, 0.0, 0.35, 0.4)
			sep.size = Vector2(1334, 1)
			sep.position = Vector2(0, row_y)
			_skin_panel.add_child(sep)

		# Tower name label
		var name_lbl = Label.new()
		name_lbl.text = tower_labels[ti]
		name_lbl.position = Vector2(LM, row_y + (ROW_H - 24) / 2.0)
		name_lbl.size = Vector2(NAME_W, 24)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
		_skin_panel.add_child(name_lbl)

		# Current color preview square
		var preview = ColorRect.new()
		preview.size = Vector2(PREV_SZ, PREV_SZ)
		preview.position = Vector2(LM + NAME_W + 10.0, item_y)
		preview.color = TowerSkins.get_color(ti, _DEFAULT_COLORS[ti])
		_skin_panel.add_child(preview)
		_skin_previews.append(preview)

		# Palette swatches
		var sw_start_x: float = LM + NAME_W + 10.0 + PREV_SZ + 10.0
		var row_borders: Array = []
		for ci in _PALETTE.size():
			var sx: float = sw_start_x + ci * (SW_SZ + SW_GAP)

			var border = ColorRect.new()
			border.color = Color(1.0, 1.0, 0.3)
			border.size = Vector2(SW_SZ + 4, SW_SZ + 4)
			border.position = Vector2(sx - 2, item_y - 2)
			var current = TowerSkins.overrides.get(ti, Color(-1, -1, -1))
			border.visible = (current == _PALETTE[ci])
			_skin_panel.add_child(border)
			row_borders.append(border)

			var swatch = Button.new()
			swatch.size = Vector2(SW_SZ, SW_SZ)
			swatch.position = Vector2(sx, item_y)
			var flat = StyleBoxFlat.new()
			flat.bg_color = _PALETTE[ci]
			swatch.add_theme_stylebox_override("normal",  flat)
			swatch.add_theme_stylebox_override("hover",   flat)
			swatch.add_theme_stylebox_override("pressed", flat)
			swatch.add_theme_stylebox_override("focus",   flat)
			var cap_ti = ti
			var cap_ci = ci
			swatch.pressed.connect(func(): _on_swatch_pressed(cap_ti, cap_ci))
			_skin_panel.add_child(swatch)

		_swatch_borders.append(row_borders)

		# Special named skin buttons
		var sp_x: float = sw_start_x + 9.0 * (SW_SZ + SW_GAP) + 10.0

		# Default button — fixed x so it lines up across all rows
		var reset_btn = Button.new()
		reset_btn.text = "Default"
		reset_btn.size = Vector2(DEF_W, 38)
		reset_btn.position = Vector2(DEF_X, row_y + (ROW_H - 38) / 2.0)
		reset_btn.add_theme_font_size_override("font_size", 14)
		var cap_ti2 = ti
		reset_btn.pressed.connect(func(): _on_reset_skin(cap_ti2))
		_skin_panel.add_child(reset_btn)

		# Special skin buttons — placed after Default, spaced by SP_W + 8
		var next_sp_x: float = DEF_X + DEF_W + 8.0

		# Void skin button (only for eligible towers, only when code unlocked)
		if ti in TowerSkins.VOID_TOWERS:
			var void_btn = Button.new()
			void_btn.text = "Void"
			void_btn.size = Vector2(SP_W, 38)
			void_btn.position = Vector2(next_sp_x, row_y + (ROW_H - 38) / 2.0)
			void_btn.add_theme_font_size_override("font_size", 14)
			var void_flat = StyleBoxFlat.new()
			void_flat.bg_color = Color(0.12, 0.0, 0.22)
			void_flat.border_color = Color(0.5, 0.0, 0.8)
			void_flat.border_width_bottom = 2
			void_flat.border_width_top = 2
			void_flat.border_width_left = 2
			void_flat.border_width_right = 2
			void_btn.add_theme_stylebox_override("normal", void_flat)
			var void_hover = void_flat.duplicate()
			void_hover.bg_color = Color(0.2, 0.0, 0.35)
			void_btn.add_theme_stylebox_override("hover", void_hover)
			void_btn.add_theme_stylebox_override("pressed", void_flat)
			void_btn.add_theme_color_override("font_color", Color(0.7, 0.3, 1.0))
			var cap_ti3 = ti
			void_btn.pressed.connect(func(): _on_void_skin(cap_ti3))
			void_btn.visible = TowerSkins.is_code_unlocked("friendvoid")
			_skin_panel.add_child(void_btn)
			_void_buttons.append(void_btn)
			next_sp_x += SP_W + 8.0
		else:
			_void_buttons.append(null)

		# Ducky skin button (only for eligible towers, only when purchased)
		if ti in TowerSkins.DUCKY_TOWERS:
			var ducky_btn = Button.new()
			ducky_btn.text = "Ducky"
			ducky_btn.size = Vector2(SP_W, 38)
			ducky_btn.position = Vector2(next_sp_x, row_y + (ROW_H - 38) / 2.0)
			ducky_btn.add_theme_font_size_override("font_size", 14)
			var ducky_flat = StyleBoxFlat.new()
			ducky_flat.bg_color = Color(0.35, 0.28, 0.0)
			ducky_flat.border_color = Color(1.0, 0.85, 0.0)
			ducky_flat.border_width_bottom = 2
			ducky_flat.border_width_top = 2
			ducky_flat.border_width_left = 2
			ducky_flat.border_width_right = 2
			ducky_btn.add_theme_stylebox_override("normal", ducky_flat)
			var ducky_hover = ducky_flat.duplicate()
			ducky_hover.bg_color = Color(0.45, 0.38, 0.0)
			ducky_btn.add_theme_stylebox_override("hover", ducky_hover)
			ducky_btn.add_theme_stylebox_override("pressed", ducky_flat)
			ducky_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
			var cap_ti4 = ti
			ducky_btn.pressed.connect(func(): _on_ducky_skin(cap_ti4))
			ducky_btn.visible = TowerSkins.has_skin("ducky_0")
			_skin_panel.add_child(ducky_btn)
			_ducky_buttons.append(ducky_btn)
		else:
			_ducky_buttons.append(null)

func _on_swatch_pressed(tower_idx: int, color_idx: int) -> void:
	var color: Color = _PALETTE[color_idx]
	TowerSkins.set_color(tower_idx, color)
	_skin_previews[tower_idx].color = color
	for ci in _swatch_borders[tower_idx].size():
		_swatch_borders[tower_idx][ci].visible = (ci == color_idx)

func _on_reset_skin(tower_idx: int) -> void:
	TowerSkins.reset_color(tower_idx)
	_skin_previews[tower_idx].color = _DEFAULT_COLORS[tower_idx]
	for border in _swatch_borders[tower_idx]:
		border.visible = false

func _on_void_skin(tower_idx: int) -> void:
	TowerSkins.set_named_skin(tower_idx, "void")
	_skin_previews[tower_idx].color = TowerSkins.VOID_COLOR
	for border in _swatch_borders[tower_idx]:
		border.visible = false

func _on_ducky_skin(tower_idx: int) -> void:
	TowerSkins.set_named_skin(tower_idx, "ducky")
	_skin_previews[tower_idx].color = TowerSkins.DUCKY_COLOR
	for border in _swatch_borders[tower_idx]:
		border.visible = false

func _on_skins_btn() -> void:
	_refresh_void_buttons()
	_refresh_ducky_buttons()
	_skin_panel.visible = true

func _on_shop_btn() -> void:
	_shop_coins_lbl.text = "Coins: %d" % TowerSkins.coins
	_refresh_shop_items()
	_shop_panel.visible = true

func _on_codes_btn() -> void:
	_codes_input.text = ""
	_codes_msg.text = ""
	_codes_panel.visible = true

func _build_codes_panel() -> void:
	_codes_panel = Node2D.new()
	_codes_panel.visible = false
	add_child(_codes_panel)

	_http_request = HTTPRequest.new()
	_http_request.request_completed.connect(_on_redeem_response)
	add_child(_http_request)

	var vp := get_viewport_rect().size

	# Dim overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	overlay.size = vp
	overlay.position = Vector2.ZERO
	_codes_panel.add_child(overlay)

	# Center box
	var box_w: float = 420.0
	var box_h: float = 240.0
	var box_x: float = (vp.x - box_w) / 2.0
	var box_y: float = (vp.y - box_h) / 2.0

	var box = ColorRect.new()
	box.color = Color(0.06, 0.0, 0.12)
	box.size = Vector2(box_w, box_h)
	box.position = Vector2(box_x, box_y)
	_codes_panel.add_child(box)

	var border = ColorRect.new()
	border.color = Color(0.4, 0.0, 0.7)
	border.size = Vector2(box_w + 4, box_h + 4)
	border.position = Vector2(box_x - 2, box_y - 2)
	border.z_index = -1
	_codes_panel.add_child(border)

	var title_lbl = Label.new()
	title_lbl.text = "Enter Code"
	title_lbl.position = Vector2(box_x, box_y + 20)
	title_lbl.size = Vector2(box_w, 30)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	_codes_panel.add_child(title_lbl)

	_codes_input = LineEdit.new()
	_codes_input.placeholder_text = "type code here..."
	_codes_input.size = Vector2(box_w - 60, 40)
	_codes_input.position = Vector2(box_x + 30, box_y + 70)
	_codes_input.add_theme_font_size_override("font_size", 18)
	_codes_input.text_submitted.connect(func(_t): _on_code_submit())
	_codes_panel.add_child(_codes_input)

	_codes_submit_btn = Button.new()
	_codes_submit_btn.text = "REDEEM"
	_codes_submit_btn.size = Vector2(140, 42)
	_codes_submit_btn.position = Vector2(box_x + (box_w - 140) / 2.0, box_y + 126)
	_codes_submit_btn.add_theme_font_size_override("font_size", 18)
	_codes_submit_btn.pressed.connect(_on_code_submit)
	_codes_panel.add_child(_codes_submit_btn)

	_codes_msg = Label.new()
	_codes_msg.text = ""
	_codes_msg.position = Vector2(box_x, box_y + 180)
	_codes_msg.size = Vector2(box_w, 28)
	_codes_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_codes_msg.add_theme_font_size_override("font_size", 16)
	_codes_panel.add_child(_codes_msg)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.size = Vector2(36, 36)
	close_btn.position = Vector2(box_x + box_w - 42, box_y + 6)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(func(): _codes_panel.visible = false)
	_codes_panel.add_child(close_btn)

func _on_code_submit() -> void:
	var code := _codes_input.text.strip_edges().to_lower()
	if code.is_empty():
		return
	# Infinite-use coin codes — handled locally, no server needed
	if code == "savanfo":
		TowerSkins.add_coins(400)
		_codes_msg.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		_codes_msg.text = "+400 coins! (Total: %d)" % TowerSkins.coins
		return
	if TowerSkins.is_code_unlocked(code):
		_codes_msg.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3))
		_codes_msg.text = "Code already redeemed!"
		return
	_codes_submit_btn.disabled = true
	_codes_msg.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_codes_msg.text = "Checking..."
	var body := JSON.stringify({"code": code})
	var headers := ["Content-Type: application/json"]
	_http_request.request(TowerSkins.CODE_SERVER_URL + "/redeem", headers, HTTPClient.METHOD_POST, body)

func _on_redeem_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_codes_submit_btn.disabled = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_codes_msg.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_codes_msg.text = "Server unreachable. Try again later."
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		_codes_msg.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_codes_msg.text = "Server error. Try again later."
		return
	if json.get("ok", false):
		var code := _codes_input.text.strip_edges().to_lower()
		TowerSkins.unlock_code_local(code)
		_codes_msg.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		var uses: int = json.get("uses", 0)
		var limit: int = json.get("limit", 0)
		_codes_msg.text = "Void skin set unlocked! (%d/%d used)" % [uses, limit]
		_refresh_void_buttons()
	else:
		var err: String = json.get("error", "")
		if err == "max_uses":
			_codes_msg.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			_codes_msg.text = "Code expired! All %d uses claimed." % json.get("limit", 23)
		else:
			_codes_msg.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			_codes_msg.text = "Invalid code."

func _refresh_void_buttons() -> void:
	var unlocked := TowerSkins.is_code_unlocked("friendvoid")
	for btn in _void_buttons:
		if btn != null:
			btn.visible = unlocked

func _refresh_ducky_buttons() -> void:
	var owned := TowerSkins.has_skin("ducky_0")
	for btn in _ducky_buttons:
		if btn != null:
			btn.visible = owned

var _shop_ducky_btn: Button = null
var _shop_ducky_status: Label = null

func _build_shop_panel() -> void:
	_shop_panel = Node2D.new()
	_shop_panel.visible = false
	add_child(_shop_panel)

	var vp := get_viewport_rect().size

	# Dim overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.size = vp
	overlay.position = Vector2.ZERO
	_shop_panel.add_child(overlay)

	# Panel box
	var box_w: float = 500.0
	var box_h: float = 340.0
	var box_x: float = (vp.x - box_w) / 2.0
	var box_y: float = (vp.y - box_h) / 2.0

	var border = ColorRect.new()
	border.color = Color(0.6, 0.5, 0.0)
	border.size = Vector2(box_w + 4, box_h + 4)
	border.position = Vector2(box_x - 2, box_y - 2)
	_shop_panel.add_child(border)

	var box = ColorRect.new()
	box.color = Color(0.06, 0.04, 0.1)
	box.size = Vector2(box_w, box_h)
	box.position = Vector2(box_x, box_y)
	_shop_panel.add_child(box)

	# Header
	var title_lbl = Label.new()
	title_lbl.text = "Shop"
	title_lbl.position = Vector2(box_x, box_y + 16)
	title_lbl.size = Vector2(box_w, 32)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_shop_panel.add_child(title_lbl)

	# Coins display
	_shop_coins_lbl = Label.new()
	_shop_coins_lbl.text = "Coins: %d" % TowerSkins.coins
	_shop_coins_lbl.position = Vector2(box_x, box_y + 54)
	_shop_coins_lbl.size = Vector2(box_w, 24)
	_shop_coins_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shop_coins_lbl.add_theme_font_size_override("font_size", 18)
	_shop_coins_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	_shop_panel.add_child(_shop_coins_lbl)

	# ── Ducky Skin Item ────────────────────────────────────��──────────────────
	var item_y: float = box_y + 100
	var item_x: float = box_x + 30

	# Color preview swatch
	var swatch = ColorRect.new()
	swatch.color = TowerSkins.DUCKY_COLOR
	swatch.size = Vector2(48, 48)
	swatch.position = Vector2(item_x, item_y)
	_shop_panel.add_child(swatch)

	# Item name
	var name_lbl = Label.new()
	name_lbl.text = "Ducky"
	name_lbl.position = Vector2(item_x + 62, item_y + 2)
	name_lbl.size = Vector2(200, 24)
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	_shop_panel.add_child(name_lbl)

	# Item description
	var desc_lbl = Label.new()
	desc_lbl.text = "Laser Turret skin — golden rubber ducky tint"
	desc_lbl.position = Vector2(item_x + 62, item_y + 28)
	desc_lbl.size = Vector2(300, 20)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	_shop_panel.add_child(desc_lbl)

	# Buy button
	_shop_ducky_btn = Button.new()
	_shop_ducky_btn.text = "200 coins"
	_shop_ducky_btn.size = Vector2(120, 38)
	_shop_ducky_btn.position = Vector2(box_x + box_w - 155, item_y + 5)
	_shop_ducky_btn.add_theme_font_size_override("font_size", 15)
	_shop_ducky_btn.pressed.connect(_on_buy_ducky)
	_shop_panel.add_child(_shop_ducky_btn)

	# Status label (shows "Owned" or "Not enough coins")
	_shop_ducky_status = Label.new()
	_shop_ducky_status.text = ""
	_shop_ducky_status.position = Vector2(item_x, item_y + 60)
	_shop_ducky_status.size = Vector2(box_w - 60, 20)
	_shop_ducky_status.add_theme_font_size_override("font_size", 14)
	_shop_panel.add_child(_shop_ducky_status)

	# How to earn coins info
	var info_lbl = Label.new()
	info_lbl.text = "Earn coins from Campaign:  Win = 150 coins  ·  Defeat = 50 coins"
	info_lbl.position = Vector2(box_x, box_y + box_h - 60)
	info_lbl.size = Vector2(box_w, 20)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.add_theme_font_size_override("font_size", 14)
	info_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.65))
	_shop_panel.add_child(info_lbl)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.size = Vector2(36, 36)
	close_btn.position = Vector2(box_x + box_w - 42, box_y + 6)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(func(): _shop_panel.visible = false)
	_shop_panel.add_child(close_btn)

func _on_buy_ducky() -> void:
	if TowerSkins.has_skin("ducky_0"):
		return
	if TowerSkins.purchase_skin("ducky_0", 200):
		_shop_coins_lbl.text = "Coins: %d" % TowerSkins.coins
		_shop_ducky_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		_shop_ducky_status.text = "Purchased!"
		_shop_ducky_btn.text = "Owned"
		_shop_ducky_btn.disabled = true
		_refresh_ducky_buttons()
	else:
		_shop_ducky_status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_shop_ducky_status.text = "Not enough coins!"

func _refresh_shop_items() -> void:
	if TowerSkins.has_skin("ducky_0"):
		_shop_ducky_btn.text = "Owned"
		_shop_ducky_btn.disabled = true
		_shop_ducky_status.text = ""
	else:
		_shop_ducky_btn.text = "200 coins"
		_shop_ducky_btn.disabled = false
		_shop_ducky_status.text = ""

func _process(delta: float) -> void:
	_time += delta

	# Pulse title between bright and vivid purple
	var pulse = 0.85 + 0.15 * sin(_time * 2.0)
	_title.add_theme_color_override("font_color", Color(0.8 * pulse, 0.1, 1.0 * pulse))

	# Twinkle stars independently
	for i in _stars.size():
		_stars[i].modulate.a = 0.4 + 0.6 * (0.5 + 0.5 * sin(_time * (0.8 + (i % 7) * 0.25) + i))

	# Fill ambient audio buffer
	if _ambient_pb != null:
		_lfo_t += delta
		# Slow tremolo + eerie shimmer LFO
		var lfo := 0.72 + 0.28 * sin(_lfo_t * 0.13 * TAU)
		var shimmer := 1.0 + 0.004 * sin(_lfo_t * 0.37 * TAU)
		var frames := _ambient_pb.get_frames_available()
		for _f in frames:
			var sample := 0.0
			for j in _FREQS.size():
				var freq: float = _FREQS[j] * (shimmer if j >= 3 else 1.0)
				sample += sin(_osc_phase[j] * TAU) * float(_AMPS[j])
				_osc_phase[j] = fmod(_osc_phase[j] + freq / _MIX_RATE, 1.0)
			sample *= lfo
			_ambient_pb.push_frame(Vector2(sample, sample))

func _start_ambient_music() -> void:
	# Use Kevin MacLeod OGG if present, otherwise fall back to synthesized ambient
	var music_path := "res://Assets/audio/music/menu.mp3"
	if ResourceLoader.exists(music_path):
		_ambient_player = AudioStreamPlayer.new()
		_ambient_player.stream = load(music_path)
		_ambient_player.volume_db = -10.0
		add_child(_ambient_player)
		_ambient_player.play()
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = _MIX_RATE
	gen.buffer_length = 0.3
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.stream = gen
	_ambient_player.volume_db = -14.0
	add_child(_ambient_player)
	_ambient_player.play()
	_ambient_pb = _ambient_player.get_stream_playback()

func _on_start_campaign() -> void:
	GameMode.endless = false
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")

func _on_start_endless() -> void:
	GameMode.endless = true
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")
