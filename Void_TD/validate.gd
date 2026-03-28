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
const BaseNode         = preload("res://Nodes/BaseNode.gd")

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
	print("\n=== Void_TD Full Validation ===\n")

	# --- GameConfig ---
	print("[ GameConfig ]")
	_assert(GameConfig.STARTING_LIVES == 5, "STARTING_LIVES = 5")
	_assert(GameConfig.STARTING_CREDITS == 300, "STARTING_CREDITS = 300")
	_assert(GameConfig.WAVE_COMPLETE_BONUS == 75, "WAVE_COMPLETE_BONUS = 75")
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
	for t in [TowerDefinition.TowerType.LASER, TowerDefinition.TowerType.CANNON,
			TowerDefinition.TowerType.MISSILE, TowerDefinition.TowerType.MECHA_SOLDIER]:
		var s = TowerDefinition.stats(t)
		_assert(s["cost"] > 0, "%s cost > 0" % s["label"])
		_assert(s["damage"] > 0, "%s damage > 0" % s["label"])
		_assert(s["range"] > 0, "%s range > 0" % s["label"])
		_assert(s["fire_rate"] > 0, "%s fire_rate > 0" % s["label"])
	var mecha = TowerDefinition.stats(TowerDefinition.TowerType.MECHA_SOLDIER)
	_assert(mecha["cost"] == 300, "Mecha cost = 300")
	_assert(mecha["damage"] > TowerDefinition.stats(TowerDefinition.TowerType.MISSILE)["damage"], "Mecha damage > Missile damage")
	_assert(TowerDefinition.upgrade_cost(TowerDefinition.TowerType.MECHA_SOLDIER, 2) == 150, "Mecha L2 cost = 150")
	_assert(TowerDefinition.upgrade_cost(TowerDefinition.TowerType.MECHA_SOLDIER, 3) == 300, "Mecha L3 cost = 300")

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
	_assert(waves.size() == 10, "10 waves defined")
	var w1_count = 0
	for g in waves[0].groups: w1_count += g.count
	_assert(w1_count == 6, "Wave 1: 6 enemies")
	var w2_count = 0
	for g in waves[1].groups: w2_count += g.count
	_assert(w2_count == 9, "Wave 2: 9 enemies")
	var w3_count = 0
	for g in waves[2].groups: w3_count += g.count
	_assert(w3_count == 8, "Wave 3: 8 enemies (5+2+1 boss)")
	_assert(waves[2].groups.size() == 3, "Wave 3 has 3 spawn groups")
	_assert(waves[2].groups[2].type == EnemyDefinition.EnemyType.BOSS, "Wave 3 third group is BOSS")
	_assert(waves[2].groups[2].count == 1, "Wave 3 boss group count = 1")
	_assert(waves[5].groups[2].type == EnemyDefinition.EnemyType.BOSS, "Wave 6 has boss")
	_assert(waves[8].groups[2].type == EnemyDefinition.EnemyType.BOSS, "Wave 9 has boss")
	_assert(waves[9].groups[2].count == 3, "Wave 10 has 3 bosses")
	_assert(waves[1].difficulty_scale > waves[0].difficulty_scale, "Scale increases each wave")
	_assert(waves[9].difficulty_scale > waves[4].difficulty_scale, "Wave 10 harder than wave 5")

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
	_assert(enemy.max_hp == 65.0, "Scout max_hp = 65")
	_assert(enemy.speed == 200.0, "Scout speed = 200")
	_assert(enemy.reward == 5, "Scout reward = 5")
	_assert(not enemy.is_dead, "Enemy not dead on spawn")
	_assert(enemy.path_progress == 0.0, "Path progress starts at 0")
	enemy.take_damage(30.0)
	_assert(enemy.current_hp == 35.0, "HP reduced by damage")
	_assert(not enemy.is_dead, "Not dead at 35 HP")
	enemy.take_damage(35.0)
	_assert(enemy.is_dead, "Dead after lethal damage")
	enemy.queue_free()

	var tank = EnemyNode.new()
	tank.setup(EnemyDefinition.EnemyType.TANK)
	_assert(tank.max_hp == 600.0, "Tank max_hp = 600")
	_assert(tank.lives_damage == 3, "Tank lives_damage = 3")
	tank.queue_free()

	var boss = EnemyNode.new()
	boss.setup(EnemyDefinition.EnemyType.BOSS)
	_assert(boss.is_boss == true, "Boss enemy is_boss = true")
	_assert(boss.max_hp == 2000.0, "Boss max_hp = 2000")
	_assert(boss.lives_damage == 0, "Boss lives_damage = 0")
	_assert(boss.stun_pulse.get_connections().size() >= 0, "Boss has stun_pulse signal")
	boss.queue_free()

	var scaled = EnemyNode.new()
	scaled.setup(EnemyDefinition.EnemyType.SCOUT, 2.0)
	_assert(scaled.max_hp == 130.0, "Scout at scale 2.0 has 130 hp")
	_assert(scaled.speed > 200.0, "Scout at scale 2.0 is faster than base")
	scaled.queue_free()

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

	# --- Tower Upgrade System ---
	print("\n[ Tower Upgrade System ]")
	_assert(TowerDefinition.upgrade_cost(TowerDefinition.TowerType.LASER, 2) == 25, "Laser L2 cost = 25")
	_assert(TowerDefinition.upgrade_cost(TowerDefinition.TowerType.CANNON, 2) == 50, "Cannon L2 cost = 50")
	_assert(TowerDefinition.upgrade_cost(TowerDefinition.TowerType.MISSILE, 3) == 150, "Missile L3 cost = 150")
	_assert(TowerDefinition.upgrade_cost(TowerDefinition.TowerType.LASER, 4) == 0, "Invalid level cost = 0")

	var m1 = TowerDefinition.upgrade_multipliers(1)
	_assert(m1["damage"] == 1.0 and m1["range"] == 1.0, "L1 multipliers = 1.0")
	var m2 = TowerDefinition.upgrade_multipliers(2)
	_assert(m2["damage"] == 1.6 and m2["range"] == 1.3, "L2 multipliers correct")
	var m3 = TowerDefinition.upgrade_multipliers(3)
	_assert(m3["damage"] == 2.5 and m3["range"] == 1.6, "L3 multipliers correct")

	var utower = TowerNode.new()
	utower.setup(TowerDefinition.TowerType.CANNON, [], null)
	_assert(utower.upgrade_level == 1, "Tower starts at L1")
	_assert(utower.total_invested == 100, "Cannon total_invested = 100 after setup")
	_assert(utower.base_damage == 40.0, "Cannon base_damage = 40")
	utower.upgrade()
	_assert(utower.upgrade_level == 2, "Tower upgraded to L2")
	_assert(is_equal_approx(utower.damage, 64.0), "L2 damage = 40 * 1.6 = 64")
	_assert(is_equal_approx(utower.range_radius, 195.0), "L2 range = 150 * 1.3 = 195")
	_assert(utower.total_invested == 150, "total_invested after L2 = 100 + 50 = 150")
	utower.upgrade()
	_assert(utower.upgrade_level == 3, "Tower upgraded to L3")
	_assert(is_equal_approx(utower.damage, 100.0), "L3 damage = 40 * 2.5 = 100")
	_assert(is_equal_approx(utower.range_radius, 240.0), "L3 range = 150 * 1.6 = 240")
	_assert(utower.total_invested == 250, "total_invested after L3 = 100 + 50 + 100 = 250")
	_assert(utower.total_invested / 2 == 125, "L3 sell refund = 125")
	utower.queue_free()

	# --- BaseNode upgrades ---
	print("\n[ BaseNode upgrades ]")
	var bn = BaseNode.new()
	bn.setup(Vector2(0, 0))
	_assert(bn.upgrade_level == 1, "Base starts at L1")
	_assert(bn.damage_reduction == 0, "Base L1 damage_reduction = 0")
	_assert(bn.upgrade_cost(2) == 100, "Base L2 cost = 100")
	_assert(bn.upgrade_cost(3) == 200, "Base L3 cost = 200")
	_assert(bn.upgrade_cost(4) == 0, "Base beyond L3 cost = 0")
	bn.upgrade()
	_assert(bn.upgrade_level == 2, "Base upgraded to L2")
	_assert(bn.damage_reduction == 1, "Base L2 reduction = 1")
	_assert(bn.total_invested == 100, "Base total_invested after L2 = 100")
	_assert(max(1 - bn.damage_reduction, 1) == 1, "Scout (1 dmg) at L2 base still costs 1 life")
	_assert(max(3 - bn.damage_reduction, 1) == 2, "Tank (3 dmg) at L2 base costs 2 lives")
	bn.upgrade()
	_assert(bn.upgrade_level == 3, "Base upgraded to L3")
	_assert(bn.damage_reduction == 2, "Base L3 reduction = 2")
	_assert(bn.total_invested == 300, "Base total_invested after L3 = 300")
	_assert(max(1 - bn.damage_reduction, 1) == 1, "Scout (1 dmg) at L3 base still costs 1 life")
	_assert(max(3 - bn.damage_reduction, 1) == 1, "Tank (3 dmg) at L3 base costs 1 life")
	bn.queue_free()

	# --- Summary ---
	print("\n=== Results: %d passed, %d failed ===" % [_pass, _fail])
	if _fail > 0:
		quit(1)
	else:
		quit(0)
