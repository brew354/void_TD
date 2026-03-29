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
var _next_wave_label: Label
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

const _TOWER_TYPES: Array = [
	TowerDefinition.TowerType.LASER,
	TowerDefinition.TowerType.CANNON,
	TowerDefinition.TowerType.MISSILE,
	TowerDefinition.TowerType.MECHA_SOLDIER,
]

func _ready() -> void:
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

	# Incoming wave label — fills the gap between tower buttons and right controls
	var tower_section_end: float = _BTN_GAP + _TOWER_TYPES.size() * (_BTN_W + _BTN_GAP)
	_next_wave_label = _make_small_label("", Vector2(tower_section_end + 8, _BOT_Y + 9))
	_next_wave_label.size = Vector2(988 - tower_section_end - 12, 20)
	add_child(_next_wave_label)

	_build_upgrade_panel()

	# ── Damage flash overlay (always on top) ──────────────────────────────────
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(1.0, 0.0, 0.0, 0.0)
	_damage_flash.size = Vector2(1334, 750)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_flash)

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

func set_start_wave_enabled(enabled: bool) -> void:
	_start_wave_btn.disabled = not enabled

func set_selected_tower(type: TowerDefinition.TowerType) -> void:
	for i in _tower_btns.size():
		_tower_btns[i].modulate = Color(0.4, 1.0, 0.4) if i == int(type) else Color(1, 1, 1)

func update_next_wave(text: String) -> void:
	_next_wave_label.text = text

func _on_speed_btn_pressed() -> void:
	_fast_mode = not _fast_mode
	_speed_btn.text = "Speed: 2x" if _fast_mode else "Speed: 1x"
	speed_toggled.emit(_fast_mode)
