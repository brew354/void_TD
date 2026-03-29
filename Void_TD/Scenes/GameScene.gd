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
const GameMode        = preload("res://Models/GameMode.gd")
const TowerSkins      = preload("res://Models/TowerSkins.gd")

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
var _sfx: Dictionary = {}
var _tower_counts: Dictionary = {}  # TowerType int key → placed count
var _path_tile_nodes: Array = []
var _chevron_tween: Tween = null

# ── Screen shake ──────────────────────────────────────────────────────────────
var _camera: Camera2D = null
var _shake_timer: float = 0.0
var _shake_strength: float = 0.0

# ── Wave streak ───────────────────────────────────────────────────────────────
var _streak: int = 0
var _lives_at_wave_start: int = 0

# ── Post-game stats ───────────────────────────────────────────────────────────
var _total_kills: int = 0
var _towers_built: int = 0
var _upgrades_done: int = 0
var _credits_spent: int = 0

# ── Game mode ─────────────────────────────────────────────────────────────────
var _endless: bool = false

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	TowerSkins.load_from_disk()
	_endless = GameMode.endless
	_load_audio()
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

	# Camera for screen shake
	_camera = Camera2D.new()
	_camera.position = Vector2(GameConfig.SCENE_WIDTH / 2.0, GameConfig.SCENE_HEIGHT / 2.0)
	add_child(_camera)

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
	# Planet 1 — upper-left, toxic green/teal gas giant with ring
	var p1 = _Planet.new()
	p1.position = Vector2(110, 95)
	p1.planet_radius = 62.0
	p1.planet_color   = Color(0.18, 0.72, 0.38)
	p1.atmosphere_color = Color(0.4, 1.0, 0.55, 0.18)
	p1.highlight_color  = Color(0.55, 1.0, 0.65, 0.22)
	p1.ring_color       = Color(0.3, 0.85, 0.5, 0.45)
	p1.ring_tilt        = 0.28
	background_layer.add_child(p1)
	# Planet 2 — upper-right, deep purple/violet alien world with faint ring
	var p2 = _Planet.new()
	p2.position = Vector2(1224, 80)
	p2.planet_radius = 48.0
	p2.planet_color   = Color(0.38, 0.12, 0.72)
	p2.atmosphere_color = Color(0.65, 0.3, 1.0, 0.20)
	p2.highlight_color  = Color(0.75, 0.5, 1.0, 0.25)
	p2.ring_color       = Color(0.55, 0.2, 0.9, 0.40)
	p2.ring_tilt        = -0.22
	background_layer.add_child(p2)

# ── Systems Init ──────────────────────────────────────────────────────────────
func _init_systems() -> void:
	grid_manager = GridManager.new()
	tower_manager = TowerManager.new()
	wave_manager = WaveManager.new(self, _endless)
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
	_assign_path_directions()

func _assign_path_directions() -> void:
	_path_tile_nodes = []
	var waypoints := GameConfig.PATH_WAYPOINTS
	var total_len := 0.0
	for i in range(waypoints.size() - 1):
		total_len += waypoints[i].distance_to(waypoints[i + 1])
	var cum := 0.0
	for i in range(waypoints.size() - 1):
		var seg_start: Vector2 = waypoints[i]
		var seg_end: Vector2   = waypoints[i + 1]
		var seg_len := seg_start.distance_to(seg_end)
		var dir := (seg_end - seg_start).normalized()
		var step_size := GameConfig.TILE_SIZE * 0.5
		var num_steps := int(seg_len / step_size) + 2
		for s in range(num_steps + 1):
			var t := float(s) / float(num_steps)
			var coord: Variant = GameConfig.grid_coord(seg_start.lerp(seg_end, t))
			if coord == null:
				continue
			var tile = tile_nodes[coord.y][coord.x]
			var phase := (cum + seg_len * t) / total_len
			tile.set_path_direction(dir, phase)
			if not tile in _path_tile_nodes:
				_path_tile_nodes.append(tile)
		cum += seg_len

func _set_all_chevron_alpha(a: float) -> void:
	for tile in _path_tile_nodes:
		tile.set_chevron_alpha(a)

