## GameScene.gd — Central gameplay coordinator
class_name GameScene
extends Node2D

const GameConfig      = preload("res://Models/GameConfig.gd")
const TowerDefinition = preload("res://Models/TowerDefinition.gd")
const EnemyDefinition = preload("res://Models/EnemyDefinition.gd")
const GridManager     = preload("res://Systems/GridManager.gd")
const TowerManager    = preload("res://Systems/TowerManager.gd")
const WaveManager     = preload("res://Systems/WaveManager.gd")
const GameStateMachine = preload("res://Systems/GameStateMachine.gd")
const TileNode        = preload("res://Nodes/TileNode.gd")
const TowerNode       = preload("res://Nodes/TowerNode.gd")
const EnemyNode       = preload("res://Nodes/EnemyNode.gd")
const HUDNode         = preload("res://HUD/HUDNode.gd")
const GameOverScene   = preload("res://Scenes/GameOverScene.gd")
const BaseNode        = preload("res://Nodes/BaseNode.gd")
const WaveDefinition  = preload("res://Models/WaveDefinition.gd")

# ── Game State ──────────────────────────────────────────────────────────────
var lives: int = GameConfig.STARTING_LIVES
var currency: int = GameConfig.STARTING_CREDITS
var current_wave: int = 0
var score: int = 0

# ── Systems ──────────────────────────────────────────────────────────────────
var grid_manager: GridManager
var tower_manager: TowerManager
var wave_manager: WaveManager
var state_machine: GameStateMachine

# ── Scene Layers ─────────────────────────────────────────────────────────────
var background_layer: Node2D
var tile_layer: Node2D
var path_layer: Node2D
var tower_layer: Node2D
var enemy_layer: Node2D
var projectile_layer: Node2D
var hud: HUDNode

# ── Live Data ─────────────────────────────────────────────────────────────────
var enemies: Array = []          # Array[EnemyNode]
var tile_nodes: Array = []       # Array[Array[TileNode]]  [row][col]

# ── Tower placement ───────────────────────────────────────────────────────────
var selected_tower_type: TowerDefinition.TowerType = TowerDefinition.TowerType.LASER
var _selected_type_set: bool = false  # Track if user has picked a type
var _panel_col: int = -1
var _panel_row: int = -1
var _panel_target: String = ""  # "tower" or "base"
var _base: Node2D
var _fire_sfx_cooldowns: Dictionary = {}

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_layers()
	_init_systems()
	_build_grid()
	_spawn_base()
	_build_hud()

# ── Layer Setup ───────────────────────────────────────────────────────────────
func _build_layers() -> void:
	background_layer = Node2D.new()
	background_layer.name = "BackgroundLayer"
	add_child(background_layer)
	_draw_background()

	tile_layer = Node2D.new()
	tile_layer.name = "TileLayer"
	add_child(tile_layer)

	path_layer = Node2D.new()
	path_layer.name = "PathLayer"
	add_child(path_layer)

	tower_layer = Node2D.new()
	tower_layer.name = "TowerLayer"
	add_child(tower_layer)

	enemy_layer = Node2D.new()
	enemy_layer.name = "EnemyLayer"
	add_child(enemy_layer)

	projectile_layer = Node2D.new()
	projectile_layer.name = "ProjectileLayer"
	add_child(projectile_layer)

func _draw_background() -> void:
	var grad = _HorizGradient.new()
	background_layer.add_child(grad)
	# Regular stars
	for i in range(180):
		var star = ColorRect.new()
		var sz := randf_range(1.0, 3.0)
		star.size = Vector2(sz, sz)
		star.position = Vector2(randf_range(0, 1334), randf_range(0, 750))
		star.color = Color(1.0, randf_range(0.85, 1.0), 1.0, randf_range(0.6, 1.0))
		background_layer.add_child(star)
	# Bright accent stars
	for i in range(25):
		var star = ColorRect.new()
		var sz := randf_range(3.0, 5.0)
		star.size = Vector2(sz, sz)
		star.position = Vector2(randf_range(0, 1334), randf_range(0, 750))
		star.color = Color(1.0, 1.0, 1.0, 1.0)
		background_layer.add_child(star)

