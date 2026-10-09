class_name EncounterData
extends Resource

var player_spawn: Vector2i
var enemies: Array[UnitData]
var obstacles: Array[UnitData]

static func from_dict(dict: Dictionary) -> EncounterData:
	var obj = EncounterData.new()
	var spawn_dict = dict.get("player_spawn", {})
	obj.player_spawn = Vector2i(spawn_dict.get("x", 0), spawn_dict.get("y", 0))
	for enemies_dict in dict.get("enemies", []):
		obj.enemies.append(UnitData.from_dict(enemies_dict))
	for obstacle_dict in dict.get("obstacles", []):
		obj.obstacles.append(UnitData.from_dict(obstacle_dict))
	
	return obj