func _start_chevron_fade() -> void:
	if _chevron_tween != null:
		_chevron_tween.kill()
	_set_all_chevron_alpha(1.0)
	_chevron_tween = create_tween()
	_chevron_tween.tween_method(_set_all_chevron_alpha, 1.0, 0.0, 9.0)

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
	var groups = wave_manager.get_next_wave_groups()
	if groups.is_empty():
		return "Incoming: Endless Void Assault" if wave_manager.is_endless else ""
	var parts = []
	for g in groups:
		parts.append("%d %s" % [g.count, EnemyDefinition.stats(g.type)["label"]])
	return "Incoming: " + ", ".join(parts)

# ── Main Update Loop ──────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if state_machine.current == GameStateMachine.State.PAUSED:
		return
	# Clean dead/exited enemies from list
	enemies = enemies.filter(func(e): return is_instance_valid(e) and not e.is_dead)
	tower_manager.update(delta, enemies)
	for k in _fire_sfx_cooldowns.keys():
		_fire_sfx_cooldowns[k] = max(_fire_sfx_cooldowns[k] - delta, 0.0)
	# Screen shake decay
	if _shake_timer > 0.0:
		_shake_timer -= delta
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
		if _shake_timer <= 0.0:
			_shake_strength = 0.0
			_camera.offset = Vector2.ZERO

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _select_tower_type(TowerDefinition.TowerType.LASER)
			KEY_2: _select_tower_type(TowerDefinition.TowerType.CANNON)
			KEY_3: _select_tower_type(TowerDefinition.TowerType.MISSILE)
			KEY_4: _select_tower_type(TowerDefinition.TowerType.MECHA_SOLDIER)
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
			var tkey := int(tower.tower_type)
			currency += tower.total_invested / 2
			grid_manager.remove(col, row)
			tile_nodes[row][col].set_state(GridManager.TileState.EMPTY)
			tower_manager.remove_tower(tower)
			tower.queue_free()
			_tower_counts[tkey] = max(_tower_counts.get(tkey, 0) - 1, 0)
			hud.update_credits(currency)
			hud.update_tower_limits(_tower_counts)
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
		tile_nodes[row][col].flash_invalid()
		return
	var max_c: int = TowerDefinition.max_count(selected_tower_type)
	if max_c > 0 and _tower_counts.get(int(selected_tower_type), 0) >= max_c:
		tile_nodes[row][col].flash_invalid()
		return
	if not grid_manager.can_place(col, row):
		tile_nodes[row][col].flash_invalid()
		return
	_place_tower(col, row, selected_tower_type)

func _place_tower(col: int, row: int, type: TowerDefinition.TowerType) -> void:
	var cost = TowerDefinition.stats(type)["cost"]
	currency -= cost
	_credits_spent += cost
	_towers_built += 1
	grid_manager.place(col, row)
	tile_nodes[row][col].set_state(GridManager.TileState.OCCUPIED)

	var tower = TowerNode.new()
	tower.position = GameConfig.scene_position(col, row)
	tower_layer.add_child(tower)
	tower.setup(type, enemies, projectile_layer)
	tower.fired.connect(_on_tower_fired)
	tower_manager.add_tower(tower)
	_tower_counts[int(type)] = _tower_counts.get(int(type), 0) + 1
	hud.update_credits(currency)
	hud.update_tower_limits(_tower_counts)

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
			_credits_spent += up_cost
			_upgrades_done += 1
			tower.upgrade()
			_play_file("bell_heavy", -6.0)
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
	_credits_spent += up_cost
	_upgrades_done += 1
	_base.upgrade()
	_play_file("bell_heavy", -6.0)
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
	_start_chevron_fade()
	_lives_at_wave_start = lives
	_play_file("force_field", -10.0)
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
		hud.set_paused(false)
	else:
		state_machine.transition_to(GameStateMachine.State.PAUSED)
		get_tree().paused = true
		hud.set_paused(true)

# ── Enemy Spawning ────────────────────────────────────────────────────────────
func _on_enemy_spawned(enemy_type: EnemyDefinition.EnemyType, wave_scale: float) -> void:
	var enemy = EnemyNode.new()
	enemy_layer.add_child(enemy)
	enemy.setup(enemy_type, wave_scale)
	enemy.died.connect(_on_enemy_died)
	enemy.exited.connect(_on_enemy_exited)
	if enemy.is_boss:
		enemy.stun_pulse.connect(_on_boss_stun_pulse)
	if enemy.enemy_type == EnemyDefinition.EnemyType.MEGA_BOSS:
		enemy.armor_broken.connect(_on_mega_boss_armor_broken)
	enemies.append(enemy)

