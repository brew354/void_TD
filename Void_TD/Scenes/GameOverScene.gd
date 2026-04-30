## GameOverScene.gd — Win/loss screen with stats and high score
class_name GameOverScene
extends Node2D

const SAVE_PATH       = "user://void_td_save.cfg"
const TowerSkins      = preload("res://Models/TowerSkins.gd")
const GameMode        = preload("res://Models/GameMode.gd")

var won: bool = false
var final_score: int = 0
var kills: int = 0
var towers_built: int = 0
var upgrades_done: int = 0
var credits_spent: int = 0

func _ready() -> void:
	TowerSkins.load_from_disk()

	# Award coins for campaign games
	var coins_earned: int = 0
	if not GameMode.endless:
		coins_earned = TowerSkins.COIN_REWARD_WIN if won else TowerSkins.COIN_REWARD_LOSE
		TowerSkins.add_coins(coins_earned)

	var vp := get_viewport_rect().size
	var bg = ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.15)
	bg.size = vp
	add_child(bg)

	# ── Title ─────────────────────────────────────────────────────────────────
	var title = Label.new()
	if won:
		title.text = "THE VOID IS DEFEATED"
		title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.4))
	else:
		title.text = "THE BASE HAS FALLEN"
		title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	title.position = Vector2(0, 130)
	title.size = Vector2(1334, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	add_child(title)

	# ── Subtitle ──────────────────────────────────────────────────────────────
	var subtitle = Label.new()
	if won:
		subtitle.text = "Humanity survives. The universe endures."
		subtitle.add_theme_color_override("font_color", Color(0.5, 1.0, 0.65))
	else:
		subtitle.text = "The Void consumes all."
		subtitle.add_theme_color_override("font_color", Color(0.9, 0.45, 0.45))
	subtitle.position = Vector2(0, 218)
	subtitle.size = Vector2(1334, 36)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	add_child(subtitle)

	# ── Score ─────────────────────────────────────────────────────────────────
	var score_lbl = Label.new()
	score_lbl.text = "Score: %d" % final_score
	score_lbl.position = Vector2(0, 278)
	score_lbl.size = Vector2(1334, 50)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 36)
	score_lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(score_lbl)

	# ── High Score ────────────────────────────────────────────────────────────
	var cfg = ConfigFile.new()
	cfg.load(SAVE_PATH)  # ignore error if absent
	var old_high: int = cfg.get_value("game", "high_score", 0)
	var is_new_high: bool = final_score > old_high
	if is_new_high:
		cfg.set_value("game", "high_score", final_score)
		cfg.save(SAVE_PATH)
		var new_hs_lbl = Label.new()
		new_hs_lbl.text = "NEW HIGH SCORE!"
		new_hs_lbl.position = Vector2(0, 322)
		new_hs_lbl.size = Vector2(1334, 36)
		new_hs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		new_hs_lbl.add_theme_font_size_override("font_size", 24)
		new_hs_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.0))
		add_child(new_hs_lbl)
	else:
		var hs_lbl = Label.new()
		hs_lbl.text = "Best: %d" % old_high
		hs_lbl.position = Vector2(0, 322)
		hs_lbl.size = Vector2(1334, 36)
		hs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hs_lbl.add_theme_font_size_override("font_size", 22)
		hs_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
		add_child(hs_lbl)

	# ── Stats Grid ────────────────────────────────────────────────────────────
	var stats = [
		["Void Entities Slain", str(kills)],
		["Defenses Built",      str(towers_built)],
		["Upgrades",            str(upgrades_done)],
		["Energy Spent",        "%d ⚡" % credits_spent],
	]
	var col_w: float = 240.0
	var start_x: float = (1334.0 - col_w * stats.size()) / 2.0
	for i in stats.size():
		var x := start_x + i * col_w
		var key_lbl = Label.new()
		key_lbl.text = stats[i][0]
		key_lbl.position = Vector2(x, 375)
		key_lbl.size = Vector2(col_w, 28)
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 16)
		key_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.85))
		add_child(key_lbl)

		var val_lbl = Label.new()
		val_lbl.text = stats[i][1]
		val_lbl.position = Vector2(x, 401)
		val_lbl.size = Vector2(col_w, 34)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_font_size_override("font_size", 28)
		val_lbl.add_theme_color_override("font_color", Color.WHITE)
		add_child(val_lbl)

	# ── Coins Earned (campaign only) ──────────────────────────────────────────
	if coins_earned > 0:
		var coin_lbl = Label.new()
		coin_lbl.text = "+%d coins earned!  (Total: %d)" % [coins_earned, TowerSkins.coins]
		coin_lbl.position = Vector2(0, 448)
		coin_lbl.size = Vector2(1334, 32)
		coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coin_lbl.add_theme_font_size_override("font_size", 20)
		coin_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
		add_child(coin_lbl)

	# ── Return Button ─────────────────────────────────────────────────────────
	var btn = Button.new()
	btn.text = "Return to Menu"
	btn.size = Vector2(260, 60)
	btn.position = Vector2((1334 - 260) / 2.0, 490)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(_on_return)
	add_child(btn)

func _on_return() -> void:
	get_tree().change_scene_to_file.call_deferred("res://Scenes/MenuScene.tscn")
