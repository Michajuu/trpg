class_name Unit
extends Node2D

enum facing_direction {RIGHT, LEFT}

@export var unit_name: String = "Unit"
@export var max_hp: int = 100
@export var dmg: int = 10
@export var map_position = Vector2i(0,0)
## Chance (0.0–1.0) for this unit's attacks to crit (0.025 = 2.5%).
@export_range(0.0, 1.0) var crit_chance: float = 0.025
## Damage multiplier of this unit's critical hits.
@export var crit_multiplier: float = 2.0
## Speed of the tile-to-tile movement animation, in pixels per second (FPS-independent).
@export var move_speed: float = 300
var current_hp: int
var destination : Vector2 = position
var facing : facing_direction = facing_direction.RIGHT

var manager : Battle_Manager

signal _request_can_unit_move(from_position: Vector2i ,to_position: Vector2i, target_pos: Vector2,callback: Callable)
signal _attack_tiles(attack: Attack)

func _ready() -> void:
	current_hp = max_hp

func _take_damage(hit: Hit) -> void:
	current_hp = max(current_hp - hit.damage, 0)

## True if a hit coming from from_position lands on the unit's back.
## Units only face left/right, so only the x axis matters; hits from the same column are never from behind.
func is_hit_from_behind(from_position: Vector2i) -> bool:
	var dx: int = from_position.x - map_position.x
	return dx > 0 if facing == facing_direction.LEFT else dx < 0

## Moves the unit toward destination. Call every frame with delta.
func _move_toward_destination(delta: float) -> void:
	var step := move_speed * delta
	position.x = move_toward(position.x, destination.x, step)
	position.y = move_toward(position.y, destination.y, step)

func _on_can_unit_move_response(can_move: bool, target_map_pos: Vector2i, target_pos: Vector2) -> void:
	if can_move:
		map_position = target_map_pos
		position = target_pos
