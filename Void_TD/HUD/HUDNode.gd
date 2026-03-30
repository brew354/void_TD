## HUDNode.gd — Screen-fixed HUD overlay
class_name HUDNode
extends CanvasLayer

const TowerDefinition = preload("res://Models/TowerDefinition.gd")

signal tower_selected(tower_type)
signal start_wave_pressed
signal pause_pressed
signal speed_toggled(fast: bool)
signal upgrade_pressed
signal sell_pressed
signal upgrade_panel_closed

# Top bar:    y=0,   h=36  — info labels only
# Bottom bar: y=714, h=36  — tower buttons + controls
const _TOP_H:  float = 36.0
const _BOT_Y:  float = 714.0
const _BOT_H:  float = 36.0
const _BTN_H:  float = 32.0   # button height inside bottom bar
const _BTN_W:  float = 158.0  # tower button width
const _BTN_GAP: float = 4.0

var _lives_label: Label
var _wave_label: Label
var _score_label: Label
var _credits_label: Label
var _towers_label: Label
var _next_wave_label: Label  # unused, kept for API compatibility

# Milestone popups — top-right corner, stacked up to 4
const _POPUP_W: float    = 300.0
const _POPUP_H: float    = 52.0
const _POPUP_X_SHOW: float = 1334.0 - _POPUP_W - 10.0
const _POPUP_X_HIDE: float = 1344.0
const _POPUP_Y0: float   = 46.0   # first slot top (below top bar)
const _POPUP_GAP: float  = 6.0
const _MAX_SLOTS: int    = 4
var _popup_slots: Array  = []   # Array of {panel, stripe, label, free}
var _popup_queue: Array  = []   # Array of {text, color}
var _start_wave_btn: Button
var _pause_btn: Button
var _speed_btn: Button
var _fast_mode: bool = false
var _last_credits: int = 0
var _tower_counts: Dictionary = {}
var _lives_pulse_tween: Tween = null
var _damage_flash: ColorRect
var _upgrade_panel: ColorRect
var _panel_title: Label
var _panel_stats: Label
var _panel_upgrade_btn: Button
var _panel_sell_btn: Button
var _tower_btns: Array = []

# Mega Boss HP bar — centered at top, below top bar
var _boss_bar_panel: ColorRect = null
var _boss_hp_fg: ColorRect = null
var _boss_name_lbl: Label = null
const _BB_W: float = 420.0
const _BB_H: float = 38.0
const _BB_INNER_W: float = 394.0
const _BB_X: float = (1334.0 - 420.0) / 2.0
const _BB_Y_SHOW: float = 38.0
const _BB_Y_HIDE: float = -50.0

# Wave preview panel — top-left, below top bar
var _wave_preview_panel: ColorRect = null
var _wave_preview_hdr_lbl: Label = null
var _wave_preview_row_nodes: Array = []
const _WP_W: float = 214.0
const _WP_HDR_H: float = 26.0
const _WP_ROW_H: float = 21.0
const _WP_PAD: float = 6.0
const _WP_MAX_ROWS: int = 6
const _WP_X_SHOW: float = 10.0
const _WP_X_HIDE: float = -230.0
const _WP_Y: float = 46.0

