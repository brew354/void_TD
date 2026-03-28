## HUDNode.gd — Screen-fixed HUD overlay
class_name HUDNode
extends CanvasLayer

const TowerDefinition = preload("res://Models/TowerDefinition.gd")

signal tower_selected(tower_type)
signal start_wave_pressed
signal pause_pressed

var _lives_label: Label
var _wave_label: Label
var _score_label: Label
var _credits_label: Label
var _start_wave_btn: Button
var _pause_btn: Button

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

	# Top: Pause button
	_pause_btn = _make_button("Pause", Vector2(1240, 2), Vector2(84, 30))
	_pause_btn.pressed.connect(func(): pause_pressed.emit())
	add_child(_pause_btn)

	# Bottom: Credits
	_credits_label = _make_label("Credits: 150", Vector2(10, 715))
	add_child(_credits_label)

	# Bottom: Tower buttons
	var tower_defs = [
		[TowerDefinition.TowerType.LASER,   "Laser $50",    Vector2(180, 713)],
		[TowerDefinition.TowerType.CANNON,  "Cannon $100",  Vector2(330, 713)],
		[TowerDefinition.TowerType.MISSILE, "Missile $150", Vector2(480, 713)],
	]
	for td in tower_defs:
		var btn = _make_button(td[1], td[2], Vector2(140, 28))
		var t = td[0]
		btn.pressed.connect(func(): tower_selected.emit(t))
		add_child(btn)

	# Bottom: Start Wave button
	_start_wave_btn = _make_button("START WAVE", Vector2(1170, 713), Vector2(150, 28))
	_start_wave_btn.pressed.connect(func(): start_wave_pressed.emit())
	add_child(_start_wave_btn)

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

func update_wave(current: int, total: int) -> void:
	_wave_label.text = "Wave: %d/%d" % [current, total]

func update_score(score: int) -> void:
	_score_label.text = "Score: %d" % score

func update_credits(credits: int) -> void:
	_credits_label.text = "Credits: %d" % credits

func set_start_wave_enabled(enabled: bool) -> void:
	_start_wave_btn.disabled = not enabled