# ── Systems Init ──────────────────────────────────────────────────────────────
func _init_systems() -> void:
	grid_manager = GridManager.new()
	tower_manager = TowerManager.new()
	wave_manager = WaveManager.new(self)
	state_machine = GameStateMachine.new()

	wave_manager.enemy_spawned.connect(_on_enemy_spawned)
	wave_manager.wave_complete.connect(_on_wave_complete)
	state_machine.state_changed.connect(_on_state_changed)

# ── Grid Build ────────────────────────────────────────────────────────────────
func _build_grid() -> void:
	tile_nodes = []
	for r in range(GameConfig.GRID_ROWS):
		var row_arr = []
		for c in range(GameConfig.GRID_COLS):
			var tile = TileNode.new()
			tile.setup(c, r, grid_manager.get_state(c, r))
			tile.tile_clicked.connect(_on_tile_clicked)
			tile_layer.add_child(tile)
			row_arr.append(tile)
		tile_nodes.append(row_arr)

func _spawn_base() -> void:
	_base = BaseNode.new()
	enemy_layer.add_child(_base)
	_base.setup(GameConfig.PATH_WAYPOINTS[-1])

# ── HUD ───────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	hud = HUDNode.new()
	add_child(hud)
	hud.tower_selected.connect(_on_hud_tower_selected)
	hud.start_wave_pressed.connect(_on_hud_start_wave)
	hud.pause_pressed.connect(_on_hud_pause)
	hud.speed_toggled.connect(_on_speed_toggled)
	hud.upgrade_pressed.connect(_on_upgrade_pressed)
	hud.sell_pressed.connect(_on_sell_from_panel)
	hud.upgrade_panel_closed.connect(_close_upgrade_panel)
	_refresh_hud()

func _refresh_hud() -> void:
	hud.update_lives(lives)
	hud.update_wave(wave_manager.current_wave_number() - (1 if state_machine.current == GameStateMachine.State.WAVE_IN_PROGRESS else 0),
					wave_manager.total_waves())
	hud.update_score(score)
	hud.update_credits(currency)
	hud.set_start_wave_enabled(state_machine.can_start_wave())
	hud.update_next_wave(_wave_preview_text())

func _wave_preview_text() -> String:
	var waves = WaveDefinition.all_waves()
	var next_idx = wave_manager.current_wave_number() - 1
	if next_idx >= waves.size():
		return ""
	var parts = []
	for g in waves[next_idx].groups:
		parts.append("%d %s" % [g.count, EnemyDefinition.stats(g.type)["label"]])
	return "Next: " + ", ".join(parts)

# ── Main Update Loop ──────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if state_machine.current == GameStateMachine.State.PAUSED:
		return
	# Clean dead/exited enemies from list
	enemies = enemies.filter(func(e): return is_instance_valid(e) and not e.is_dead)
	tower_manager.update(delta, enemies)
	for k in _fire_sfx_cooldowns.keys():
		_fire_sfx_cooldowns[k] = max(_fire_sfx_cooldowns[k] - delta, 0.0)

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _select_tower_type(TowerDefinition.TowerType.LASER)
			KEY_2: _select_tower_type(TowerDefinition.TowerType.CANNON)
			KEY_3: _select_tower_type(TowerDefinition.TowerType.MISSILE)
			KEY_SPACE: _on_hud_start_wave()
		return
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	# Base double-click (base sits outside the tile grid)
	if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		if event.position.distance_to(GameConfig.PATH_WAYPOINTS[-1]) <= 35.0:
			if state_machine.can_upgrade_tower():
				_open_base_panel()
			return
	var coord = GameConfig.grid_coord(event.position)
	if coord == null:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		_sell_tower(coord.x, coord.y)
		_close_upgrade_panel()
	elif event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		if state_machine.can_upgrade_tower() \
				and grid_manager.get_state(coord.x, coord.y) == GridManager.TileState.OCCUPIED:
			_open_upgrade_panel(coord.x, coord.y)