const _TOWER_TYPES: Array = [
	TowerDefinition.TowerType.LASER,
	TowerDefinition.TowerType.CANNON,
	TowerDefinition.TowerType.MISSILE,
	TowerDefinition.TowerType.MECHA_SOLDIER,
	TowerDefinition.TowerType.FREEZE,
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()

func _build_hud() -> void:
	# ── Top bar — info only ───────────────────────────────────────────────────
	var top_bg = ColorRect.new()
	top_bg.color = Color(0, 0, 0, 0.72)
	top_bg.size = Vector2(1334, _TOP_H)
	top_bg.position = Vector2.ZERO
	add_child(top_bg)

	_lives_label = _make_label("Lives: 5", Vector2(14, 7))
	add_child(_lives_label)

	_credits_label = _make_label("Energy: 300", Vector2(200, 7))
	add_child(_credits_label)

	_wave_label = _make_label("Assault: 0/20", Vector2(440, 7))
	add_child(_wave_label)

	_score_label = _make_label("Score: 0", Vector2(720, 7))
	add_child(_score_label)

	_towers_label = _make_label("Towers: 0/30", Vector2(980, 7))
	add_child(_towers_label)

	# ── Bottom bar — actions only ─────────────────────────────────────────────
	var bot_bg = ColorRect.new()
	bot_bg.color = Color(0, 0, 0, 0.72)
	bot_bg.size = Vector2(1334, _BOT_H)
	bot_bg.position = Vector2(0, _BOT_Y)
	add_child(bot_bg)

	var btn_y: float = _BOT_Y + (_BOT_H - _BTN_H) / 2.0  # vertically centered in bar

	# Tower buttons — left-aligned
	for i in _TOWER_TYPES.size():
		var t = _TOWER_TYPES[i]
		var s = TowerDefinition.stats(t)
		var bx: float = _BTN_GAP + i * (_BTN_W + _BTN_GAP)
		var btn = _make_button(s["label"], Vector2(bx, btn_y), Vector2(_BTN_W, _BTN_H))
		btn.add_theme_font_size_override("font_size", 12)
		var captured = t
		btn.pressed.connect(func():
			tower_selected.emit(captured)
			set_selected_tower(captured)
		)
		add_child(btn)
		_tower_btns.append(btn)

	# Right-side controls — laid out right-to-left so REPEL is flush with edge
	# REPEL ASSAULT button
	_start_wave_btn = _make_button("REPEL ASSAULT", Vector2(1160, btn_y), Vector2(170, _BTN_H))
	_start_wave_btn.add_theme_font_size_override("font_size", 13)
	_start_wave_btn.pressed.connect(func(): start_wave_pressed.emit())
	add_child(_start_wave_btn)

	# Pause button
	_pause_btn = _make_button("Pause", Vector2(1080, btn_y), Vector2(76, _BTN_H))
	_pause_btn.add_theme_font_size_override("font_size", 12)
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	add_child(_pause_btn)

	# Speed button
	_speed_btn = _make_button("Speed: 1x", Vector2(988, btn_y), Vector2(88, _BTN_H))
	_speed_btn.add_theme_font_size_override("font_size", 12)
	_speed_btn.pressed.connect(_on_speed_btn_pressed)
	add_child(_speed_btn)

	_build_upgrade_panel()
	_build_boss_bar()
	_build_wave_preview()

	# ── Damage flash overlay (always on top) ──────────────────────────────────
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(1.0, 0.0, 0.0, 0.0)
	_damage_flash.size = Vector2(1334, 750)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_flash)

	# ── Milestone popup slots ─────────────────────────────────────────────────
	for i in _MAX_SLOTS:
		var panel = ColorRect.new()
		panel.color = Color(0.04, 0.0, 0.12, 0.92)
		panel.size = Vector2(_POPUP_W, _POPUP_H)
		panel.position = Vector2(_POPUP_X_HIDE, _POPUP_Y0 + i * (_POPUP_H + _POPUP_GAP))
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.visible = false
		add_child(panel)

		var stripe = ColorRect.new()
		stripe.size = Vector2(4, _POPUP_H)
		stripe.position = Vector2.ZERO
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(stripe)

		var lbl = Label.new()
		lbl.position = Vector2(12, 0)
		lbl.size = Vector2(_POPUP_W - 16, _POPUP_H)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(lbl)

		_popup_slots.append({"panel": panel, "stripe": stripe, "label": lbl, "free": true})

func _build_upgrade_panel() -> void:
	_upgrade_panel = ColorRect.new()
	_upgrade_panel.color = Color(0.07, 0.0, 0.12, 0.97)
	_upgrade_panel.size = Vector2(240, 118)
	_upgrade_panel.visible = false
	add_child(_upgrade_panel)

	var header = ColorRect.new()
	header.color = Color(0.25, 0.0, 0.42, 1.0)
	header.size = Vector2(240, 30)
	_upgrade_panel.add_child(header)

	_panel_title = Label.new()
	_panel_title.position = Vector2(8, 6)
	_panel_title.size = Vector2(196, 22)
	_panel_title.add_theme_font_size_override("font_size", 15)
	_panel_title.add_theme_color_override("font_color", Color.WHITE)
	_upgrade_panel.add_child(_panel_title)

	var close_btn = _make_button("X", Vector2(206, 3), Vector2(28, 24))
	close_btn.pressed.connect(func(): upgrade_panel_closed.emit())
	_upgrade_panel.add_child(close_btn)

	_panel_stats = Label.new()
	_panel_stats.position = Vector2(10, 38)
	_panel_stats.size = Vector2(220, 26)
	_panel_stats.add_theme_font_size_override("font_size", 14)
	_panel_stats.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	_upgrade_panel.add_child(_panel_stats)

	_panel_upgrade_btn = _make_button("Upgrade", Vector2(8, 76), Vector2(110, 34))
	_panel_upgrade_btn.pressed.connect(func(): upgrade_pressed.emit())
	_upgrade_panel.add_child(_panel_upgrade_btn)

	_panel_sell_btn = _make_button("Sell", Vector2(122, 76), Vector2(110, 34))
	_panel_sell_btn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	_panel_sell_btn.pressed.connect(func(): sell_pressed.emit())
	_upgrade_panel.add_child(_panel_sell_btn)

