## TowerDefinition.gd — Tower types and stats
class_name TowerDefinition

enum TowerType { LASER, CANNON, MISSILE }

# Returns a dict with: cost, damage, range, fire_rate (seconds), splash_radius, projectile_speed
static func stats(type: TowerType) -> Dictionary:
	match type:
		TowerType.LASER:
			return { "cost": 50, "damage": 10, "range": 180.0, "fire_rate": 0.3,
					 "splash_radius": 0.0, "projectile_speed": 600.0, "label": "Laser" }
		TowerType.CANNON:
			return { "cost": 100, "damage": 40, "range": 150.0, "fire_rate": 1.2,
					 "splash_radius": 60.0, "projectile_speed": 400.0, "label": "Cannon" }
		TowerType.MISSILE:
			return { "cost": 150, "damage": 80, "range": 300.0, "fire_rate": 2.0,
					 "splash_radius": 0.0, "projectile_speed": 350.0, "label": "Missile" }
	return {}
