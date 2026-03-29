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
	Color(0.2,  0.6,  1.0),  # Photon Lance
	Color(0.9,  0.5,  0.1),  # Plasma Cannon
	Color(0.8,  0.2,  0.8),  # Void-Seeker
	Color(1.0,  0.15, 0.0),  # Titan Mech
]

var _title: Label
var _stars: Array = []
var _time: float = 0.0
var _skin_panel: Node2D = null
var _skin_previews: Array = []        # Array[ColorRect]  one per tower row
var _swatch_borders: Array = []       # Array[Array[ColorRect]]  [tower][palette]
var _ducky_border: ColorRect = null   # selection border for the Ducky button
var _doggo_border: ColorRect = null   # selection border for the Doggo button

func _ready() -> void:
	TowerSkins.load_from_disk()

	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.size = Vector2(1334, 750)
	bg.position = Vector2.ZERO
	add_child(bg)

	# Twinkling star field
	for i in range(160):
		var star = ColorRect.new()
		var sz = randf_range(1.0, 3.0)
		star.size = Vector2(sz, sz)
		star.position = Vector2(randf_range(0, 1334), randf_range(0, 750))
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

	# Skins button
	var btn_skins = Button.new()
	btn_skins.text = "SKINS"
	btn_skins.size = Vector2(160, 44)
	btn_skins.position = Vector2(1334 / 2.0 - 80, 528)
	btn_skins.add_theme_font_size_override("font_size", 20)
	btn_skins.modulate.a = 0.0
	btn_skins.pressed.connect(_on_skins_btn)
	add_child(btn_skins)

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

	if hs > 0:
		var hs_lbl = Label.new()
		hs_lbl.text = "Best Score: %d" % hs
		hs_lbl.position = Vector2(0, 584)
		hs_lbl.size = Vector2(1334, 36)
		hs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hs_lbl.add_theme_font_size_override("font_size", 22)
		hs_lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
		hs_lbl.modulate.a = 0.0
		add_child(hs_lbl)
		tween.tween_property(hs_lbl, "modulate:a", 1.0, 0.8).set_delay(2.2)

	_build_skin_panel()

func _build_skin_panel() -> void:
	_skin_panel = Node2D.new()
	_skin_panel.visible = false
	add_child(_skin_panel)

	# Semi-transparent overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.78)
	overlay.size = Vector2(1334, 750)
	overlay.position = Vector2.ZERO
	_skin_panel.add_child(overlay)

	# Panel background
	const PW: float = 700.0
	const PH: float = 290.0
	var px: float = (1334.0 - PW) / 2.0
	var py: float = (750.0  - PH) / 2.0

	var panel_bg = ColorRect.new()
	panel_bg.color = Color(0.06, 0.0, 0.1, 0.98)
	panel_bg.size = Vector2(PW, PH)
	panel_bg.position = Vector2(px, py)
	_skin_panel.add_child(panel_bg)

	# Header bar
	var header = ColorRect.new()
	header.color = Color(0.22, 0.0, 0.38, 1.0)
	header.size = Vector2(PW, 38)
	header.position = Vector2(px, py)
	_skin_panel.add_child(header)

	var title_lbl = Label.new()
	title_lbl.text = "Tower Skins"
	title_lbl.position = Vector2(px + 14, py + 7)
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	_skin_panel.add_child(title_lbl)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.size = Vector2(30, 30)
	close_btn.position = Vector2(px + PW - 34, py + 4)
	close_btn.pressed.connect(func(): _skin_panel.visible = false)
	_skin_panel.add_child(close_btn)

	# One row per tower type
	var tower_labels = ["Photon Lance", "Plasma Cannon", "Void-Seeker", "Titan Mech"]

	for ti in 4:
		var row_y: float = py + 48 + ti * 58

		# Tower name label
		var name_lbl = Label.new()
		name_lbl.text = tower_labels[ti]
		name_lbl.position = Vector2(px + 12, row_y + 8)
		name_lbl.size = Vector2(128, 28)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
		_skin_panel.add_child(name_lbl)

		# Current color preview square
		var preview = ColorRect.new()
		preview.size = Vector2(36, 36)
		preview.position = Vector2(px + 144, row_y + 4)
		preview.color = TowerSkins.get_color(ti, _DEFAULT_COLORS[ti])
		_skin_panel.add_child(preview)
		_skin_previews.append(preview)

		# Palette swatches
		var row_borders: Array = []
		for ci in _PALETTE.size():
			var sx: float = px + 190.0 + ci * 42.0

			# Yellow selection border (shown when this swatch is active)
			var border = ColorRect.new()
			border.color = Color(1.0, 1.0, 0.3)
			border.size = Vector2(38, 38)
			border.position = Vector2(sx - 1, row_y + 3)
			var current = TowerSkins.overrides.get(ti, Color(-1, -1, -1))
			border.visible = (current == _PALETTE[ci])
			_skin_panel.add_child(border)
			row_borders.append(border)

			# Swatch button
			var swatch = Button.new()
			swatch.size = Vector2(36, 36)
			swatch.position = Vector2(sx, row_y + 4)
			var flat = StyleBoxFlat.new()
			flat.bg_color = _PALETTE[ci]
			swatch.add_theme_stylebox_override("normal",   flat)
			swatch.add_theme_stylebox_override("hover",    flat)
			swatch.add_theme_stylebox_override("pressed",  flat)
			swatch.add_theme_stylebox_override("focus",    flat)
			var cap_ti = ti
			var cap_ci = ci
			swatch.pressed.connect(func(): _on_swatch_pressed(cap_ti, cap_ci))
			_skin_panel.add_child(swatch)

		_swatch_borders.append(row_borders)

		# Void-Seeker (ti == 2) gets a Doggo special skin button
		if ti == 2:
			var dog_x: float = px + PW - 158.0

			_doggo_border = ColorRect.new()
			_doggo_border.color = Color(1.0, 1.0, 0.3)
			_doggo_border.size = Vector2(68, 38)
			_doggo_border.position = Vector2(dog_x - 1, row_y + 3)
			_doggo_border.visible = (TowerSkins.overrides.get(2, Color(-1,-1,-1)) == TowerSkins.DOGGO_COLOR)
			_skin_panel.add_child(_doggo_border)

			var dog_btn = Button.new()
			dog_btn.text = "Doggo"
			dog_btn.size = Vector2(66, 36)
			dog_btn.position = Vector2(dog_x, row_y + 4)
			dog_btn.add_theme_font_size_override("font_size", 13)
			var dog_flat = StyleBoxFlat.new()
			dog_flat.bg_color = TowerSkins.DOGGO_COLOR
			dog_btn.add_theme_stylebox_override("normal",  dog_flat)
			dog_btn.add_theme_stylebox_override("hover",   dog_flat)
			dog_btn.add_theme_stylebox_override("pressed", dog_flat)
			dog_btn.add_theme_stylebox_override("focus",   dog_flat)
			dog_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			dog_btn.pressed.connect(_on_doggo_pressed)
			_skin_panel.add_child(dog_btn)

		# Titan Mech (ti == 3) gets an extra Ducky special skin button
		if ti == 3:
			var duck_x: float = px + PW - 158.0

			# Ducky selection border
			_ducky_border = ColorRect.new()
			_ducky_border.color = Color(1.0, 1.0, 0.3)
			_ducky_border.size = Vector2(68, 38)
			_ducky_border.position = Vector2(duck_x - 1, row_y + 3)
			_ducky_border.visible = (TowerSkins.overrides.get(3, Color(-1,-1,-1)) == TowerSkins.DUCKY_COLOR)
			_skin_panel.add_child(_ducky_border)

			var duck_btn = Button.new()
			duck_btn.text = "Ducky"
			duck_btn.size = Vector2(66, 36)
			duck_btn.position = Vector2(duck_x, row_y + 4)
			duck_btn.add_theme_font_size_override("font_size", 13)
			var duck_flat = StyleBoxFlat.new()
			duck_flat.bg_color = TowerSkins.DUCKY_COLOR
			duck_btn.add_theme_stylebox_override("normal",  duck_flat)
			duck_btn.add_theme_stylebox_override("hover",   duck_flat)
			duck_btn.add_theme_stylebox_override("pressed", duck_flat)
			duck_btn.add_theme_stylebox_override("focus",   duck_flat)
			duck_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
			duck_btn.pressed.connect(_on_ducky_pressed)
			_skin_panel.add_child(duck_btn)

		# Reset / Default button
		var reset_btn = Button.new()
		reset_btn.text = "Default"
		reset_btn.size = Vector2(72, 30)
		reset_btn.position = Vector2(px + PW - 82, row_y + 8)
		reset_btn.add_theme_font_size_override("font_size", 13)
		var cap_ti2 = ti
		reset_btn.pressed.connect(func(): _on_reset_skin(cap_ti2))
		_skin_panel.add_child(reset_btn)

