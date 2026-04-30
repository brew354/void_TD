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
	Color(0.3, 0.7, 1.0),  # Tesla Tower   — electric blue tint
]

var _title: Label
var _stars: Array = []
var _time: float = 0.0
var _inv_panel: Node2D = null
var _inv_skins_tab: Control = null
var _inv_towers_tab: Control = null
var _inv_skins_scroll: ScrollContainer = null
var _inv_towers_scroll: ScrollContainer = null
var _inv_tab_btn_skins: Button = null
var _inv_tab_btn_towers: Button = null
var _codes_panel: Node2D = null
var _codes_input: LineEdit = null
var _codes_msg: Label = null
var _codes_submit_btn: Button = null
var _http_request: HTTPRequest = null
var _void_buttons: Array = []         # Array[Button] one per tower row (null if not applicable)
var _ducky_buttons: Array = []        # Array[Button] one per tower row (null if not applicable)
var _shop_panel: Node2D = null
var _shop_coins_lbl: Label = null
var _tower_equip_btns: Array = []     # Array[Button] one per tower type
var _loadout_count_lbl: Label = null

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

	# Inventory / Shop / Codes buttons — side by side
	var btn_inv = Button.new()
	btn_inv.text = "INVENTORY"
	btn_inv.size = Vector2(140, 44)
	btn_inv.position = Vector2(1334 / 2.0 - 225, 528)
	btn_inv.add_theme_font_size_override("font_size", 20)
	btn_inv.modulate.a = 0.0
	btn_inv.pressed.connect(_on_inventory_btn)
	add_child(btn_inv)

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
	tween.tween_property(btn_inv,      "modulate:a", 1.0, 0.8).set_delay(2.0)
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

	_build_inventory_panel()
	_build_shop_panel()
	_build_codes_panel()
	_start_ambient_music()

func _build_inventory_panel() -> void:
	_inv_panel = Node2D.new()
	_inv_panel.visible = false
	add_child(_inv_panel)

	var vp := get_viewport_rect().size

	# ── Full-screen background ────────────────────────────────────────────────
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.0, 0.08)
	bg.size = vp
	bg.position = Vector2.ZERO
	_inv_panel.add_child(bg)

	# ── Header ────────────────────────────────────────────────────────────────
	const HEADER_H: float = 68.0
	var header = ColorRect.new()
	header.color = Color(0.15, 0.0, 0.26)
	header.size = Vector2(1334, HEADER_H)
	header.position = Vector2.ZERO
	_inv_panel.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = "Inventory"
	title_lbl.size = Vector2(1334, HEADER_H)
	title_lbl.position = Vector2.ZERO
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 30)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	_inv_panel.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.size = Vector2(44, 44)
	close_btn.position = Vector2(1334 - 52, 12)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(func(): _inv_panel.visible = false)
	_inv_panel.add_child(close_btn)

	# ── Tab buttons ───────────────────────────────────────────────────────────
	const TAB_Y: float = 68.0
	const TAB_H: float = 40.0
	const TAB_W: float = 160.0

	_inv_tab_btn_skins = Button.new()
	_inv_tab_btn_skins.text = "Skins"
	_inv_tab_btn_skins.size = Vector2(TAB_W, TAB_H)
	_inv_tab_btn_skins.position = Vector2(1334 / 2.0 - TAB_W - 4, TAB_Y)
	_inv_tab_btn_skins.add_theme_font_size_override("font_size", 18)
	_inv_tab_btn_skins.pressed.connect(func(): _switch_inv_tab("skins"))
	_inv_panel.add_child(_inv_tab_btn_skins)

	_inv_tab_btn_towers = Button.new()
	_inv_tab_btn_towers.text = "Towers"
	_inv_tab_btn_towers.size = Vector2(TAB_W, TAB_H)
	_inv_tab_btn_towers.position = Vector2(1334 / 2.0 + 4, TAB_Y)
	_inv_tab_btn_towers.add_theme_font_size_override("font_size", 18)
	_inv_tab_btn_towers.pressed.connect(func(): _switch_inv_tab("towers"))
	_inv_panel.add_child(_inv_tab_btn_towers)

	# ── Scrollable tab area ───────────────────────────────────────────────────
	var content_top: float = HEADER_H + TAB_H + 8.0
	var scroll_h: float = vp.y - content_top

	# Skins tab
	var skins_scroll = ScrollContainer.new()
	skins_scroll.position = Vector2(0, content_top)
	skins_scroll.size = Vector2(vp.x, scroll_h)
	skins_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inv_panel.add_child(skins_scroll)
	_inv_skins_tab = Control.new()
	skins_scroll.add_child(_inv_skins_tab)
	_inv_skins_scroll = skins_scroll
	_build_skins_tab_content(scroll_h)

	# Towers tab
	var towers_scroll = ScrollContainer.new()
	towers_scroll.position = Vector2(0, content_top)
	towers_scroll.size = Vector2(vp.x, scroll_h)
	towers_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	towers_scroll.visible = false
	_inv_panel.add_child(towers_scroll)
	_inv_towers_tab = Control.new()
	towers_scroll.add_child(_inv_towers_tab)
	_inv_towers_scroll = towers_scroll
	_build_towers_tab_content(scroll_h)

