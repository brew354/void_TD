## GameOverScene.gd — Win/loss screen
class_name GameOverScene
extends Node2D

var won: bool = false
var final_score: int = 0

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.15)
	bg.size = Vector2(1334, 750)
	add_child(bg)

	var title = Label.new()
	if won:
		title.text = "VICTORY!"
		title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.4))
	else:
		title.text = "GAME OVER"
		title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	title.position = Vector2(0, 220)
	title.size = Vector2(1334, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	add_child(title)

	var score_lbl = Label.new()
	score_lbl.text = "Score: %d" % final_score
	score_lbl.position = Vector2(0, 340)
	score_lbl.size = Vector2(1334, 50)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 36)
	score_lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(score_lbl)

	var btn = Button.new()
	btn.text = "Return to Menu"
	btn.size = Vector2(260, 60)
	btn.position = Vector2((1334 - 260) / 2.0, 440)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(_on_return)
	add_child(btn)

func _on_return() -> void:
	get_tree().change_scene_to_file("res://Scenes/MenuScene.tscn")
