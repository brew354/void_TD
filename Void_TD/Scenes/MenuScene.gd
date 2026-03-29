## MenuScene.gd — Title screen
class_name MenuScene
extends Node2D

const SAVE_PATH = "user://void_td_save.cfg"
const GameMode = preload("res://Models/GameMode.gd")

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
	_title.position = Vector2(0, 180)
	_title.size = Vector2(1334, 100)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 72)
	_title.add_theme_color_override("font_color", Color(0.8, 0.1, 1.0))
	_title.modulate.a = 0.0
	add_child(_title)

	var sub = Label.new()
	sub.text = "The last human base. The last hope for the universe."
	sub.position = Vector2(0, 286)
	sub.size = Vector2(1334, 36)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.75, 0.4, 1.0))
	sub.modulate.a = 0.0
	add_child(sub)

	# Lore blurb
	var lore = Label.new()
	lore.text = "The Void stirs on its home planet.\nIts forces march on the last human stronghold.\nDefeat it — or the universe falls."
	lore.position = Vector2(0, 320)
	lore.size = Vector2(1334, 72)
	lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lore.add_theme_font_size_override("font_size", 16)
	lore.add_theme_color_override("font_color", Color(0.55, 0.45, 0.7))
	lore.modulate.a = 0.0
	add_child(lore)

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

	# High score display
	var cfg = ConfigFile.new()
	cfg.load(SAVE_PATH)
	var hs: int = cfg.get_value("game", "high_score", 0)

	var tween = create_tween().set_parallel(true)
	tween.tween_property(_title,       "modulate:a", 1.0, 1.2)
	tween.tween_property(sub,          "modulate:a", 1.0, 0.8).set_delay(0.9)
	tween.tween_property(lore,         "modulate:a", 1.0, 0.8).set_delay(1.1)
	tween.tween_property(btn_campaign, "modulate:a", 1.0, 0.8).set_delay(1.6)
	tween.tween_property(btn_endless,  "modulate:a", 1.0, 0.8).set_delay(1.6)
	tween.tween_property(lbl_c,        "modulate:a", 1.0, 0.8).set_delay(1.8)
	tween.tween_property(lbl_e,        "modulate:a", 1.0, 0.8).set_delay(1.8)

	if hs > 0:
		var hs_lbl = Label.new()
		hs_lbl.text = "Best Score: %d" % hs
		hs_lbl.position = Vector2(0, 540)
		hs_lbl.size = Vector2(1334, 36)
		hs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hs_lbl.add_theme_font_size_override("font_size", 22)
		hs_lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0))
		hs_lbl.modulate.a = 0.0
		add_child(hs_lbl)
		tween.tween_property(hs_lbl, "modulate:a", 1.0, 0.8).set_delay(2.0)

func _process(delta: float) -> void:
	_time += delta

	# Pulse title between bright and vivid purple
	var pulse = 0.85 + 0.15 * sin(_time * 2.0)
	_title.add_theme_color_override("font_color", Color(0.8 * pulse, 0.1, 1.0 * pulse))

	# Twinkle stars independently
	for i in _stars.size():
		_stars[i].modulate.a = 0.4 + 0.6 * (0.5 + 0.5 * sin(_time * (0.8 + (i % 7) * 0.25) + i))

func _on_start_campaign() -> void:
	GameMode.endless = false
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")

func _on_start_endless() -> void:
	GameMode.endless = true
	get_tree().change_scene_to_file("res://Scenes/GameScene.tscn")
