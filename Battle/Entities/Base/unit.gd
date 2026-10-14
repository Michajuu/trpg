class_name Unit
extends Node2D

enum facing_direction {RIGHT, LEFT}

@export var unit_name: String = "Unit"
@export var max_hp: int = 100
@export var dmg: int = 10
@export var map_position = Vector2i(0,0)
## Prędkość animacji przejścia między polami, w pikselach na sekundę (niezależna od FPS).
@export var move_speed: float = 300
var current_hp: int
var destination : Vector2 = position
var facing : facing_direction = facing_direction.RIGHT

var manager : Battle_Manager

signal _request_can_unit_move(from_position: Vector2i ,to_position: Vector2i, target_pos: Vector2,callback: Callable)
signal _attack_tiles(tiles: Array[Vector2i], damage: int)

func _ready() -> void:
	current_hp = max_hp

func _take_damage(damage: int) -> void:
	current_hp = max(current_hp - damage, 0)

## Przesuwa jednostkę w stronę destination. Wywołuj co klatkę z delta.
func _move_toward_destination(delta: float) -> void:
	var step := move_speed * delta
	position.x = move_toward(position.x, destination.x, step)
	position.y = move_toward(position.y, destination.y, step)

func _on_can_unit_move_response(can_move: bool, target_map_pos: Vector2i, target_pos: Vector2) -> void:
	if can_move:
		map_position = target_map_pos
		position = target_pos
