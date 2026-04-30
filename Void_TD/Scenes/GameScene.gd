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
var _rift: Node2D = null

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
var _start_wave: int = 0
var _milestone_manager = null

# ── Music ─────────────────────────────────────────────────────────────────────
var _music_player: AudioStreamPlayer = null

# ── Boss bar tracking ─────────────────────────────────────────────────────────
var _boss_bar_enemy: Node = null  # Void Herald currently shown in the top bar

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	TowerSkins.load_from_disk()
	_endless = GameMode.endless
	_start_wave = GameMode.start_wave
	GameMode.start_wave = 0
	_load_audio()
	_start_music()
	_build_layers()
	_init_systems()
	if _start_wave > 1:
		currency = 5000
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
	var vp := get_viewport_rect().size
	var grad = _HorizGradient.new()
	background_layer.add_child(grad)
	# Twinkling, drifting star field
	var stars = _StarField.new()
	stars.field_size = vp
	background_layer.add_child(stars)
	# Void rift at enemy spawn point
	_rift = _VoidRift.new()
	_rift.position = Vector2(58, GameConfig.PATH_WAYPOINTS[0].y)
	background_layer.add_child(_rift)
	# Planet 1 — upper-left, void dark-black/purple gas giant with wide flat ring
	var p1 = _Planet.new()
	p1.position = Vector2(110, 95)
	p1.planet_radius = 70.0
	p1.planet_color     = Color(0.06, 0.02, 0.14)
	p1.atmosphere_color = Color(0.55, 0.05, 0.9, 0.28)
	p1.highlight_color  = Color(0.4, 0.0, 0.7, 0.18)
	p1.ring_color       = Color(0.65, 0.1, 1.0, 0.55)
	p1.ring_tilt        = 0.12
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
	wave_manager = WaveManager.new(self, _endless, _start_wave)
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
	hud.tower_deselected.connect(_deselect_tower)
	hud.start_wave_pressed.connect(_on_hud_start_wave)
	hud.pause_pressed.connect(_on_hud_pause)
	hud.menu_pressed.connect(_on_menu_pressed)
	hud.speed_toggled.connect(_on_speed_toggled)
	hud.upgrade_pressed.connect(_on_upgrade_pressed)
	hud.sell_pressed.connect(_on_sell_from_panel)
	hud.upgrade_panel_closed.connect(_close_upgrade_panel)
	_refresh_hud()
	const MilestoneManager = preload("res://Systems/MilestoneManager.gd")
	_milestone_manager = MilestoneManager.new(hud)
	add_child(_milestone_manager)
	_show_wave_preview()

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

func _enemy_preview_color(type: EnemyDefinition.EnemyType) -> Color:
	match type:
		EnemyDefinition.EnemyType.SCOUT:     return Color(0.7,  0.3,  1.0)
		EnemyDefinition.EnemyType.TANK:      return Color(1.0,  0.5,  0.1)
		EnemyDefinition.EnemyType.BOSS:      return Color(1.0,  0.2,  0.8)
		EnemyDefinition.EnemyType.SPEEDER:   return Color(0.0,  0.95, 1.0)
		EnemyDefinition.EnemyType.SHIELDED:  return Color(0.4,  0.7,  1.0)
		EnemyDefinition.EnemyType.MEGA_BOSS: return Color(1.0,  0.85, 0.0)
	return Color.WHITE

func _get_wave_preview_rows() -> Array:
	var groups = wave_manager.get_next_wave_groups()
	var rows: Array = []
	for g in groups:
		rows.append({
			"label": EnemyDefinition.stats(g.type)["label"],
			"count": g.count,
			"color": _enemy_preview_color(g.type),
		})
	return rows

