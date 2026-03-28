## EnemyDefinition.gd — Enemy types and stats
class_name EnemyDefinition

enum EnemyType { SCOUT, TANK, BOSS }

# Returns a dict with: hp, speed (px/s), reward (currency), lives_damage, color
static func stats(type: EnemyType) -> Dictionary:
	match type:
		EnemyType.SCOUT:
			return { "hp": 50, "speed": 200.0, "reward": 5, "lives_damage": 1,
					 "color": Color(0.0, 1.0, 0.4), "size": Vector2(20, 20), "label": "Scout" }
		EnemyType.TANK:
			return { "hp": 500, "speed": 60.0, "reward": 40, "lives_damage": 3,
					 "color": Color(1.0, 0.4, 0.0), "size": Vector2(36, 36), "label": "Tank" }
		EnemyType.BOSS:
			return { "hp": 2000, "speed": 40.0, "reward": 200, "lives_damage": 0,
					 "color": Color(0.6, 0.0, 0.8), "size": Vector2(52, 52), "label": "Boss",
					 "is_boss": true,
					 "stun_range": 200.0, "stun_interval": 4.0, "stun_duration": 2.0 }
	return {}
