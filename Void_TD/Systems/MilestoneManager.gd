## MilestoneManager.gd — Tracks kill/wave milestones and triggers HUD popups
class_name MilestoneManager
extends Node

const EnemyDefinition = preload("res://Models/EnemyDefinition.gd")

var _hud        # HUDNode reference
var _fired: Dictionary = {}          # key -> true; prevents double-firing
var _type_kills: Dictionary = {}     # EnemyType int -> kill count

# Accent colors by category
const COLOR_KILLS   := Color(1.0,  0.25, 0.25)  # red
const COLOR_TYPE    := Color(0.9,  0.5,  0.0)   # orange
const COLOR_WAVE    := Color(0.2,  0.8,  1.0)   # cyan
const COLOR_STREAK  := Color(1.0,  0.85, 0.1)   # gold

func _init(hud) -> void:
	_hud = hud

# Called by GameScene._on_enemy_died after _total_kills is incremented
func on_enemy_killed(enemy, total_kills: int) -> void:
	# Total kill milestones
	match total_kills:
		10:  _fire("kills_10",  "10 Void Fragments Destroyed",       COLOR_KILLS)
		25:  _fire("kills_25",  "25 Enemies Eliminated",              COLOR_KILLS)
		50:  _fire("kills_50",  "50 Enemies Eliminated",              COLOR_KILLS)
		100: _fire("kills_100", "100 Enemies Defeated!",              COLOR_KILLS)
		250: _fire("kills_250", "250 Void Threats Neutralized!",      COLOR_KILLS)
		500: _fire("kills_500", "500 Enemies Obliterated!",           COLOR_KILLS)

	# Per-type milestones
	var et: int = int(enemy.enemy_type)
	_type_kills[et] = _type_kills.get(et, 0) + 1
	var tc: int = _type_kills[et]

	match enemy.enemy_type:
		EnemyDefinition.EnemyType.TANK:
			if tc == 10:  _fire("tanks_10",  "10 Void Tankers Crushed",       COLOR_TYPE)
			if tc == 25:  _fire("tanks_25",  "25 Void Tankers Destroyed!",    COLOR_TYPE)
		EnemyDefinition.EnemyType.BOSS:
			if tc == 1:   _fire("first_boss",  "Void Herald Slain!",          COLOR_TYPE)
			if tc == 5:   _fire("bosses_5",    "5 Void Heralds Eliminated!",  COLOR_TYPE)
		EnemyDefinition.EnemyType.SPEEDER:
			if tc == 20:  _fire("speeders_20", "20 Void Shades Erased",       COLOR_TYPE)
		EnemyDefinition.EnemyType.SHIELDED:
			if tc == 10:  _fire("shielded_10", "10 Void Sentinels Broken",    COLOR_TYPE)
		EnemyDefinition.EnemyType.MEGA_BOSS:
			if tc == 1:   _fire("first_mega",  "THE VOID Has Fallen!",        COLOR_TYPE)

# Called by GameScene._on_wave_complete
func on_wave_complete(completed_wave: int, total_waves: int,
		lives_lost: bool, streak: int, is_endless: bool) -> void:
	# Wave number milestones
	match completed_wave:
		5:  _fire("wave_5",  "Assault 5 Survived!",    COLOR_WAVE)
		10: _fire("wave_10", "Halfway There!",          COLOR_WAVE)
		15: _fire("wave_15", "Assault 15 Survived!",   COLOR_WAVE)
	if completed_wave == total_waves - 1 and not is_endless:
		_fire("wave_19", "Final Stand Incoming!",       COLOR_WAVE)

	# Flawless wave (no lives lost this wave)
	if not lives_lost:
		_fire("flawless_" + str(completed_wave), "Flawless Defense!", COLOR_WAVE)

	# Streak milestones
	if streak == 3: _fire("streak_3", "3-Wave Streak!",              COLOR_STREAK)
	if streak == 5: _fire("streak_5", "5-Wave Streak! Impenetrable!", COLOR_STREAK)

func _fire(key: String, text: String, color: Color) -> void:
	if _fired.has(key):
		return
	_fired[key] = true
	_hud.show_milestone_popup(text, color)