func _on_swatch_pressed(tower_idx: int, color_idx: int) -> void:
	var color: Color = _PALETTE[color_idx]
	TowerSkins.set_color(tower_idx, color)
	_skin_previews[tower_idx].color = color
	for ci in _swatch_borders[tower_idx].size():
		_swatch_borders[tower_idx][ci].visible = (ci == color_idx)
	if tower_idx == 2 and _doggo_border != null:
		_doggo_border.visible = false
	if tower_idx == 3 and _ducky_border != null:
		_ducky_border.visible = false

func _on_doggo_pressed() -> void:
	TowerSkins.set_color(2, TowerSkins.DOGGO_COLOR)
	_skin_previews[2].color = TowerSkins.DOGGO_COLOR
	for border in _swatch_borders[2]:
		border.visible = false
	if _doggo_border != null:
		_doggo_border.visible = true

func _on_ducky_pressed() -> void:
	TowerSkins.set_color(3, TowerSkins.DUCKY_COLOR)
	_skin_previews[3].color = TowerSkins.DUCKY_COLOR
	for border in _swatch_borders[3]:
		border.visible = false
	if _ducky_border != null:
		_ducky_border.visible = true

func _on_reset_skin(tower_idx: int) -> void:
	TowerSkins.reset_color(tower_idx)
	_skin_previews[tower_idx].color = _DEFAULT_COLORS[tower_idx]
	for border in _swatch_borders[tower_idx]:
		border.visible = false
	if tower_idx == 2 and _doggo_border != null:
		_doggo_border.visible = false
	if tower_idx == 3 and _ducky_border != null:
		_ducky_border.visible = false

func _on_skins_btn() -> void:
	_skin_panel.visible = true

func _process(delta: float) -> void:
	_time += delta

	# Pulse title between bright and vivid purple
	var pulse = 0.85 + 0.15 * sin(_time * 2.0)
	_title.add_theme_color_override("font_color", Color(0.8 * pulse, 0.1, 1.0 * pulse))

	# Twinkle stars independently
	for i in _stars.size():
		_stars[i].modulate.a = 0.4 + 0.6 * (0.5 + 0.5 * sin(_time * (0.8 + (i % 7) * 0.25) + i))

func _on_start_campaign() -> void:
	GameMode.endless = false
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")

func _on_start_endless() -> void:
	GameMode.endless = true
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")