func show_upgrade_panel(tower_label: String, level: int, dmg: float,
		rng: float, upgrade_cost: int, can_upgrade: bool,
		sell_value: int, screen_pos: Vector2) -> void:
	_panel_sell_btn.visible = true
	_panel_title.text = "%s   L%d" % [tower_label, level]
	_panel_stats.text = "DMG: %.0f      RNG: %.0f" % [dmg, rng]
	_panel_upgrade_btn.disabled = not can_upgrade
	_panel_upgrade_btn.text = "Upgrade %d⚡" % upgrade_cost if can_upgrade else "Max Level"
	_panel_sell_btn.text = "Sell +%d⚡" % sell_value
	var pw: float = _upgrade_panel.size.x
	var ph: float = _upgrade_panel.size.y
	var px := clampf(screen_pos.x - pw / 2.0, 4.0, 1330.0 - pw)
	var py := clampf(screen_pos.y - ph - 44.0, _TOP_H + 4.0, _BOT_Y - ph - 4.0)
	_upgrade_panel.position = Vector2(px, py)
	_upgrade_panel.visible = true

func show_base_panel(level: int, reduction: int, up_cost: int,
		can_upgrade: bool, screen_pos: Vector2) -> void:
	_panel_sell_btn.visible = false
	_panel_title.text = "Base   L%d" % level
	var red_text: String
	if reduction == 0:
		red_text = "None yet"
	elif reduction == 1:
		red_text = "-%d life per hit" % reduction
	else:
		red_text = "-%d lives per hit" % reduction
	_panel_stats.text = "Dmg reduction:  %s" % red_text
	_panel_upgrade_btn.disabled = not can_upgrade
	_panel_upgrade_btn.text = "Upgrade %d⚡" % up_cost if can_upgrade else "Max Level"
	var pw: float = _upgrade_panel.size.x
	var ph: float = _upgrade_panel.size.y
	var px := clampf(screen_pos.x - pw / 2.0, 4.0, 1330.0 - pw)
	var py := clampf(screen_pos.y - ph - 44.0, _TOP_H + 4.0, _BOT_Y - ph - 4.0)
	_upgrade_panel.position = Vector2(px, py)
	_upgrade_panel.visible = true

func hide_upgrade_panel() -> void:
	_panel_sell_btn.visible = true
	_upgrade_panel.visible = false

func _make_label(text: String, pos: Vector2) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 16)
	return lbl

func _make_small_label(text: String, pos: Vector2) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	lbl.add_theme_font_size_override("font_size", 13)
	return lbl

func _make_button(text: String, pos: Vector2, sz: Vector2 = Vector2(120, 28)) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = pos
	btn.size = sz
	btn.add_theme_font_size_override("font_size", 14)
	return btn

func update_lives(lives: int) -> void:
	_lives_label.text = "Lives: %d" % lives
	if lives <= 2:
		_lives_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		if _lives_pulse_tween == null or not _lives_pulse_tween.is_running():
			_lives_pulse_tween = create_tween().set_loops()
			_lives_pulse_tween.tween_property(_lives_label, "modulate:a", 0.35, 0.4)
			_lives_pulse_tween.tween_property(_lives_label, "modulate:a", 1.0, 0.4)
	else:
		_lives_label.add_theme_color_override("font_color", Color.WHITE)
		_lives_label.modulate.a = 1.0
		if _lives_pulse_tween != null:
			_lives_pulse_tween.kill()
			_lives_pulse_tween = null

func update_wave(current: int, total: int) -> void:
	if current > total:
		_wave_label.text = "Assault: %d (∞)" % current
	else:
		_wave_label.text = "Assault: %d/%d" % [current, total]

func update_score(score: int) -> void:
	_score_label.text = "Score: %d" % score

func update_credits(credits: int) -> void:
	_last_credits = credits
	_credits_label.text = "Energy: %d" % credits
	_refresh_tower_buttons()

func update_tower_limits(counts: Dictionary) -> void:
	_tower_counts = counts
	_refresh_tower_buttons()

