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
]

var _title: Label
var _stars: Array = []
var _time: float = 0.0
var _skin_panel: Node2D = null

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
var _doggo_border: ColorRect = null     # selection border for the Doggo button

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
	_start_ambient_music()

func _build_skin_panel() -> void:
	_skin_panel = Node2D.new()
	_skin_panel.visible = false
	add_child(_skin_panel)

	# ── Full-screen background ────────────────────────────────────────────────
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.0, 0.08)
	bg.size = Vector2(1334, 750)
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
	var rows_total: float = ROW_H * 4.0
	var row_start_y: float = HEADER_H + (750.0 - HEADER_H - rows_total) / 2.0

	var tower_labels = ["Laser Turret", "Plasma Cannon", "Void-Seeker", "Titan Mech"]

	for ti in 4:
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

		if ti == 2:  # Void-Seeker — Doggo
			_doggo_border = ColorRect.new()
			_doggo_border.color = Color(1.0, 1.0, 0.3)
			_doggo_border.size = Vector2(SP_W + 4, SW_SZ + 4)
			_doggo_border.position = Vector2(sp_x - 2, item_y - 2)
			_doggo_border.visible = (TowerSkins.overrides.get(2, Color(-1,-1,-1)) == TowerSkins.DOGGO_COLOR)
			_skin_panel.add_child(_doggo_border)

			var dog_btn = Button.new()
			dog_btn.text = "Doggo"
			dog_btn.size = Vector2(SP_W, SW_SZ)
			dog_btn.position = Vector2(sp_x, item_y)
			dog_btn.add_theme_font_size_override("font_size", 14)
			var dog_flat = StyleBoxFlat.new()
			dog_flat.bg_color = TowerSkins.DOGGO_COLOR
			dog_btn.add_theme_stylebox_override("normal",  dog_flat)
			dog_btn.add_theme_stylebox_override("hover",   dog_flat)
			dog_btn.add_theme_stylebox_override("pressed", dog_flat)
			dog_btn.add_theme_stylebox_override("focus",   dog_flat)
			dog_btn.add_theme_color_override("font_color", Color.WHITE)
			dog_btn.pressed.connect(_on_doggo_pressed)
			_skin_panel.add_child(dog_btn)

		# Default button — fixed x so it lines up across all rows
		var reset_btn = Button.new()
		reset_btn.text = "Default"
		reset_btn.size = Vector2(DEF_W, 38)
		reset_btn.position = Vector2(DEF_X, row_y + (ROW_H - 38) / 2.0)
		reset_btn.add_theme_font_size_override("font_size", 14)
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
func _on_doggo_pressed() -> void:
	TowerSkins.set_color(2, TowerSkins.DOGGO_COLOR)
	_skin_previews[2].color = TowerSkins.DOGGO_COLOR
	for border in _swatch_borders[2]:
		border.visible = false
	if _doggo_border != null:
		_doggo_border.visible = true

func _on_reset_skin(tower_idx: int) -> void:
	TowerSkins.reset_color(tower_idx)
	_skin_previews[tower_idx].color = _DEFAULT_COLORS[tower_idx]
	for border in _swatch_borders[tower_idx]:
		border.visible = false
	if tower_idx == 2 and _doggo_border != null:
		_doggo_border.visible = false

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
