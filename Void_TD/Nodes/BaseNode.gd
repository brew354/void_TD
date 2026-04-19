## BaseNode.gd — Visual base structure at end of enemy track
class_name BaseNode
extends Node2D

var upgrade_level: int = 1
var damage_reduction: int = 0   # Lives subtracted from each hit
var total_invested: int = 0
var _level_label: Label

func setup(pos: Vector2) -> void:
	position = pos
	var sprite = Sprite2D.new()
	sprite.texture = load("res://Assets/towers/kenney_sci-fi-rts/PNG/Default size/Structure/scifiStructure_01.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# kenney structures are 64x64; scale up so base reads larger than towers
	sprite.scale = Vector2(1.8, 1.8)
	add_child(sprite)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 10)
	_level_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
	_level_label.position = Vector2(16, 14)
	_level_label.visible = false
	add_child(_level_label)

func upgrade_cost(to_level: int) -> int:
	if to_level == 2: return 100
	if to_level == 3: return 200
	return 0

func upgrade() -> void:
	upgrade_level += 1
	damage_reduction = upgrade_level - 1
	total_invested += upgrade_cost(upgrade_level)
	_level_label.text = "L%d" % upgrade_level
	_level_label.visible = true