func _switch_inv_tab(tab: String) -> void:
	_inv_skins_scroll.visible = (tab == "skins")
	_inv_towers_scroll.visible = (tab == "towers")
	if tab == "towers":
		_refresh_tower_equip_btns()

func _build_skins_tab_content(scroll_h: float) -> void:
	# ── Layout constants ──────────────────────────────────────────────────────
	const ROW_H:    float = 115.0
	const SW_SZ:    float = 52.0
	const SW_GAP:   float = 8.0
	const LM:       float = 173.0
	const NAME_W:   float = 180.0
	const PREV_SZ:  float = 52.0
	const SP_W:     float = 90.0
	const DEF_X:    float = 1059.0
	const DEF_W:    float = 102.0

	var tower_labels = ["Laser Turret", "Plasma Cannon", "Void-Seeker", "Titan Mech", "Void Stunner", "Tesla Tower"]
	var tower_count: int = 5 + (1 if TowerSkins.has_skin("tesla_tower") else 0)
	var rows_total: float = ROW_H * float(tower_count)
	var content_h: float = maxf(rows_total + 20.0, scroll_h)
	_inv_skins_tab.custom_minimum_size = Vector2(1334, content_h)
	var row_start_y: float = 10.0

	_void_buttons.clear()
	_ducky_buttons.clear()
	for ti in tower_count:
		var row_y: float = row_start_y + ti * ROW_H
		var item_y: float = row_y + (ROW_H - SW_SZ) / 2.0   # vertically center items in row

		# Subtle row separator
		if ti > 0:
			var sep = ColorRect.new()
			sep.color = Color(0.2, 0.0, 0.35, 0.4)
			sep.size = Vector2(1334, 1)
			sep.position = Vector2(0, row_y)
			_inv_skins_tab.add_child(sep)

		# Tower name label
		var name_lbl = Label.new()
		name_lbl.text = tower_labels[ti]
		name_lbl.position = Vector2(LM, row_y + (ROW_H - 24) / 2.0)
		name_lbl.size = Vector2(NAME_W, 24)
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
		_inv_skins_tab.add_child(name_lbl)

		# Current color preview square
		var preview = ColorRect.new()
		preview.size = Vector2(PREV_SZ, PREV_SZ)
		preview.position = Vector2(LM + NAME_W + 10.0, item_y)
		preview.color = TowerSkins.get_color(ti, _DEFAULT_COLORS[ti])
		_inv_skins_tab.add_child(preview)
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
			_inv_skins_tab.add_child(border)
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
			_inv_skins_tab.add_child(swatch)

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
		_inv_skins_tab.add_child(reset_btn)

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
			_inv_skins_tab.add_child(void_btn)
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
			_inv_skins_tab.add_child(ducky_btn)
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

func _on_inventory_btn() -> void:
	_refresh_void_buttons()
	_refresh_ducky_buttons()
	_switch_inv_tab("skins")
	_inv_panel.visible = true

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
	# Cheat code — jump straight to wave 20 campaign
	if code == "cheatcode":
		GameMode.endless = false
		GameMode.start_wave = 20
		_cleanup_and_switch("res://Scenes/GameScene.tscn")
		return
	# Infinite-use coin codes — handled locally, no server needed
	if code == "savanfo":
		TowerSkins.add_coins(800)
		_codes_msg.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		_codes_msg.text = "+800 coins! (Total: %d)" % TowerSkins.coins
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