func _refresh_tower_buttons() -> void:
	for i in min(_tower_btns.size(), _TOWER_TYPES.size()):
		var t = _TOWER_TYPES[i]
		var s: Dictionary = TowerDefinition.stats(t)
		var cost: int = s["cost"]
		var max_c: int = TowerDefinition.max_count(t)
		var cnt: int = _tower_counts.get(int(t), 0)
		var at_limit: bool = max_c > 0 and cnt >= max_c
		_tower_btns[i].disabled = _last_credits < cost or at_limit
		if max_c > 0:
			_tower_btns[i].text = "%s  %d⚡  %d/%d" % [s["label"], cost, cnt, max_c]
		else:
			_tower_btns[i].text = "%s  %d⚡" % [s["label"], cost]

func flash_damage() -> void:
	_damage_flash.color.a = 0.35
	var tween = create_tween()
	tween.tween_property(_damage_flash, "color:a", 0.0, 0.45)

func set_paused(paused: bool) -> void:
	_pause_btn.text = "Resume" if paused else "Pause"

func set_start_wave_enabled(enabled: bool) -> void:
	_start_wave_btn.disabled = not enabled

func set_selected_tower(type: TowerDefinition.TowerType) -> void:
	for i in _tower_btns.size():
		_tower_btns[i].modulate = Color(0.4, 1.0, 0.4) if i == int(type) else Color(1, 1, 1)

func show_milestone_popup(text: String, accent_color: Color) -> void:
	# Find first free slot
	var slot_idx: int = -1
	for i in _popup_slots.size():
		if _popup_slots[i]["free"]:
			slot_idx = i
			break
	if slot_idx == -1:
		_popup_queue.append({"text": text, "color": accent_color})
		return

	var slot = _popup_slots[slot_idx]
	slot["free"] = false
	slot["label"].text = text
	slot["stripe"].color = accent_color
	var panel: ColorRect = slot["panel"]
	panel.modulate.a = 1.0
	panel.position.x = _POPUP_X_HIDE
	panel.visible = true

	var tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(panel, "position:x", _POPUP_X_SHOW, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.5)
	tw.tween_property(panel, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		panel.visible = false
		panel.modulate.a = 1.0
		slot["free"] = true
		if not _popup_queue.is_empty():
			var next = _popup_queue.pop_front()
			show_milestone_popup(next["text"], next["color"])
	)

func update_tower_total(count: int, max_total: int) -> void:
	_towers_label.text = "Towers: %d/%d" % [count, max_total]
	_towers_label.add_theme_color_override("font_color",
		Color(1.0, 0.4, 0.4) if count >= max_total else Color.WHITE)

func update_next_wave(_text: String) -> void:
	pass  # incoming wave label removed

func _on_speed_btn_pressed() -> void:
	_fast_mode = not _fast_mode
	_speed_btn.text = "Speed: 2x" if _fast_mode else "Speed: 1x"
	speed_toggled.emit(_fast_mode)

func _build_boss_bar() -> void:
	_boss_bar_panel = ColorRect.new()
	_boss_bar_panel.color = Color(0.07, 0.0, 0.0, 0.96)
	_boss_bar_panel.size = Vector2(_BB_W, _BB_H)
	_boss_bar_panel.position = Vector2(_BB_X, _BB_Y_HIDE)
	_boss_bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_boss_bar_panel)

	var top_stripe := ColorRect.new()
	top_stripe.color = Color(0.75, 0.0, 0.15, 1.0)
	top_stripe.size = Vector2(_BB_W, 2.0)
	top_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_panel.add_child(top_stripe)

	_boss_name_lbl = Label.new()
	_boss_name_lbl.position = Vector2(0, 3)
	_boss_name_lbl.size = Vector2(_BB_W, 16)
	_boss_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_name_lbl.add_theme_font_size_override("font_size", 13)
	_boss_name_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	_boss_bar_panel.add_child(_boss_name_lbl)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0.2, 0.0, 0.0)
	hp_bg.size = Vector2(_BB_INNER_W, 12)
	hp_bg.position = Vector2((_BB_W - _BB_INNER_W) / 2.0, 22)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_panel.add_child(hp_bg)

	_boss_hp_fg = ColorRect.new()
	_boss_hp_fg.color = Color(0.88, 0.08, 0.14)
	_boss_hp_fg.size = Vector2(_BB_INNER_W, 12)
	_boss_hp_fg.position = hp_bg.position
	_boss_hp_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_bar_panel.add_child(_boss_hp_fg)