func _show_wave_preview() -> void:
	var next_num := wave_manager.current_wave_number()
	var rows := _get_wave_preview_rows()
	if rows.is_empty():
		# Endless past scripted waves: procedural composition — no exact preview available
		hud.show_wave_preview("ENDLESS — WAVE %d" % next_num,
			[{"label": "Scouts + Tanks + Bosses…", "count": -1, "color": Color(0.7, 0.3, 1.0)}])
	else:
		hud.show_wave_preview("INCOMING — WAVE %d" % next_num, rows)

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
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Base tap (base sits outside the tile grid)
	if event.position.distance_to(GameConfig.PATH_WAYPOINTS[-1]) <= 35.0:
		if state_machine.can_upgrade_tower():
			_open_base_panel()
		return

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
			hud.update_tower_total(tower_manager.towers.size(), GameConfig.TOWER_MAX_TOTAL)
			break

func _on_tile_clicked(col: int, row: int) -> void:
	if grid_manager.get_state(col, row) == GridManager.TileState.OCCUPIED:
		if state_machine.can_upgrade_tower():
			_open_upgrade_panel(col, row)
		return
	if not state_machine.can_place_tower():
		return
	if not _selected_type_set:
		return
	var cost = TowerDefinition.stats(selected_tower_type)["cost"]
	if currency < cost:
		tile_nodes[row][col].flash_invalid()
		return
	if tower_manager.towers.size() >= GameConfig.TOWER_MAX_TOTAL:
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
	hud.update_tower_total(tower_manager.towers.size(), GameConfig.TOWER_MAX_TOTAL)

func _open_upgrade_panel(col: int, row: int) -> void:
	_panel_col = col
	_panel_row = row
	_panel_target = "tower"
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
	if not state_machine.can_place_tower():
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

func _deselect_tower() -> void:
	_selected_type_set = false
	hud.clear_selected_tower()

func _on_hud_start_wave() -> void:
	if not state_machine.can_start_wave():
		return
	if not wave_manager.has_more_waves():
		return
	_close_upgrade_panel()
	hud.hide_wave_preview()
	_start_chevron_fade()
	_lives_at_wave_start = lives
	_play_file("force_field", -10.0)
	_show_assault_incoming()
	# Rift intensity scales with wave progress
	var wave_pct := float(wave_manager.current_wave_number()) / float(max(wave_manager.total_waves(), 1))
	_rift.set_intensity(0.5 + wave_pct * 0.5)
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

func _on_menu_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MenuScene.tscn")

# ── Enemy Spawning ────────────────────────────────────────────────────────────
func _on_enemy_spawned(enemy_type: EnemyDefinition.EnemyType, wave_scale: float, speed_scale: float) -> void:
	var enemy = EnemyNode.new()
	enemy_layer.add_child(enemy)
	enemy.setup(enemy_type, wave_scale, speed_scale)
	enemy.died.connect(_on_enemy_died)
	enemy.exited.connect(_on_enemy_exited)
	if enemy.is_boss:
		enemy.stun_pulse.connect(_on_boss_stun_pulse)
	if enemy.enemy_type == EnemyDefinition.EnemyType.BOSS and _boss_bar_enemy == null:
		_rift.boss_flare()
		_boss_bar_enemy = enemy
		hud.show_boss_bar("VOID HERALD")
		enemy.hp_changed.connect(hud.update_boss_bar)
		enemy.died.connect(func(_e): _boss_bar_enemy = null; hud.hide_boss_bar())
		enemy.exited.connect(func(_e): _boss_bar_enemy = null; hud.hide_boss_bar())
	if enemy.enemy_type == EnemyDefinition.EnemyType.MEGA_BOSS:
		_rift.boss_flare()
		enemy.armor_broken.connect(_on_mega_boss_armor_broken)
		hud.show_boss_bar("THE VOID")
		enemy.hp_changed.connect(hud.update_boss_bar)
		enemy.died.connect(func(_e): hud.hide_boss_bar())
		enemy.exited.connect(func(_e): hud.hide_boss_bar())
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
		TowerDefinition.TowerType.TESLA:
			_play_file("laser_large", -4.0)
			_screen_shake(2.0, 0.12)
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
	if _milestone_manager:
		_milestone_manager.on_enemy_killed(enemy, _total_kills)
	_spawn_reward_label(enemy.position, enemy.reward)
	match enemy.enemy_type:
		EnemyDefinition.EnemyType.SCOUT:
			pass
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
	var raw: int = 4 if enemy.is_boss else enemy.lives_damage
	var damage: int = max(raw - _base.damage_reduction, 1)
	lives -= damage
	lives = max(lives, 0)
	hud.flash_damage()
	hud.update_lives(lives)
	if enemy.is_boss:
		_screen_shake(10.0, 0.5)
	if lives <= 0:
		_trigger_game_over(false)