func _sell_tower(col: int, row: int) -> void:
	if not state_machine.can_place_tower():
		return
	if grid_manager.get_state(col, row) != GridManager.TileState.OCCUPIED:
		return
	var pos = GameConfig.scene_position(col, row)
	for tower in tower_manager.towers:
		if is_instance_valid(tower) and tower.position.distance_to(pos) < 1.0:
			currency += tower.total_invested / 2
			grid_manager.remove(col, row)
			tile_nodes[row][col].set_state(GridManager.TileState.EMPTY)
			tower_manager.remove_tower(tower)
			tower.queue_free()
			hud.update_credits(currency)
			break

func _on_tile_clicked(col: int, row: int) -> void:
	if not state_machine.can_place_tower():
		return
	if grid_manager.get_state(col, row) == GridManager.TileState.OCCUPIED:
		return
	if not _selected_type_set:
		return
	var cost = TowerDefinition.stats(selected_tower_type)["cost"]
	if currency < cost:
		# Flash the tile red to indicate can't afford
		tile_nodes[row][col].flash_invalid()
		return
	if not grid_manager.can_place(col, row):
		tile_nodes[row][col].flash_invalid()
		return
	_place_tower(col, row, selected_tower_type)

func _place_tower(col: int, row: int, type: TowerDefinition.TowerType) -> void:
	var cost = TowerDefinition.stats(type)["cost"]
	currency -= cost
	grid_manager.place(col, row)
	tile_nodes[row][col].set_state(GridManager.TileState.OCCUPIED)

	var tower = TowerNode.new()
	tower.position = GameConfig.scene_position(col, row)
	tower_layer.add_child(tower)
	tower.setup(type, enemies, projectile_layer)
	tower.fired.connect(_on_tower_fired)
	tower_manager.add_tower(tower)

	hud.update_credits(currency)

func _open_upgrade_panel(col: int, row: int) -> void:
	_panel_col = col
	_panel_row = row
	var pos = GameConfig.scene_position(col, row)
	for tower in tower_manager.towers:
		if is_instance_valid(tower) and tower.position.distance_to(pos) < 1.0:
			var s = TowerDefinition.stats(tower.tower_type)
			var can_upgrade = tower.upgrade_level < 3
			var up_cost = TowerDefinition.upgrade_cost(tower.tower_type, tower.upgrade_level + 1) if can_upgrade else 0
			hud.show_upgrade_panel(
				s["label"], tower.upgrade_level,
				tower.damage, tower.range_radius,
				up_cost, can_upgrade and currency >= up_cost,
				tower.total_invested / 2,
				pos
			)
			break

func _open_base_panel() -> void:
	_panel_target = "base"
	var can_upgrade: bool = _base.upgrade_level < 3
	var up_cost: int = _base.upgrade_cost(_base.upgrade_level + 1) if can_upgrade else 0
	hud.show_base_panel(
		_base.upgrade_level, _base.damage_reduction,
		up_cost, can_upgrade and currency >= up_cost,
		GameConfig.PATH_WAYPOINTS[-1]
	)

func _close_upgrade_panel() -> void:
	_panel_col = -1
	_panel_row = -1
	_panel_target = ""
	hud.hide_upgrade_panel()

func _on_upgrade_pressed() -> void:
	if _panel_target == "base":
		_upgrade_base()
		return
	if _panel_col < 0:
		return
	var pos = GameConfig.scene_position(_panel_col, _panel_row)
	for tower in tower_manager.towers:
		if is_instance_valid(tower) and tower.position.distance_to(pos) < 1.0:
			if tower.upgrade_level >= 3:
				return
			var up_cost = TowerDefinition.upgrade_cost(tower.tower_type, tower.upgrade_level + 1)
			if currency < up_cost:
				return
			currency -= up_cost
			tower.upgrade()
			_play_chime([440.0, 554.0, 659.0], 0.09)
			hud.update_credits(currency)
			_open_upgrade_panel(_panel_col, _panel_row)
			break

