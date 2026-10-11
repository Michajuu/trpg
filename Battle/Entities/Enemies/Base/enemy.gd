class_name Enemy
extends Unit


@export var warning_tile : PackedScene = preload("res://Battle/System/warning_tile.tscn")
@export var health_bar: ProgressBar
@onready var sprite : AnimatedSprite2D = $Sprite
const WARNING_TILE_POSITION_ZERO = Vector2(200,220)

var warning_tiles : Array

signal enemy_died(enemy: Enemy)
signal _enemy_updated_position(enemy: Enemy, from_map_position: Vector2i, to_map_position: Vector2i)

var about_to_attack : bool = false
var turnsUntilAttack: int = 0

func _ready() -> void:
	sprite.play("idle")
	current_hp = max_hp
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp

func _process(delta: float) -> void:
	if position != destination:
		position.x = move_toward(position.x,destination.x,3)
		position.y = move_toward(position.y,destination.y,3)

func _take_damage(damage: int) -> void:
	current_hp = max(current_hp - damage, 0)
	if health_bar:
		health_bar.value = current_hp
	if !current_hp:
		enemy_died.emit(self)
		queue_free()

func _decide_next_action(astar: AStarGrid2D, player_map_position : Vector2i) -> void:
	print(self.name + ": I don't have an AI ;P")

func _try_path_to(astar: AStarGrid2D, tile: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = astar.get_id_path(map_position, tile)
	return path

func _commit_move(path: Array[Vector2i]) -> void:
	var new_map_position := path[1]
	_update_facing(new_map_position)
	_enemy_updated_position.emit(self, map_position, new_map_position)
	map_position = new_map_position
	destination = manager.map_position_to_position(new_map_position)

func _update_facing(new_map_position: Vector2i):
	var direction = new_map_position-map_position
	if direction.x:
		facing = facing_direction.LEFT if direction.x == -1 else facing_direction.RIGHT
		sprite.flip_h = facing
	else:
		var player_map_position = manager.player.map_position
		var direction_to_player = clamp(player_map_position.x - new_map_position.x,-1,1)
		facing = facing_direction.LEFT if direction_to_player == -1 else facing_direction.RIGHT
		sprite.flip_h = facing

func _place_warning_tile(tiles: Array[Vector2i]) -> void:
	for tile in tiles:
		var warning_tile_instance = warning_tile.instantiate()
		warning_tiles.append(warning_tile_instance)
		add_child(warning_tile_instance)
		warning_tile_instance.global_position.x = WARNING_TILE_POSITION_ZERO.x + (tile.x * 46) - (tile.y * 32)
		warning_tile_instance.global_position.y = WARNING_TILE_POSITION_ZERO.y + (tile.y * 32)
	about_to_attack = true

func _remove_warning_tiles() -> void:
	for warning_tile in warning_tiles:
		warning_tile.queue_free()
	warning_tiles = []