func show_boss_bar(boss_name: String) -> void:
	_boss_name_lbl.text = "☠   %s   ☠" % boss_name
	_boss_hp_fg.size.x = _BB_INNER_W
	_boss_hp_fg.color = Color(0.88, 0.08, 0.14)
	_boss_bar_panel.position.y = _BB_Y_HIDE
	var tw := create_tween()
	tw.tween_property(_boss_bar_panel, "position:y", _BB_Y_SHOW, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func update_boss_bar(ratio: float) -> void:
	_boss_hp_fg.size.x = _BB_INNER_W * ratio
	if ratio > 0.5:
		_boss_hp_fg.color = Color(0.88, 0.08, 0.14).lerp(Color(1.0, 0.5, 0.0), (1.0 - ratio) * 2.0)
	else:
		_boss_hp_fg.color = Color(1.0, 0.5, 0.0).lerp(Color(0.5, 0.0, 0.05), (0.5 - ratio) * 2.0)

func hide_boss_bar() -> void:
	var tw := create_tween()
	tw.tween_property(_boss_bar_panel, "position:y", _BB_Y_HIDE, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _build_wave_preview() -> void:
	_wave_preview_panel = ColorRect.new()
	_wave_preview_panel.color = Color(0.04, 0.0, 0.12, 0.92)
	_wave_preview_panel.size = Vector2(_WP_W, _WP_HDR_H + _WP_PAD)
	_wave_preview_panel.position = Vector2(_WP_X_HIDE, _WP_Y)
	_wave_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wave_preview_panel)

	var hdr_bg = ColorRect.new()
	hdr_bg.color = Color(0.25, 0.0, 0.42, 1.0)
	hdr_bg.size = Vector2(_WP_W, _WP_HDR_H)
	hdr_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_preview_panel.add_child(hdr_bg)

	var accent = ColorRect.new()
	accent.color = Color(0.6, 0.0, 1.0)
	accent.size = Vector2(4, _WP_HDR_H)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_preview_panel.add_child(accent)

	_wave_preview_hdr_lbl = Label.new()
	_wave_preview_hdr_lbl.position = Vector2(10, 4)
	_wave_preview_hdr_lbl.size = Vector2(_WP_W - 14, _WP_HDR_H - 4)
	_wave_preview_hdr_lbl.add_theme_font_size_override("font_size", 13)
	_wave_preview_hdr_lbl.add_theme_color_override("font_color", Color.WHITE)
	_wave_preview_panel.add_child(_wave_preview_hdr_lbl)

	for i in _WP_MAX_ROWS:
		var row_y = _WP_HDR_H + _WP_PAD + i * _WP_ROW_H

		var dot = ColorRect.new()
		dot.size = Vector2(8, 8)
		dot.position = Vector2(10, row_y + 6)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wave_preview_panel.add_child(dot)

		var lbl = Label.new()
		lbl.position = Vector2(24, row_y + 1)
		lbl.size = Vector2(_WP_W - 28, _WP_ROW_H - 2)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.8, 1.0))
		_wave_preview_panel.add_child(lbl)

		_wave_preview_row_nodes.append({"dot": dot, "lbl": lbl})
		dot.visible = false
		lbl.visible = false

## Show the wave preview panel.
## header: short string like "INCOMING — WAVE 3"
## rows: Array of {label: String, count: int, color: Color}
func show_wave_preview(header: String, rows: Array) -> void:
	_wave_preview_hdr_lbl.text = header
	var n := mini(rows.size(), _WP_MAX_ROWS)
	for i in _WP_MAX_ROWS:
		var vis := i < n
		_wave_preview_row_nodes[i]["dot"].visible = vis
		_wave_preview_row_nodes[i]["lbl"].visible = vis
		if vis:
			_wave_preview_row_nodes[i]["dot"].color = rows[i]["color"]
			var c: int = rows[i]["count"]
			_wave_preview_row_nodes[i]["lbl"].text = \
				rows[i]["label"] if c < 0 else "%d × %s" % [c, rows[i]["label"]]
	var panel_h := _WP_HDR_H + _WP_PAD * 2 + n * _WP_ROW_H
	_wave_preview_panel.size = Vector2(_WP_W, panel_h)
	_wave_preview_panel.position.x = _WP_X_HIDE
	var tw := create_tween()
	tw.tween_property(_wave_preview_panel, "position:x", _WP_X_SHOW, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_wave_preview() -> void:
	var tw := create_tween()
	tw.tween_property(_wave_preview_panel, "position:x", _WP_X_HIDE, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