func _upgrade_base() -> void:
	if _base.upgrade_level >= 3:
		return
	var up_cost: int = _base.upgrade_cost(_base.upgrade_level + 1)
	if currency < up_cost:
		return
	currency -= up_cost
	_base.upgrade()
	_play_chime([440.0, 554.0, 659.0], 0.09)
	hud.update_credits(currency)
	_open_base_panel()

func _on_sell_from_panel() -> void:
	if _panel_col < 0:
		return
	_sell_tower(_panel_col, _panel_row)
	_close_upgrade_panel()

# ── HUD Callbacks ─────────────────────────────────────────────────────────────
func _select_tower_type(type: TowerDefinition.TowerType) -> void:
	selected_tower_type = type
	_selected_type_set = true
	hud.set_selected_tower(type)

func _on_hud_tower_selected(type: TowerDefinition.TowerType) -> void:
	_select_tower_type(type)

func _on_hud_start_wave() -> void:
	if not state_machine.can_start_wave():
		return
	if not wave_manager.has_more_waves():
		return
	_close_upgrade_panel()
	_play_sfx(440.0, 0.18, -6.0)
	state_machine.transition_to(GameStateMachine.State.WAVE_IN_PROGRESS)
	wave_manager.start_wave()
	hud.update_wave(wave_manager.current_wave_number() - 1, wave_manager.total_waves())
	hud.update_next_wave(_wave_preview_text())
	hud.set_start_wave_enabled(false)

func _on_speed_toggled(fast: bool) -> void:
	Engine.time_scale = 2.0 if fast else 1.0

func _on_hud_pause() -> void:
	if state_machine.current == GameStateMachine.State.PAUSED:
		state_machine.resume_from_pause()
		get_tree().paused = false
	else:
		state_machine.transition_to(GameStateMachine.State.PAUSED)
		get_tree().paused = true

# ── Enemy Spawning ────────────────────────────────────────────────────────────
func _on_enemy_spawned(enemy_type: EnemyDefinition.EnemyType, wave_scale: float) -> void:
	var enemy = EnemyNode.new()
	enemy_layer.add_child(enemy)
	enemy.setup(enemy_type, wave_scale)
	enemy.died.connect(_on_enemy_died)
	enemy.exited.connect(_on_enemy_exited)
	if enemy.is_boss:
		enemy.stun_pulse.connect(_on_boss_stun_pulse)
	enemies.append(enemy)

func _on_tower_fired(tower_type: TowerDefinition.TowerType) -> void:
	var key := int(tower_type)
	if _fire_sfx_cooldowns.get(key, 0.0) > 0.0:
		return
	match tower_type:
		TowerDefinition.TowerType.LASER:
			_play_sweep(1600.0, 300.0, 0.07, -8.0)
		TowerDefinition.TowerType.CANNON:
			_play_noise(0.05, -5.0)
			_play_sfx(70.0, 0.15, -7.0)
		TowerDefinition.TowerType.MISSILE:
			_play_sweep(180.0, 700.0, 0.09, -9.0)
	_fire_sfx_cooldowns[key] = 0.15

func _spawn_reward_label(pos: Vector2, amount: int) -> void:
	var lbl := Label.new()
	lbl.text = "+$%d" % amount
	lbl.position = pos + Vector2(-20.0, -28.0)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.z_index = 20
	enemy_layer.add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "position", pos + Vector2(-20.0, -80.0), 0.7)
	tween.parallel().tween_property(lbl, "modulate:a", 1.0, 0.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.35)
	tween.tween_callback(lbl.queue_free)

func _on_enemy_died(enemy: EnemyNode) -> void:
	_spawn_reward_label(enemy.position, enemy.reward)
	match enemy.enemy_type:
		EnemyDefinition.EnemyType.SCOUT:
			_play_sweep(900.0, 180.0, 0.05, -8.0)
		EnemyDefinition.EnemyType.TANK:
			_play_noise(0.06, -4.0)
			_play_sfx(55.0, 0.15, -6.0)
		EnemyDefinition.EnemyType.BOSS:
			_play_noise(0.12, -3.0)
			_play_chime([300.0, 200.0, 120.0], 0.1)
	currency += enemy.reward
	score += enemy.reward
	hud.update_credits(currency)
	hud.update_score(score)
	wave_manager.on_enemy_resolved()