# ── State Machine Callbacks ───────────────────────────────────────────────────
func _on_state_changed(new_state: GameStateMachine.State) -> void:
	hud.set_start_wave_enabled(state_machine.can_start_wave())

func _on_wave_complete() -> void:
	if lives <= 0:
		return
	_rift.set_intensity(0.3)
	currency += GameConfig.wave_bonus(wave_manager.current_wave_number() - 1)
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

	if _milestone_manager:
		var completed := wave_manager.current_wave_number() - 1
		_milestone_manager.on_wave_complete(
			completed,
			wave_manager.total_waves(),
			lives < _lives_at_wave_start,
			_streak,
			wave_manager.is_endless
		)

	# +1 life every 3 waves cleared
	var waves_done := wave_manager.current_wave_number() - 1
	if waves_done > 0 and waves_done % 3 == 0:
		lives += 1
		hud.update_lives(lives)
		_spawn_life_restore_label()

	_play_file("bell_heavy", -4.0)
	get_tree().create_timer(0.22).timeout.connect(func(): _play_file("bell_heavy", -5.0), CONNECT_ONE_SHOT)
	get_tree().create_timer(0.44).timeout.connect(func(): _play_file("bell_heavy", -7.0), CONNECT_ONE_SHOT)

	if not wave_manager.has_more_waves():
		_trigger_game_over(true)
		return

	state_machine.transition_to(GameStateMachine.State.WAVE_CLEAR)
	hud.update_wave(wave_manager.current_wave_number() - 1, wave_manager.total_waves())
	hud.set_start_wave_enabled(true)
	_show_wave_preview()

# ── Audio ─────────────────────────────────────────────────────────────────────
func _start_music() -> void:
	var music_path := "res://Assets/audio/music/game.mp3"
	if not ResourceLoader.exists(music_path):
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.stream = load(music_path)
	_music_player.volume_db = -12.0
	add_child(_music_player)
	_music_player.play()

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
	var wr: WeakRef = weakref(player)
	get_tree().create_timer(max_duration).timeout.connect(func():
		var p = wr.get_ref()
		if p != null:
			p.stop()
			p.queue_free()
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

func _spawn_life_restore_label() -> void:
	var lbl := Label.new()
	lbl.text = "+1 ♥"
	lbl.size = Vector2(1334, 50)
	lbl.position = Vector2(0, 370)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.modulate.a = 0.0
	hud.add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 1.0, 0.18)
	tween.tween_property(lbl, "position:y", 310.0, 0.55)
	tween.tween_interval(0.5)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.38)
	tween.tween_callback(lbl.queue_free)

func _show_assault_incoming() -> void:
	var lbl := Label.new()
	lbl.text = "—   VOID ASSAULT INCOMING   —"
	lbl.size = Vector2(1334, 60)
	lbl.position = Vector2(0, 305)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 40)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.82))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.modulate.a = 0.0
	hud.add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 1.0, 0.18)
	tween.tween_property(lbl, "position:y", 320.0, 0.18)
	tween.tween_interval(0.85)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.38)
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
		var rh: float = rw * abs(ring_tilt)
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

## Left-to-right gradient: black → dark purple (fills full viewport)
class _HorizGradient extends Node2D:
	func _draw() -> void:
		var steps := 80
		var vp := get_viewport_rect().size
		var sw := vp.x
		var sh := vp.y
		var strip_w: float = ceil(float(sw) / steps) + 1
		for i in range(steps):
			var t := float(i) / float(steps - 1)
			var c := Color(0.0, 0.0, 0.0).lerp(Color(0.15, 0.0, 0.25), t)
			draw_rect(Rect2(i * float(sw) / steps, 0, strip_w, sh), c)