func _build_towers_tab_content(scroll_h: float) -> void:
	var tower_labels = ["Laser Turret", "Plasma Cannon", "Void-Seeker", "Titan Mech", "Void Stunner", "Tesla Tower"]
	var tower_descs = [
		"Fast single-target laser — $50",
		"AoE splash cannon — $100",
		"Long-range missile — $150",
		"Heavy AoE mech — $300",
		"Area slow pulse — $125",
		"AoE electric + burn + stun — $200",
	]
	const ROW_H: float = 90.0
	const LM: float = 300.0
	var tower_count: int = 5 + (1 if TowerSkins.has_skin("tesla_tower") else 0)
	var rows_total: float = ROW_H * float(tower_count) + 50.0
	var content_h: float = maxf(rows_total + 20.0, scroll_h)
	_inv_towers_tab.custom_minimum_size = Vector2(1334, content_h)
	var start_y: float = 10.0

	# Loadout counter
	_loadout_count_lbl = Label.new()
	_loadout_count_lbl.position = Vector2(0, start_y)
	_loadout_count_lbl.size = Vector2(1334, 28)
	_loadout_count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loadout_count_lbl.add_theme_font_size_override("font_size", 18)
	_loadout_count_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.9))
	_inv_towers_tab.add_child(_loadout_count_lbl)

	_tower_equip_btns.clear()
	for ti in tower_count:
		var row_y: float = start_y + 40.0 + ti * ROW_H

		if ti > 0:
			var sep = ColorRect.new()
			sep.color = Color(0.2, 0.0, 0.35, 0.3)
			sep.size = Vector2(734, 1)
			sep.position = Vector2(LM, row_y)
			_inv_towers_tab.add_child(sep)

		var name_lbl = Label.new()
		name_lbl.text = tower_labels[ti]
		name_lbl.position = Vector2(LM, row_y + 16)
		name_lbl.size = Vector2(240, 24)
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 1.0))
		_inv_towers_tab.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = tower_descs[ti]
		desc_lbl.position = Vector2(LM, row_y + 44)
		desc_lbl.size = Vector2(340, 20)
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.55, 0.75))
		_inv_towers_tab.add_child(desc_lbl)

		var equip_btn = Button.new()
		equip_btn.size = Vector2(120, 38)
		equip_btn.position = Vector2(LM + 420, row_y + 22)
		equip_btn.add_theme_font_size_override("font_size", 15)
		var cap_ti = ti
		equip_btn.pressed.connect(func(): _on_toggle_equip(cap_ti))
		_inv_towers_tab.add_child(equip_btn)
		_tower_equip_btns.append(equip_btn)

func _on_toggle_equip(tower_idx: int) -> void:
	if TowerSkins.is_tower_equipped(tower_idx) and not TowerSkins.loadout.is_empty():
		if TowerSkins.loadout.size() <= 1:
			return
		TowerSkins.unequip_tower(tower_idx)
	else:
		TowerSkins.equip_tower(tower_idx)
	_refresh_tower_equip_btns()

func _refresh_tower_equip_btns() -> void:
	var count: int = TowerSkins.loadout.size() if not TowerSkins.loadout.is_empty() else 4
	_loadout_count_lbl.text = "Equipped: %d / %d" % [count, TowerSkins.MAX_LOADOUT]
	for ti in _tower_equip_btns.size():
		var btn: Button = _tower_equip_btns[ti]
		var equipped: bool = TowerSkins.is_tower_equipped(ti)
		if equipped:
			btn.text = "Equipped"
			btn.disabled = false
			var flat = StyleBoxFlat.new()
			flat.bg_color = Color(0.1, 0.3, 0.15)
			flat.border_color = Color(0.2, 0.8, 0.3)
			flat.border_width_bottom = 2
			flat.border_width_top = 2
			flat.border_width_left = 2
			flat.border_width_right = 2
			btn.add_theme_stylebox_override("normal", flat)
			var hover = flat.duplicate()
			hover.bg_color = Color(0.15, 0.4, 0.2)
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		else:
			btn.text = "Equip"
			var can_equip: bool = TowerSkins.loadout.size() < TowerSkins.MAX_LOADOUT
			btn.disabled = not can_equip
			var flat = StyleBoxFlat.new()
			flat.bg_color = Color(0.15, 0.08, 0.25)
			flat.border_color = Color(0.4, 0.2, 0.6)
			flat.border_width_bottom = 2
			flat.border_width_top = 2
			flat.border_width_left = 2
			flat.border_width_right = 2
			btn.add_theme_stylebox_override("normal", flat)
			var hover = flat.duplicate()
			hover.bg_color = Color(0.2, 0.12, 0.35)
			btn.add_theme_stylebox_override("hover", hover)
			btn.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9))

