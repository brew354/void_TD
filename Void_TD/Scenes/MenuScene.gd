## MenuScene.gd — Title screen
class_name MenuScene
extends Node2D

func _ready() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.15)
	bg.size = Vector2(1334, 750)
	bg.position = Vector2.ZERO
	add_child(bg)

	# Title
	var title = Label.new()
	title.text = "SPACE TD"
	title.position = Vector2(0, 220)
	title.size = Vector2(1334, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0))
	add_child(title)

	var sub = Label.new()
	sub.text = "Sci-Fi Tower Defense"
	sub.position = Vector2(0, 320)
	sub.size = Vector2(1334, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	add_child(sub)

	# Start button
	var btn = Button.new()
	btn.text = "START GAME"
	btn.size = Vector2(240, 60)
	btn.position = Vector2((1334 - 240) / 2.0, 440)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(_on_start)
	add_child(btn)

func _on_start() -> void:
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")
