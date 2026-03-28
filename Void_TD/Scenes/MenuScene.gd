## MenuScene.gd — Title screen
class_name MenuScene
extends Node2D

var _title: Label
var _stars: Array = []
var _time: float = 0.0

func _ready() -> void:
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
	_title.position = Vector2(0, 200)
	_title.size = Vector2(1334, 100)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 72)
	_title.add_theme_color_override("font_color", Color(0.8, 0.1, 1.0))
	_title.modulate.a = 0.0
	add_child(_title)

	var sub = Label.new()
	sub.text = "Void Tower Defense Game"
	sub.position = Vector2(0, 310)
	sub.size = Vector2(1334, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.75, 0.4, 1.0))
	sub.modulate.a = 0.0
	add_child(sub)

	var btn = Button.new()
	btn.text = "START GAME"
	btn.size = Vector2(240, 60)
	btn.position = Vector2((1334 - 240) / 2.0, 430)
	btn.add_theme_font_size_override("font_size", 28)
	btn.modulate.a = 0.0
	btn.pressed.connect(_on_start)
	add_child(btn)

	# Staggered fade-in
	var tween = create_tween().set_parallel(true)
	tween.tween_property(_title, "modulate:a", 1.0, 1.2)
	tween.tween_property(sub,    "modulate:a", 1.0, 0.8).set_delay(0.9)
	tween.tween_property(btn,    "modulate:a", 1.0, 0.8).set_delay(1.5)

func _process(delta: float) -> void:
	_time += delta

	# Pulse title between bright and vivid purple
	var pulse = 0.85 + 0.15 * sin(_time * 2.0)
	_title.add_theme_color_override("font_color", Color(0.8 * pulse, 0.1, 1.0 * pulse))

	# Twinkle stars independently
	for i in _stars.size():
		_stars[i].modulate.a = 0.4 + 0.6 * (0.5 + 0.5 * sin(_time * (0.8 + (i % 7) * 0.25) + i))

func _on_start() -> void:
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")
