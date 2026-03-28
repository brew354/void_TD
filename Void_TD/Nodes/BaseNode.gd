## BaseNode.gd — Visual base structure at end of enemy track
extends Node2D

func setup(pos: Vector2) -> void:
	position = pos
	var rect = ColorRect.new()
	rect.color = Color(0.0, 0.6, 0.8)
	rect.size = Vector2(60, 60)
	rect.position = Vector2(-30, -30)
	add_child(rect)
	var label = Label.new()
	label.text = "BASE"
	label.add_theme_color_override("font_color", Color.WHITE)
	label.position = Vector2(-18, -8)
	add_child(label)
