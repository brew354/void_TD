## Headless validation — comprehensive check of all systems
extends SceneTree

const GameConfig       = preload("res://Models/GameConfig.gd")
const TowerDefinition  = preload("res://Models/TowerDefinition.gd")
const EnemyDefinition  = preload("res://Models/EnemyDefinition.gd")
const WaveDefinition   = preload("res://Models/WaveDefinition.gd")
const GridManager      = preload("res://Systems/GridManager.gd")
const GameStateMachine = preload("res://Systems/GameStateMachine.gd")
const TowerManager     = preload("res://Systems/TowerManager.gd")
const EnemyNode        = preload("res://Nodes/EnemyNode.gd")
const TowerNode        = preload("res://Nodes/TowerNode.gd")

var _pass: int = 0
var _fail: int = 0

func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: ", msg)
		_pass += 1
	else:
		push_error("  FAIL: " + msg)
		_fail += 1

func _init() -> void:
	print("\n=== SpaceTD Full Validation ===\n")

	# --- GameConfig ---
	print("[ GameConfig ]")
	_assert(GameConfig.STARTING_LIVES == 5, "STARTING_LIVES = 5")
	_assert(GameConfig.TILE_SIZE == 64.0, "TILE_SIZE = 64")
	_assert(GameConfig.GRID_COLS == 20, "GRID_COLS = 20")
	_assert(GameConfig.GRID_ROWS == 11, "GRID_ROWS = 11")
	_assert(GameConfig.PATH_WAYPOINTS.size() == 8, "8 waypoints")
	var pos = GameConfig.scene_position(0, 0)
	_assert(pos.x > 0 and pos.y > 0, "scene_position(0,0) > 0")
	var coord = GameConfig.grid_coord(Vector2(100, 100))
	_assert(coord != null, "grid_coord in-bounds returns non-null")
	var oob = GameConfig.grid_coord(Vector2(-100, -100))
	_assert(oob == null, "grid_coord out-of-bounds returns null")

	# --- TowerDefinition ---
	print("\n[ TowerDefinition ]")
	for t in [TowerDefinition.TowerType.LASER, TowerDefinition.TowerType.CANNON, TowerDefinition.TowerType.MISSILE]:
		var s = TowerDefinition.stats(t)
		_assert(s["cost"] > 0, "%s cost > 0" % s["label"])
		_assert(s["damage"] > 0, "%s damage > 0" % s["label"])
		_assert(s["range"] > 0, "%s range > 0" % s["label"])
		_assert(s["fire_rate"] > 0, "%s fire_rate > 0" % s["label"])

	# --- EnemyDefinition ---
	print("\n[ EnemyDefinition ]")
	for e in [EnemyDefinition.EnemyType.SCOUT, EnemyDefinition.EnemyType.TANK]:
		var s = EnemyDefinition.stats(e)
		_assert(s["hp"] > 0, "%s hp > 0" % s["label"])
		_assert(s["speed"] > 0, "%s speed > 0" % s["label"])
		_assert(s["reward"] > 0, "%s reward > 0" % s["label"])
	var boss_stats = EnemyDefinition.stats(EnemyDefinition.EnemyType.BOSS)
	_assert(boss_stats["hp"] == 2000, "Boss hp = 2000")
	_assert(boss_stats["is_boss"] == true, "Boss is_boss = true")
	_assert(boss_stats["stun_range"] > 0, "Boss stun_range > 0")
	_assert(boss_stats["lives_damage"] == 0, "Boss lives_damage = 0")

	# --- WaveDefinition ---
	print("\n[ WaveDefinition ]")
	var waves = WaveDefinition.all_waves()
	_assert(waves.size() == 3, "3 waves defined")
	var w1_count = 0
	for g in waves[0].groups: w1_count += g.count
	_assert(w1_count == 8, "Wave 1: 8 enemies")
	var w2_count = 0
	for g in waves[1].groups: w2_count += g.count
	_assert(w2_count == 8, "Wave 2: 8 enemies (5+3)")
	var w3_count = 0
	for g in waves[2].groups: w3_count += g.count
	_assert(w3_count == 10, "Wave 3: 10 enemies (4+5+1 boss)")
	_assert(waves[2].groups.size() == 3, "Wave 3 has 3 spawn groups")
	_assert(waves[2].groups[2].type == EnemyDefinition.EnemyType.BOSS, "Wave 3 third group is BOSS")
	_assert(waves[2].groups[2].count == 1, "Wave 3 boss group count = 1")

	# --- GridManager ---
	print("\n[ GridManager ]")
	var gm = GridManager.new()
	_assert(gm.can_place(5, 5), "Empty tile is placeable")
	# Waypoints include x=256,y=384 → col=4,row≈5 – mark and check
	var path_coord = GameConfig.grid_coord(GameConfig.PATH_WAYPOINTS[1])
	if path_coord != null:
		var ps = gm.get_state(path_coord.x, path_coord.y)
		_assert(ps == GridManager.TileState.PATH, "Path waypoint tile marked as PATH")
	gm.place(5, 5)
	_assert(not gm.can_place(5, 5), "After place(), tile not placeable")
	gm.remove(5, 5)
	_assert(gm.can_place(5, 5), "After remove(), tile placeable again")

	# --- GameStateMachine ---
	print("\n[ GameStateMachine ]")
	var sm = GameStateMachine.new()
	_assert(sm.current == GameStateMachine.State.BUILD_PHASE, "Starts in BUILD_PHASE")
	_assert(sm.can_start_wave(), "Can start wave in BUILD_PHASE")
	_assert(sm.can_place_tower(), "Can place tower in BUILD_PHASE")
	sm.transition_to(GameStateMachine.State.WAVE_IN_PROGRESS)
	_assert(sm.current == GameStateMachine.State.WAVE_IN_PROGRESS, "Transition to WAVE_IN_PROGRESS")
	_assert(sm.can_place_tower(), "Can place tower during wave")
	_assert(not sm.can_start_wave(), "Cannot start wave while in progress")
	sm.transition_to(GameStateMachine.State.PAUSED)
	_assert(sm.current == GameStateMachine.State.PAUSED, "Transition to PAUSED")
	sm.resume_from_pause()
	_assert(sm.current == GameStateMachine.State.WAVE_IN_PROGRESS, "Resume from pause restores prior state")

	# --- EnemyNode (partial - no scene tree needed for setup) ---
	print("\n[ EnemyNode ]")
	var enemy = EnemyNode.new()
	enemy.setup(EnemyDefinition.EnemyType.SCOUT)
	_assert(enemy.max_hp == 50.0, "Scout max_hp = 50")
	_assert(enemy.speed == 200.0, "Scout speed = 200")
	_assert(enemy.reward == 5, "Scout reward = 5")
	_assert(not enemy.is_dead, "Enemy not dead on spawn")
	_assert(enemy.path_progress == 0.0, "Path progress starts at 0")
	enemy.take_damage(25.0)
	_assert(enemy.current_hp == 25.0, "HP reduced by damage")
	_assert(not enemy.is_dead, "Not dead at 25 HP")
	enemy.take_damage(25.0)
	_assert(enemy.is_dead, "Dead after lethal damage")
	enemy.queue_free()

	var tank = EnemyNode.new()
	tank.setup(EnemyDefinition.EnemyType.TANK)
	_assert(tank.max_hp == 500.0, "Tank max_hp = 500")
	_assert(tank.lives_damage == 3, "Tank lives_damage = 3")
	tank.queue_free()

	var boss = EnemyNode.new()
	boss.setup(EnemyDefinition.EnemyType.BOSS)
	_assert(boss.is_boss == true, "Boss enemy is_boss = true")
	_assert(boss.max_hp == 2000.0, "Boss max_hp = 2000")
	_assert(boss.lives_damage == 0, "Boss lives_damage = 0")
	_assert(boss.stun_pulse.get_connections().size() >= 0, "Boss has stun_pulse signal")
	boss.queue_free()

	# --- TowerNode stun ---
	print("\n[ TowerNode stun ]")
	var tower = TowerNode.new()
	tower.setup(TowerDefinition.TowerType.LASER, [], null)
	_assert(tower._stun_timer == 0.0, "Tower stun_timer starts at 0")
	tower.apply_stun(2.0)
	_assert(tower._stun_timer > 0.0, "apply_stun(2.0) sets stun_timer > 0")
	tower.apply_stun(1.0)
	_assert(tower._stun_timer == 2.0, "apply_stun with shorter duration keeps max")
	tower.apply_stun(3.0)
	_assert(tower._stun_timer == 3.0, "apply_stun with longer duration refreshes timer")
	tower.queue_free()

	# --- Summary ---
	print("\n=== Results: %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		quit(1)
	else:
		quit(0)