## Animated star field — twinkling + slow parallax drift
class _StarField extends Node2D:
	var field_size: Vector2 = Vector2(1334, 750)
	var _t: float = 0.0

	# Three parallax layers: (count, size_range, speed, alpha_range, twinkle_speed)
	var _layers: Array = []

	func _ready() -> void:
		# Back layer: many small dim stars, slow drift
		_layers.append(_make_layer(140, 1.0, 2.2, 0.3, 0.7, 3.0, Vector2(2.0, 0.8)))
		# Mid layer: medium stars, moderate drift
		_layers.append(_make_layer(50, 2.0, 3.5, 0.5, 0.9, 2.0, Vector2(5.0, 1.5)))
		# Front layer: few bright stars, faster drift
		_layers.append(_make_layer(20, 3.0, 5.0, 0.8, 1.0, 1.5, Vector2(9.0, 3.0)))

	func _make_layer(count: int, sz_min: float, sz_max: float,
			a_min: float, a_max: float, twinkle: float,
			drift: Vector2) -> Dictionary:
		var stars: Array = []
		for i in count:
			stars.append({
				"pos": Vector2(randf_range(0, field_size.x), randf_range(0, field_size.y)),
				"sz": randf_range(sz_min, sz_max),
				"base_a": randf_range(a_min, a_max),
				"phase": randf_range(0.0, TAU),
				"rate": randf_range(0.6, 1.4),
				"warmth": randf_range(0.85, 1.0),
			})
		return {"stars": stars, "twinkle": twinkle, "drift": drift}

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for layer in _layers:
			var drift: Vector2 = layer["drift"]
			var twinkle: float = layer["twinkle"]
			for s in layer["stars"]:
				# Parallax drift — wrap around edges
				var px: float = fmod(s["pos"].x + drift.x * _t, field_size.x)
				var py: float = fmod(s["pos"].y + drift.y * _t, field_size.y)
				if px < 0.0: px += field_size.x
				if py < 0.0: py += field_size.y
				# Twinkle
				var alpha: float = s["base_a"] + sin(_t * twinkle * s["rate"] + s["phase"]) * 0.3
				alpha = clampf(alpha, 0.1, 1.0)
				var col := Color(1.0, s["warmth"], s["warmth"], alpha)
				var sz: float = s["sz"]
				draw_rect(Rect2(px, py, sz, sz), col)

