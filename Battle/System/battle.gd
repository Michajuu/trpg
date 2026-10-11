class_name Battle_Manager
extends Control

@export var encounter_json: JSON
@export var player_healtbar: ProgressBar

var player : Player

var player_scene = preload("res://Battle/Entities/Player/player.tscn")

const POSITION_ZERO = Vector2(200,190)

var grid = [
	[null,null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null,null]
]

var astar = AStarGrid2D.new()

var enemies : Array[Enemy]

var map_size = Vector2i(8,4)

func _ready() -> void:
	astar.region = Rect2i(0, 0, map_size.x+1, map_size.y+1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	var encounter_data = EncounterData.from_dict(encounter_json.data)
	var player_instance : Player = player_scene.instantiate()
	# Setting player position on grid
	player_instance.position.x = POSITION_ZERO.x + (encounter_data.player_spawn.x * 46) - (encounter_data.player_spawn.y * 32)
	player_instance.position.y = POSITION_ZERO.y + (encounter_data.player_spawn.y * 32)
	player_instance.destination = player_instance.position
	# Setting map position for movement
	player_instance.map_position = Vector2i(encounter_data.player_spawn.x, encounter_data.player_spawn.y)
	# Setting player position on matrix
	grid[encounter_data.player_spawn.y][encounter_data.player_spawn.x] = player_instance
	# Connecting signals
	player_instance._attack_tiles.connect(_on_attack_tiles)
	player_instance.update_player_healthbar.connect(_on_update_player_healthbar)
	# Setting refrence to parent
	player_instance.manager = self
	
	player = player_instance
	add_child(player_instance)
	
	for enemy : UnitData in encounter_data.enemies:
		var enemy_scene = load("res://Battle/Entities/Enemies/%s/%s.tscn" % [enemy.id, enemy.id])
		var enemy_instance : Enemy = enemy_scene.instantiate()
		# Setting player position on grid
		enemy_instance.position.x = POSITION_ZERO.x + (enemy.position.x * 46) - (enemy.position.y * 32)
		enemy_instance.position.y = POSITION_ZERO.y + (enemy.position.y * 32)
		enemy_instance.destination = enemy_instance.position
		# Setting map position for movement
		enemy_instance.map_position = Vector2i(enemy.position.x, enemy.position.y)
		# Setting enemy position on matrix
		grid[enemy.position.y][enemy.position.x] = enemy_instance
		# Adding enemy to an array
		enemies.append(enemy_instance)
		# Connecting signlas
		enemy_instance._enemy_updated_position.connect(_on_enemy_update_position)
		enemy_instance._attack_tiles.connect(_on_attack_tiles)
		enemy_instance.enemy_died.connect(_on_enemy_death)
		# Setting refrence to parent
		enemy_instance.manager = self
		
		add_child(enemy_instance)
	
	for obstacle : UnitData in encounter_data.obstacles:
		var obstacle_scene = load("res://Battle/Entities/Obstacles/%s/%s.tscn" % [obstacle.id, obstacle.id])
		var obstacle_instance = obstacle_scene.instantiate()
		obstacle_instance.position = map_position_to_position(obstacle.position)
		grid[obstacle.position.y][obstacle.position.x] = obstacle_instance
		astar.set_point_solid(obstacle.position, true)
		add_child(obstacle_instance)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

func _move_enemies() -> void:
	for enemy : Enemy in enemies:
		enemy._decide_next_action(astar, player.map_position)

func _can_move(unit: Unit ,from_map_position: Vector2i,to_map_position: Vector2i) -> bool:
	if to_map_position.x <= map_size.x and to_map_position.y <= map_size.y and to_map_position.x != -1 and to_map_position.y != -1:
		if !grid[to_map_position.y][to_map_position.x]:
			grid[from_map_position.y][from_map_position.x] = null
			grid[to_map_position.y][to_map_position.x] = unit
			if unit is Player:
				_move_enemies()
			return true
	return false

func _on_attack_tiles(tiles: Array[Vector2i], damage: int) -> void:
	for tile in tiles:
		if tile.x <= map_size.x and tile.y <= map_size.y and tile.x != -1 and tile.y != -1:
			var unit = grid[tile.y][tile.x]
			if unit is Unit:
				unit._take_damage(damage)

func _on_enemy_death(enemy: Enemy):
	grid[enemy.map_position.y][enemy.map_position.x] = null
	enemies.erase(enemy)
	enemy.queue_free()

func _on_update_player_healthbar(new_hp: int):
	player_healtbar.value = new_hp

func _is_player_there(tiles: Array[Vector2i]) -> bool:
	for tile in tiles:
		if tile.x <= map_size.x:
			if grid[tile.y][tile.x] is Player:
				return true
	return false

func _on_enemy_update_position(unit: Unit, from_map_position: Vector2i, to_map_position: Vector2i) -> void:
	grid[from_map_position.y][from_map_position.x] = null
	grid[to_map_position.y][to_map_position.x] = unit

func map_position_to_position(map_position: Vector2i) -> Vector2:
	var position = Vector2(0,0)
	position.x = POSITION_ZERO.x + (map_position.x * 46) - (map_position.y * 32)
	position.y = POSITION_ZERO.y + (map_position.y * 32)
	
	return position

func print_astar_grid(astar: AStarGrid2D, path: Array[Vector2i] = []) -> void:
	var region := astar.region  
	for y in range(region.position.y, region.end.y):
		var row := ""
		for x in range(region.position.x, region.end.x):
			var cell := Vector2i(x, y)
			if astar.is_point_solid(cell):
				row += " ## "
			elif cell in path:
				row += " ** "
			else:
				row += "%4.1f" % astar.get_point_weight_scale(cell)
			row += " "
		print(row)
	print("")   # blank line between prints

func _print_grid() -> void:
	for row in grid:
		print(row)
	print("-----------------")