func _on_boss_stun_pulse(pos: Vector2, radius: float, duration: float) -> void:
	for tower in tower_manager.towers:
		if is_instance_valid(tower) and tower.position.distance_to(pos) <= radius:
			tower.apply_stun(duration)

func _on_enemy_exited(enemy: EnemyNode) -> void:
	wave_manager.on_enemy_resolved()
	if enemy.is_boss:
		_trigger_game_over(false)
		return
	lives -= max(enemy.lives_damage - _base.damage_reduction, 1)
	lives = max(lives, 0)
	hud.flash_damage()
	hud.update_lives(lives)
	if lives <= 0:
		_trigger_game_over(false)

# ── State Machine Callbacks ───────────────────────────────────────────────────
func _on_state_changed(new_state: GameStateMachine.State) -> void:
	hud.set_start_wave_enabled(state_machine.can_start_wave())

func _on_wave_complete() -> void:
	if lives <= 0:
		return
	currency += GameConfig.WAVE_COMPLETE_BONUS
	_play_chime([523.0, 659.0, 784.0, 1047.0], 0.12)
	hud.update_credits(currency)
	if not wave_manager.has_more_waves():
		_trigger_game_over(true)
		return
	state_machine.transition_to(GameStateMachine.State.WAVE_CLEAR)
	hud.update_wave(wave_manager.current_wave_number() - 1, wave_manager.total_waves())
	hud.update_next_wave(_wave_preview_text())
	hud.set_start_wave_enabled(true)

# ── Audio Helpers ─────────────────────────────────────────────────────────────
func _make_tone(freq: float, duration: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := 1.0 - (t / duration)
		var s := int(sin(TAU * freq * t) * env * 10000.0)
		s = clamp(s, -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _play_sfx(freq: float, duration: float, volume_db: float = 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = _make_tone(freq, duration)
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _play_chime(freqs: Array, note_dur: float) -> void:
	for i in freqs.size():
		var freq: float = freqs[i]
		get_tree().create_timer(float(i) * note_dur * 0.55).timeout.connect(
			func(): _play_sfx(freq, note_dur, -6.0), CONNECT_ONE_SHOT)

func _make_sweep(freq_start: float, freq_end: float, duration: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var progress := float(i) / float(max(frames - 1, 1))
		var freq := freq_start + (freq_end - freq_start) * progress
		var env := 1.0 - (t / duration)
		var s := int(sin(TAU * freq * t) * env * 10000.0)
		s = clamp(s, -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _make_noise_burst(duration: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(rate * duration)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / float(rate)
		var env := pow(1.0 - (t / duration), 2.0)
		var s := int((randf() * 2.0 - 1.0) * env * 12000.0)
		s = clamp(s, -32768, 32767)
		data[i * 2]     = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

func _play_sweep(freq_start: float, freq_end: float, duration: float, volume_db: float = 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = _make_sweep(freq_start, freq_end, duration)
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func _play_noise(duration: float, volume_db: float = 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = _make_noise_burst(duration)
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

## Left-to-right gradient: black → dark purple
class _HorizGradient extends Node2D:
	func _draw() -> void:
		var steps := 80
		var sw := GameConfig.SCENE_WIDTH
		var sh := GameConfig.SCENE_HEIGHT
		var strip_w: float = ceil(float(sw) / steps) + 1
		for i in range(steps):
			var t := float(i) / float(steps - 1)
			var c := Color(0.0, 0.0, 0.0).lerp(Color(0.15, 0.0, 0.25), t)
			draw_rect(Rect2(i * float(sw) / steps, 0, strip_w, sh), c)

# ── Game Over ─────────────────────────────────────────────────────────────────
func _trigger_game_over(victory: bool) -> void:
	Engine.time_scale = 1.0
	state_machine.transition_to(GameStateMachine.State.GAME_OVER)
	await get_tree().create_timer(1.5).timeout
	var scene = GameOverScene.new()
	scene.won = victory
	scene.final_score = score
	get_tree().root.add_child(scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = scene
