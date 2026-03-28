## TowerManager.gd — Tracks all placed towers and drives their update loop
class_name TowerManager

var towers: Array = []  # Array[TowerNode]

func add_tower(tower) -> void:
	towers.append(tower)

func remove_tower(tower) -> void:
	towers.erase(tower)

func update(delta: float, enemies: Array) -> void:
	for tower in towers:
		if is_instance_valid(tower):
			tower.update_tower(delta, enemies)
