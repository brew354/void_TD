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
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.12)
	bg.size = Vector2(GameConfig.SCENE_WIDTH, GameConfig.SCENE_HEIGHT)
	background_layer.add_child(bg)
	# Simple star dots
	for i in range(120):
		var star = ColorRect.new()
		star.color = Color(1, 1, 1, randf_range(0.2, 0.8))
		var sz = randf_range(1, 3)
		star.size = Vector2(sz, sz)
		star.position = Vector2(randf_range(0, 1334), randf_range(0, 750))
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
	var base = BaseNode.new()
	enemy_layer.add_child(base)
	base.setup(GameConfig.PATH_WAYPOINTS[-1])

# ── HUD ───────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	hud = HUDNode.new()
	add_child(hud)
	hud.tower_selected.connect(_on_hud_tower_selected)
	hud.start_wave_pressed.connect(_on_hud_start_wave)
	hud.pause_pressed.connect(_on_hud_pause)
	hud.speed_toggled.connect(_on_speed_toggled)
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

# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var coord = GameConfig.grid_coord(event.position)
		if coord != null:
			_sell_tower(coord.x, coord.y)

func _sell_tower(col: int, row: int) -> void:
	if not state_machine.can_place_tower():
		return
	if grid_manager.get_state(col, row) != GridManager.TileState.OCCUPIED:
		return
	var pos = GameConfig.scene_position(col, row)
	for tower in tower_manager.towers:
		if is_instance_valid(tower) and tower.position.distance_to(pos) < 1.0:
			currency += TowerDefinition.stats(tower.tower_type)["cost"] / 2
			grid_manager.remove(col, row)
			tile_nodes[row][col].set_state(GridManager.TileState.EMPTY)
			tower_manager.remove_tower(tower)
			tower.queue_free()
			hud.update_credits(currency)
			break

func _on_tile_clicked(col: int, row: int) -> void:
	if not state_machine.can_place_tower():
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
	tower_manager.add_tower(tower)

	hud.update_credits(currency)

# ── HUD Callbacks ─────────────────────────────────────────────────────────────
func _on_hud_tower_selected(type: TowerDefinition.TowerType) -> void:
	selected_tower_type = type
	_selected_type_set = true

func _on_hud_start_wave() -> void:
	if not state_machine.can_start_wave():
		return
	if not wave_manager.has_more_waves():
		return
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

func _on_enemy_died(enemy: EnemyNode) -> void:
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
	lives -= enemy.lives_damage
	lives = max(lives, 0)
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
	if not wave_manager.has_more_waves():
		_trigger_game_over(true)
		return
	state_machine.transition_to(GameStateMachine.State.WAVE_CLEAR)
	hud.update_wave(wave_manager.current_wave_number() - 1, wave_manager.total_waves())
	hud.update_next_wave(_wave_preview_text())
	hud.set_start_wave_enabled(true)

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
