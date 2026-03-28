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

var _lives_label: Label
var _wave_label: Label
var _score_label: Label
var _credits_label: Label
var _next_wave_label: Label
var _start_wave_btn: Button
var _pause_btn: Button
var _speed_btn: Button
var _tower_btns: Array = []
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

func _ready() -> void:
	_build_hud()

func _build_hud() -> void:
	# Top bar background
	var top_bg = ColorRect.new()
	top_bg.color = Color(0, 0, 0, 0.6)
	top_bg.size = Vector2(1334, 40)
	top_bg.position = Vector2(0, 0)
	add_child(top_bg)

	# Bottom bar background
	var bot_bg = ColorRect.new()
	bot_bg.color = Color(0, 0, 0, 0.6)
	bot_bg.size = Vector2(1334, 40)
	bot_bg.position = Vector2(0, 710)
	add_child(bot_bg)

	# Top: Lives
	_lives_label = _make_label("Lives: 20", Vector2(10, 5))
	add_child(_lives_label)

	# Top: Wave
	_wave_label = _make_label("Wave: 0/3", Vector2(200, 5))
	add_child(_wave_label)

	# Top: Score
	_score_label = _make_label("Score: 0", Vector2(400, 5))
	add_child(_score_label)

	# Top: Speed toggle
	_speed_btn = _make_button("Speed: 1x", Vector2(600, 2), Vector2(110, 30))
	_speed_btn.pressed.connect(_on_speed_btn_pressed)
	add_child(_speed_btn)

	# Top: Pause button
	_pause_btn = _make_button("Pause", Vector2(1240, 2), Vector2(84, 30))
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	add_child(_pause_btn)

	# Bottom: Credits
	_credits_label = _make_label("Credits: 150", Vector2(10, 715))
	add_child(_credits_label)

	# Bottom: Tower buttons
	var tower_defs = [
		[TowerDefinition.TowerType.LASER,         "Laser $50",    Vector2(180, 713)],
		[TowerDefinition.TowerType.CANNON,        "Cannon $100",  Vector2(330, 713)],
		[TowerDefinition.TowerType.MISSILE,       "Missile $150", Vector2(480, 713)],
		[TowerDefinition.TowerType.MECHA_SOLDIER, "Mecha $300",   Vector2(630, 713)],
	]
	for td in tower_defs:
		var btn = _make_button(td[1], td[2], Vector2(140, 28))
		var t = td[0]
		btn.pressed.connect(func():
			tower_selected.emit(t)
			set_selected_tower(t)
		)
		add_child(btn)
		_tower_btns.append(btn)

	# Bottom: Next wave preview
	_next_wave_label = _make_label("", Vector2(800, 715))
	add_child(_next_wave_label)

	# Bottom: Start Wave button
	_start_wave_btn = _make_button("START WAVE", Vector2(1170, 713), Vector2(150, 28))
	_start_wave_btn.pressed.connect(func(): start_wave_pressed.emit())
	add_child(_start_wave_btn)

	_build_upgrade_panel()

	# Full-screen damage flash overlay (rendered last = on top)
	_damage_flash = ColorRect.new()
	_damage_flash.color = Color(1.0, 0.0, 0.0, 0.0)
	_damage_flash.size = Vector2(1334, 750)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_flash)

func _build_upgrade_panel() -> void:
	# Outer panel: dark body
	_upgrade_panel = ColorRect.new()
	_upgrade_panel.color = Color(0.07, 0.0, 0.12, 0.97)
	_upgrade_panel.size = Vector2(240, 118)
	_upgrade_panel.visible = false
	add_child(_upgrade_panel)

	# Purple header bar
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

	# Stats row
	_panel_stats = Label.new()
	_panel_stats.position = Vector2(10, 38)
	_panel_stats.size = Vector2(220, 26)
	_panel_stats.add_theme_font_size_override("font_size", 14)
	_panel_stats.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	_upgrade_panel.add_child(_panel_stats)

	# Buttons row
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
	_panel_upgrade_btn.text = "Upgrade $%d" % upgrade_cost if can_upgrade else "Max Level"
	_panel_sell_btn.text = "Sell +$%d" % sell_value

	# Position centered above the tower, clamped inside the play area
	var pw: float = _upgrade_panel.size.x
	var ph: float = _upgrade_panel.size.y
	var px := clampf(screen_pos.x - pw / 2.0, 4.0, 1334.0 - pw - 4.0)
	var py := clampf(screen_pos.y - ph - 44.0, 44.0, 706.0 - ph)
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
	_panel_upgrade_btn.text = "Upgrade $%d" % up_cost if can_upgrade else "Max Level"
	var pw: float = _upgrade_panel.size.x
	var ph: float = _upgrade_panel.size.y
	var px := clampf(screen_pos.x - pw / 2.0, 4.0, 1334.0 - pw - 4.0)
	var py := clampf(screen_pos.y - ph - 44.0, 44.0, 706.0 - ph)
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
	lbl.add_theme_font_size_override("font_size", 18)
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
	_wave_label.text = "Wave: %d/%d" % [current, total]

func update_score(score: int) -> void:
	_score_label.text = "Score: %d" % score

func update_credits(credits: int) -> void:
	_last_credits = credits
	_credits_label.text = "Credits: %d" % credits
	_refresh_tower_buttons()

func update_tower_limits(counts: Dictionary) -> void:
	_tower_counts = counts
	_refresh_tower_buttons()

func _refresh_tower_buttons() -> void:
	var types = [
		TowerDefinition.TowerType.LASER,
		TowerDefinition.TowerType.CANNON,
		TowerDefinition.TowerType.MISSILE,
		TowerDefinition.TowerType.MECHA_SOLDIER,
	]
	for i in min(_tower_btns.size(), types.size()):
		var t = types[i]
		var cost: int = TowerDefinition.stats(t)["cost"]
		var max_c: int = TowerDefinition.max_count(t)
		var at_limit: bool = max_c > 0 and _tower_counts.get(int(t), 0) >= max_c
		_tower_btns[i].disabled = _last_credits < cost or at_limit

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