func _on_tower_fired(tower_type: TowerDefinition.TowerType) -> void:
	var key := int(tower_type)
	if _fire_sfx_cooldowns.get(key, 0.0) > 0.0:
		return
	match tower_type:
		TowerDefinition.TowerType.LASER:
			_play_file("laser_small", -8.0)
		TowerDefinition.TowerType.CANNON:
			_play_file("explosion_crunch", 4.0)
			_screen_shake(3.0, 0.18)
		TowerDefinition.TowerType.MISSILE:
			_play_file("thruster", -4.0)
		TowerDefinition.TowerType.MECHA_SOLDIER:
			_play_file("explosion", 6.0)
			_play_file("explosion_crunch", 2.0)
			_screen_shake(5.0, 0.25)
	_fire_sfx_cooldowns[key] = 0.15

func _spawn_reward_label(pos: Vector2, amount: int) -> void:
	var lbl := Label.new()
	lbl.text = "+%d ⚡" % amount
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
	_total_kills += 1
	_spawn_reward_label(enemy.position, enemy.reward)
	match enemy.enemy_type:
		EnemyDefinition.EnemyType.SCOUT:
			_play_file("metal_light", -6.0)
		EnemyDefinition.EnemyType.TANK:
			_play_file("explosion_crunch", -4.0)
		EnemyDefinition.EnemyType.BOSS:
			_play_file("explosion_low", -2.0)
			_screen_shake(8.0, 0.45)
		EnemyDefinition.EnemyType.SPEEDER:
			_play_file("generic_light", -5.0)
		EnemyDefinition.EnemyType.SHIELDED:
			_play_file("force_field", -4.0)
		EnemyDefinition.EnemyType.MEGA_BOSS:
			_play_file("explosion_low", 0.0)
			_play_file("explosion", -2.0)
			_screen_shake(12.0, 0.7)
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
	hud.update_credits(currency)

	# Streak bonus: +$25 per consecutive clean wave
	if lives >= _lives_at_wave_start:
		_streak += 1
		if _streak > 1:
			var streak_bonus: int = _streak * 25
			currency += streak_bonus
			score += streak_bonus
			hud.update_credits(currency)
			hud.update_score(score)
			_spawn_streak_label(streak_bonus)
	else:
		_streak = 0

	_play_file("bell_heavy", -4.0)
	get_tree().create_timer(0.22).timeout.connect(func(): _play_file("bell_heavy", -5.0), CONNECT_ONE_SHOT)
	get_tree().create_timer(0.44).timeout.connect(func(): _play_file("bell_heavy", -7.0), CONNECT_ONE_SHOT)

	if not wave_manager.has_more_waves():
		_trigger_game_over(true)
		return

	state_machine.transition_to(GameStateMachine.State.WAVE_CLEAR)
	hud.update_wave(wave_manager.current_wave_number() - 1, wave_manager.total_waves())
	hud.update_next_wave(_wave_preview_text())
	hud.set_start_wave_enabled(true)

# ── Audio ─────────────────────────────────────────────────────────────────────
func _load_audio() -> void:
	var sf := "res://Assets/audio/kenney_sci-fi-sounds/Audio/"
	var im := "res://Assets/audio/kenney_impact-sounds/Audio/"
	_sfx["laser_small"]    = _load_sfx_arr(sf + "laserRetro_%03d.ogg",            1)
	_sfx["laser_large"]    = _load_sfx_arr(sf + "laserLarge_%03d.ogg",           5)
	_sfx["explosion"]      = _load_sfx_arr(sf + "lowFrequency_explosion_%03d.ogg", 2)
	_sfx["explosion_crunch"] = _load_sfx_arr(sf + "explosionCrunch_%03d.ogg",    5)
	_sfx["explosion_low"]  = _load_sfx_arr(sf + "lowFrequency_explosion_%03d.ogg", 2)
	_sfx["force_field"]    = _load_sfx_arr(sf + "forceField_%03d.ogg",           5)
	_sfx["thruster"]       = _load_sfx_arr(sf + "thrusterFire_%03d.ogg",         5)
	_sfx["engine_small"]   = _load_sfx_arr(sf + "spaceEngineSmall_%03d.ogg",     5)
	_sfx["metal_heavy"]    = _load_sfx_arr(im + "impactMetal_heavy_%03d.ogg",    5)
	_sfx["metal_light"]    = _load_sfx_arr(im + "impactMetal_light_%03d.ogg",    5)
	_sfx["generic_light"]  = _load_sfx_arr(im + "impactGeneric_light_%03d.ogg",  5)
	_sfx["bell_heavy"]     = _load_sfx_arr(im + "impactBell_heavy_%03d.ogg",     5)

