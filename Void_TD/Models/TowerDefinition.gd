## TowerDefinition.gd — Tower types and stats
class_name TowerDefinition

enum TowerType { LASER, CANNON, MISSILE, MECHA_SOLDIER }

# Returns a dict with: cost, damage, range, fire_rate (seconds), splash_radius, projectile_speed
static func stats(type: TowerType) -> Dictionary:
	match type:
		TowerType.LASER:
			return { "cost": 50, "damage": 10, "range": 180.0, "fire_rate": 0.3,
					 "splash_radius": 0.0, "projectile_speed": 600.0, "label": "Photon Lance" }
		TowerType.CANNON:
			return { "cost": 100, "damage": 40, "range": 150.0, "fire_rate": 1.2,
					 "splash_radius": 60.0, "projectile_speed": 400.0, "label": "Plasma Cannon" }
		TowerType.MISSILE:
			return { "cost": 150, "damage": 80, "range": 300.0, "fire_rate": 2.0,
					 "splash_radius": 0.0, "projectile_speed": 350.0, "label": "Void-Seeker" }
		TowerType.MECHA_SOLDIER:
			return { "cost": 300, "damage": 150, "range": 220.0, "fire_rate": 1.0,
					 "splash_radius": 45.0, "projectile_speed": 500.0, "label": "Titan Mech" }
	return {}

## Returns the maximum number of this tower that can be placed. 0 = unlimited.
static func max_count(type: TowerType) -> int:
	match type:
		TowerType.CANNON:        return 6
		TowerType.MISSILE:       return 4
		TowerType.MECHA_SOLDIER: return 4
	return 0

static func upgrade_cost(type: TowerType, to_level: int) -> int:
	var base = stats(type)["cost"]
	if to_level == 2: return base / 2
	if to_level == 3: return base
	return 0

static func upgrade_multipliers(level: int) -> Dictionary:
	match level:
		2: return {"damage": 1.6, "range": 1.3}
		3: return {"damage": 2.5, "range": 1.6}
	return {"damage": 1.0, "range": 1.0}