## Void Rift — dramatic tear in space at enemy spawn point
class _VoidRift extends Node2D:
	var _t: float = 0.0
	var _intensity: float = 0.35        # 0.0 = invisible, 1.0 = full power
	var _target_intensity: float = 0.35
	var _flare_timer: float = 0.0       # boss flare countdown

	# Crack shape — two branching jagged lines
	var _crack_main: PackedVector2Array = PackedVector2Array()
	var _crack_branch_l: PackedVector2Array = PackedVector2Array()
	var _crack_branch_r: PackedVector2Array = PackedVector2Array()
	# Tendrils
	var _tendrils: Array = []
	# Drifting particles
	var _particles: Array = []

	func _ready() -> void:
		# Main crack — tall jagged vertical tear
		var segs := 16
		var half_h := 140.0
		for i in segs + 1:
			var y := lerpf(-half_h, half_h, float(i) / segs)
			var x := randf_range(-10.0, 10.0) if i > 0 and i < segs else 0.0
			_crack_main.append(Vector2(x, y))

		# Left branch — forks from upper third
		var branch_start_l := _crack_main[4]
		for i in 6:
			var frac := float(i) / 5.0
			var x := branch_start_l.x - 15.0 * frac + randf_range(-5.0, 5.0)
			var y := branch_start_l.y - 40.0 * frac + randf_range(-3.0, 3.0)
			_crack_branch_l.append(Vector2(x, y))

		# Right branch — forks from lower third
		var branch_start_r := _crack_main[12]
		for i in 6:
			var frac := float(i) / 5.0
			var x := branch_start_r.x + 18.0 * frac + randf_range(-5.0, 5.0)
			var y := branch_start_r.y + 35.0 * frac + randf_range(-3.0, 3.0)
			_crack_branch_r.append(Vector2(x, y))

		# 14 tendrils — long, reaching
		for i in 14:
			_tendrils.append({
				"angle": randf_range(-PI, PI),
				"length": randf_range(60.0, 160.0),
				"phase": randf_range(0.0, TAU),
				"rate": randf_range(0.2, 0.6),
				"width": randf_range(1.2, 3.0),
			})

		# 40 particles
		for i in 40:
			_particles.append({
				"angle": randf_range(-PI, PI),
				"dist": randf_range(15.0, 80.0),
				"speed": randf_range(10.0, 35.0),
				"phase": randf_range(0.0, TAU),
				"sz": randf_range(1.5, 4.5),
				"max_dist": randf_range(80.0, 200.0),
			})

	func set_intensity(value: float) -> void:
		_target_intensity = clampf(value, 0.0, 1.0)

	func boss_flare() -> void:
		_flare_timer = 2.0

	func _process(delta: float) -> void:
		_t += delta
		_intensity = lerpf(_intensity, _target_intensity, delta * 2.0)
		if _flare_timer > 0.0:
			_flare_timer -= delta
		queue_redraw()

	func _draw() -> void:
		if _intensity < 0.01:
			return

		var flare := 1.0 + (_flare_timer / 2.0) * 2.0 if _flare_timer > 0.0 else 1.0
		var i := _intensity * flare

		# ── Deep ambient glow — large, visible from anywhere ──────────────────
		var breathe := sin(_t * 0.6) * 0.3
		var glow_base := 60.0 + i * 80.0 + breathe * 15.0
		draw_circle(Vector2.ZERO, glow_base * 1.8,
			Color(0.3, 0.0, 0.5, 0.04 * i))
		draw_circle(Vector2.ZERO, glow_base * 1.4,
			Color(0.4, 0.0, 0.7, 0.07 * i))
		draw_circle(Vector2.ZERO, glow_base * 1.0,
			Color(0.5, 0.05, 0.9, 0.12 * i))
		draw_circle(Vector2.ZERO, glow_base * 0.6,
			Color(0.65, 0.1, 1.0, 0.18 * i))
		draw_circle(Vector2.ZERO, glow_base * 0.3,
			Color(0.8, 0.3, 1.0, 0.25 * i))

		# ── Pulsing rings — concentric energy waves ──────────────────────────
		for r_idx in 3:
			var ring_phase := fmod(_t * 0.4 + float(r_idx) * 0.33, 1.0)
			var ring_r := 20.0 + ring_phase * glow_base * 1.5
			var ring_a := (1.0 - ring_phase) * 0.2 * i
			if ring_a > 0.01:
				draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64,
					Color(0.6, 0.1, 1.0, ring_a), 1.5, true)

		# ── Tendrils — long wispy energy arms ─────────────────────────────────
		for td in _tendrils:
			var td_angle: float = float(td["angle"])
			var td_rate: float = float(td["rate"])
			var td_phase: float = float(td["phase"])
			var td_length: float = float(td["length"])
			var td_width: float = float(td["width"])
			var angle: float = td_angle + sin(_t * td_rate + td_phase) * 0.5
			var length: float = td_length * i * (0.6 + sin(_t * td_rate * 1.3 + td_phase) * 0.4)
			if length < 5.0:
				continue
			var segs := 8
			var prev := Vector2.ZERO
			for s in segs + 1:
				var frac := float(s) / segs
				var wobble := sin(_t * 1.8 + frac * 5.0 + td_phase) * 8.0 * frac
				var dir := Vector2(cos(angle), sin(angle))
				var perp := Vector2(-dir.y, dir.x)
				var pt := dir * length * frac + perp * wobble
				if s > 0:
					var alpha := (1.0 - frac * frac) * 0.6 * i
					# Outer glow line
					draw_line(prev, pt,
						Color(0.5, 0.0, 0.8, alpha * 0.3), td_width * 3.0, true)
					# Core line
					draw_line(prev, pt,
						Color(0.75, 0.2, 1.0, alpha), td_width, true)
				prev = pt

		# ── Crack — main tear + branches ──────────────────────────────────────
		var crack_scale := 0.7 + i * 0.5
		var pulse := 0.6 + sin(_t * 2.5) * 0.4
		_draw_crack(_crack_main, crack_scale, pulse, i, 5.0, 3.0)
		_draw_crack(_crack_branch_l, crack_scale * 0.8, pulse, i * 0.7, 3.5, 2.0)
		_draw_crack(_crack_branch_r, crack_scale * 0.8, pulse, i * 0.7, 3.5, 2.0)

		# ── Central eye — bright hot core ─────────────────────────────────────
		var core_pulse := 0.7 + sin(_t * 1.8) * 0.3
		var core_r := 8.0 + i * 6.0 + sin(_t * 2.2) * 2.0
		draw_circle(Vector2.ZERO, core_r * 2.0,
			Color(0.7, 0.15, 1.0, 0.3 * i * core_pulse))
		draw_circle(Vector2.ZERO, core_r,
			Color(0.85, 0.4, 1.0, 0.7 * i * core_pulse))
		draw_circle(Vector2.ZERO, core_r * 0.5,
			Color(1.0, 0.85, 1.0, 0.9 * i * core_pulse))

		# ── Drifting particles — void energy leaking out ──────────────────────
		for p in _particles:
			var dist: float = fmod(float(p["dist"]) + float(p["speed"]) * _t, float(p["max_dist"]))
			var angle: float = float(p["angle"]) + sin(_t * 0.3 + float(p["phase"])) * 0.3
			var pos := Vector2(cos(angle), sin(angle)) * dist
			var fade: float = (1.0 - dist / float(p["max_dist"])) * i
			if fade < 0.02:
				continue
			var p_sz: float = float(p["sz"]) * i
			# Particle glow
			draw_circle(pos, p_sz * 2.0,
				Color(0.5, 0.0, 0.8, fade * 0.2))
			draw_circle(pos, p_sz,
				Color(0.8, 0.3, 1.0, fade * 0.7))

		# ── Boss flare — massive expanding shockwave ──────────────────────────
		if _flare_timer > 0.0:
			var progress := 1.0 - _flare_timer / 2.0
			var ring_r := 30.0 + progress * 180.0
			var ring_a := (1.0 - progress) * 0.8
			draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 64,
				Color(0.9, 0.3, 1.0, ring_a), 4.0, true)
			draw_arc(Vector2.ZERO, ring_r * 0.7, 0.0, TAU, 64,
				Color(1.0, 0.7, 1.0, ring_a * 0.5), 2.5, true)
			draw_arc(Vector2.ZERO, ring_r * 0.4, 0.0, TAU, 64,
				Color(1.0, 0.9, 1.0, ring_a * 0.3), 1.5, true)
			# Flash the core white during flare
			draw_circle(Vector2.ZERO, 15.0 + (1.0 - progress) * 20.0,
				Color(1.0, 0.9, 1.0, ring_a * 0.6))

	func _draw_crack(pts: PackedVector2Array, scale: float,
			pulse: float, intensity: float, outer_w: float, inner_w: float) -> void:
		for j in pts.size() - 1:
			var p0 := pts[j] * scale
			var p1 := pts[j + 1] * scale
			# Outer void glow
			draw_line(p0, p1,
				Color(0.4, 0.0, 0.7, pulse * intensity * 0.4), outer_w * 2.5, true)
			# Bright purple edge
			draw_line(p0, p1,
				Color(0.8, 0.3, 1.0, pulse * intensity), outer_w, true)
			# White-hot center
			draw_line(p0, p1,
				Color(1.0, 0.85, 1.0, pulse * intensity * 0.8), inner_w, true)

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
