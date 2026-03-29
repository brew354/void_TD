## EnemyDefinition.gd — Enemy types and stats
class_name EnemyDefinition

enum EnemyType { SCOUT, TANK, BOSS, SPEEDER, SHIELDED, MEGA_BOSS }

# Returns a dict with: hp, speed (px/s), reward (currency), lives_damage, color
static func stats(type: EnemyType) -> Dictionary:
	match type:
		EnemyType.SCOUT:
			return { "hp": 65, "speed": 200.0, "reward": 5, "lives_damage": 1,
					 "color": Color(0.0, 1.0, 0.4), "size": Vector2(20, 20), "label": "Void Scout" }
		EnemyType.TANK:
			return { "hp": 600, "speed": 60.0, "reward": 45, "lives_damage": 3,
					 "color": Color(1.0, 0.4, 0.0), "size": Vector2(36, 36), "label": "Void Colossus" }
		EnemyType.BOSS:
			return { "hp": 2000, "speed": 40.0, "reward": 200, "lives_damage": 0,
					 "color": Color(0.6, 0.0, 0.8), "size": Vector2(52, 52), "label": "Void Herald",
					 "is_boss": true,
					 "stun_range": 200.0, "stun_interval": 3.5, "stun_duration": 2.0 }
		EnemyType.SPEEDER:
			return { "hp": 30, "speed": 400.0, "reward": 10, "lives_damage": 1,
					 "color": Color(0.0, 0.95, 1.0), "size": Vector2(14, 14), "label": "Void Shade" }
		EnemyType.SHIELDED:
			return { "hp": 350, "speed": 75.0, "reward": 70, "lives_damage": 2,
					 "color": Color(0.4, 0.6, 1.0), "size": Vector2(30, 30), "label": "Void Sentinel",
					 "shield_interval": 5.0, "shield_duration": 2.0 }
		EnemyType.MEGA_BOSS:
			return { "hp": 5000, "speed": 30.0, "reward": 300, "lives_damage": 4,
					 "color": Color(0.22, 0.22, 0.28), "size": Vector2(70, 70), "label": "THE VOID",
					 "is_boss": true,
					 "stun_range": 250.0, "stun_interval": 4.0, "stun_duration": 2.5,
					 "armor_threshold": 2500.0 }
	return {}