func _load_sfx_arr(pattern: String, count: int) -> Array:
	var arr := []
	for i in count:
		var res = load(pattern % i)
		if res != null:
			arr.append(res)
	return arr

func _play_file(key: String, volume_db: float = 0.0, max_duration: float = 1.0) -> void:
	var arr: Array = _sfx.get(key, [])
	if arr.is_empty():
		return
	var player := AudioStreamPlayer.new()
	player.stream = arr[0]
	player.volume_db = volume_db
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	get_tree().create_timer(max_duration).timeout.connect(func():
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	, CONNECT_ONE_SHOT)

func _screen_shake(strength: float, duration: float = 0.25) -> void:
	_shake_strength = max(_shake_strength, strength)
	_shake_timer = max(_shake_timer, duration)

func _spawn_streak_label(bonus: int) -> void:
	var lbl := Label.new()
	lbl.text = "VOID SUPPRESSED! STREAK x%d  +%d" % [_streak, bonus]
	lbl.position = Vector2(547, 340)
	lbl.size = Vector2(240, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.z_index = 25
	hud.add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "position:y", 270.0, 0.8)
	tween.parallel().tween_property(lbl, "modulate:a", 1.0, 0.0)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)

func _on_mega_boss_armor_broken() -> void:
	_screen_shake(10.0, 0.6)
	_play_file("metal_heavy", -3.0)
	var lbl := Label.new()
	lbl.text = "THE VOID'S ARMOR SHATTERS!"
	lbl.position = Vector2(507, 310)
	lbl.size = Vector2(320, 60)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.z_index = 25
	hud.add_child(lbl)
	var tween := create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tween.tween_callback(lbl.queue_free)

## Alien planet with atmosphere glow and orbital ring
class _Planet extends Node2D:
	var planet_radius: float = 50.0
	var planet_color:    Color = Color(0.2, 0.7, 0.4)
	var atmosphere_color: Color = Color(0.4, 1.0, 0.5, 0.2)
	var highlight_color:  Color = Color(0.6, 1.0, 0.6, 0.25)
	var ring_color:       Color = Color(0.3, 0.8, 0.5, 0.4)
	var ring_tilt: float = 0.25  # vertical squish of ring ellipse

	func _draw() -> void:
		# Outer atmosphere glow
		draw_circle(Vector2.ZERO, planet_radius + 10.0, Color(atmosphere_color.r, atmosphere_color.g, atmosphere_color.b, 0.08))
		draw_circle(Vector2.ZERO, planet_radius + 5.0,  atmosphere_color)
		# Planet body
		draw_circle(Vector2.ZERO, planet_radius, planet_color)
		# Surface band (darker stripe across middle)
		var band_col := planet_color.darkened(0.28)
		band_col.a = 0.55
		for dy in range(-6, 7):
			var half_w := sqrt(max(0.0, planet_radius * planet_radius - float(dy) * float(dy)))
			draw_line(Vector2(-half_w, dy), Vector2(half_w, dy), band_col, 1.0)
		# Orbital ring (thin ellipse drawn as arcs)
		var rw := planet_radius * 1.75
		var rh := rw * abs(ring_tilt)
		var segs := 48
		for i in segs:
			var a0 := float(i) / segs * TAU
			var a1 := float(i + 1) / segs * TAU
			var p0 := Vector2(cos(a0) * rw, sin(a0) * rh)
			var p1 := Vector2(cos(a1) * rw, sin(a1) * rh)
			draw_line(p0, p1, ring_color, 2.0)
		# Highlight (top-left sheen)
		draw_circle(Vector2(-planet_radius * 0.3, -planet_radius * 0.3),
					planet_radius * 0.45, highlight_color)

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
	scene.kills = _total_kills
	scene.towers_built = _towers_built
	scene.upgrades_done = _upgrades_done
	scene.credits_spent = _credits_spent
	get_tree().root.add_child(scene)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = scene