var _shop_ducky_btn: Button = null
var _shop_ducky_status: Label = null
var _shop_tesla_btn: Button = null
var _shop_tesla_status: Label = null

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
	var box_h: float = 440.0
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

	# ── Tesla Tower Item ──────────────────────────────────────────────────────
	var tesla_y: float = box_y + 190

	var tesla_swatch = ColorRect.new()
	tesla_swatch.color = Color(0.3, 0.7, 1.0)
	tesla_swatch.size = Vector2(48, 48)
	tesla_swatch.position = Vector2(item_x, tesla_y)
	_shop_panel.add_child(tesla_swatch)

	var tesla_name = Label.new()
	tesla_name.text = "Tesla Tower"
	tesla_name.position = Vector2(item_x + 62, tesla_y + 2)
	tesla_name.size = Vector2(200, 24)
	tesla_name.add_theme_font_size_override("font_size", 20)
	tesla_name.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	_shop_panel.add_child(tesla_name)

	var tesla_desc = Label.new()
	tesla_desc.text = "AoE electric tower — burn & stun at higher levels"
	tesla_desc.position = Vector2(item_x + 62, tesla_y + 28)
	tesla_desc.size = Vector2(300, 20)
	tesla_desc.add_theme_font_size_override("font_size", 13)
	tesla_desc.add_theme_color_override("font_color", Color(0.5, 0.65, 0.7))
	_shop_panel.add_child(tesla_desc)

	_shop_tesla_btn = Button.new()
	_shop_tesla_btn.text = "800 coins"
	_shop_tesla_btn.size = Vector2(120, 38)
	_shop_tesla_btn.position = Vector2(box_x + box_w - 155, tesla_y + 5)
	_shop_tesla_btn.add_theme_font_size_override("font_size", 15)
	_shop_tesla_btn.pressed.connect(_on_buy_tesla)
	_shop_panel.add_child(_shop_tesla_btn)

	_shop_tesla_status = Label.new()
	_shop_tesla_status.text = ""
	_shop_tesla_status.position = Vector2(item_x, tesla_y + 60)
	_shop_tesla_status.size = Vector2(box_w - 60, 20)
	_shop_tesla_status.add_theme_font_size_override("font_size", 14)
	_shop_panel.add_child(_shop_tesla_status)

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

func _on_buy_tesla() -> void:
	if TowerSkins.has_skin("tesla_tower"):
		return
	if TowerSkins.purchase_skin("tesla_tower", 800):
		_shop_coins_lbl.text = "Coins: %d" % TowerSkins.coins
		_shop_tesla_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		_shop_tesla_status.text = "Purchased! Equip it in Inventory > Towers."
		_shop_tesla_btn.text = "Owned"
		_shop_tesla_btn.disabled = true
		_rebuild_inventory_tabs()
	else:
		_shop_tesla_status.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_shop_tesla_status.text = "Not enough coins!"

func _rebuild_inventory_tabs() -> void:
	for child in _inv_skins_tab.get_children():
		child.queue_free()
	_skin_previews.clear()
	_swatch_borders.clear()
	_void_buttons.clear()
	_ducky_buttons.clear()
	_build_skins_tab_content(_inv_skins_scroll.size.y)
	for child in _inv_towers_tab.get_children():
		child.queue_free()
	_tower_equip_btns.clear()
	_build_towers_tab_content(_inv_towers_scroll.size.y)

func _refresh_shop_items() -> void:
	if TowerSkins.has_skin("ducky_0"):
		_shop_ducky_btn.text = "Owned"
		_shop_ducky_btn.disabled = true
		_shop_ducky_status.text = ""
	else:
		_shop_ducky_btn.text = "200 coins"
		_shop_ducky_btn.disabled = false
		_shop_ducky_status.text = ""
	if TowerSkins.has_skin("tesla_tower"):
		_shop_tesla_btn.text = "Owned"
		_shop_tesla_btn.disabled = true
		_shop_tesla_status.text = ""
	else:
		_shop_tesla_btn.text = "800 coins"
		_shop_tesla_btn.disabled = false
		_shop_tesla_status.text = ""

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

func _cleanup_and_switch(scene_path: String) -> void:
	TowerSkins.save_if_dirty()
	if _ambient_player:
		_ambient_player.stop()
		_ambient_pb = null
	if _http_request:
		_http_request.cancel_request()
	get_tree().change_scene_to_file.call_deferred(scene_path)

func _on_start_campaign() -> void:
	GameMode.endless = false
	_cleanup_and_switch("res://Scenes/GameScene.tscn")

func _on_start_endless() -> void:
	GameMode.endless = true
	_cleanup_and_switch("res://Scenes/GameScene.tscn")
