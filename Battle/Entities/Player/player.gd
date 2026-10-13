class_name Player
extends Unit

signal update_player_healthbar(new_hp: int)
signal tempo_changed(percentage: int, tempo: int)

const PERCENT_PER_TEMPO := 10
const MAX_TEMPO_PERCENTAGE := 100

## Ile procent Tempa daje jeden podstawowy atak.
@export var tempo_per_attack: int = 5
## Co ile sekund bezczynności Tempo spada.
@export var tempo_decay_interval: float = 0.5
## Ile procent Tempa traci się co tempo_decay_interval.
@export var tempo_decay_amount: int = 1

# Czas od ostatniej akcji (ruch/atak) albo od ostatniego spadku.
var _tempo_decay_time: float = 0.0

var tempo_percentage: int = 0:
	set(value):
		tempo_percentage = clampi(value, 0, MAX_TEMPO_PERCENTAGE)
		tempo_changed.emit(tempo_percentage, tempo)

## Pełne punkty Tempa: każde 10% = 1 Tempo.
var tempo: int:
	get:
		@warning_ignore("integer_division")
		return tempo_percentage / PERCENT_PER_TEMPO

@onready var sprite : AnimatedSprite2D = $Sprite
@onready var AttackCooldownTimer : Timer = $AttackCooldown

func _ready() -> void:
	current_hp = max_hp
	sprite.play("idle")

func _process(delta: float) -> void:
	_update_tempo_decay(delta)
	#Change sprite rotation according to direction
	sprite.flip_h = facing
	#Movement
	if !sprite.is_playing():
		sprite.play("idle")
	elif position != destination:
		position.x = move_toward(position.x,destination.x,3)
		position.y = move_toward(position.y,destination.y,3)
	elif Input.is_action_just_pressed("ui_right"):
		var new_map_position = Vector2i(map_position.x + 1, map_position.y)
		var new_position = Vector2(position.x+46, position.y)
		facing = facing_direction.RIGHT
		_move(new_map_position,new_position)
	elif Input.is_action_just_pressed("ui_left"):
		var new_map_position = Vector2i(map_position.x - 1, map_position.y)
		var new_position = Vector2(position.x-46, position.y)
		facing = facing_direction.LEFT
		_move(new_map_position,new_position)
	elif Input.is_action_just_pressed("ui_up"):
		var new_map_position = Vector2i(map_position.x, map_position.y - 1)
		var new_position = Vector2(position.x+32, position.y-32)
		_move(new_map_position,new_position)
	elif Input.is_action_just_pressed("ui_down"):
		var new_map_position = Vector2i(map_position.x, map_position.y + 1)
		var new_position = Vector2(position.x-32, position.y+32)
		_move(new_map_position,new_position)
	#Attacking
	if Input.is_action_just_pressed("basic_attack") and AttackCooldownTimer.is_stopped():
		var tile : Array[Vector2i] = [Vector2i(map_position.x+1*(-1 if facing else 1),map_position.y)]
		AttackCooldownTimer.start()
		_reset_tempo_decay()
		sprite.play("attack")
		# Tempo tylko za trafienie we wroga (nie w powietrze ani w przeszkodę).
		# Sprawdzamy przed emit, bo wróg może zginąć od tego ciosu.
		var hit_enemy: bool = manager._has_enemy_in(tile)
		_attack_tiles.emit(tile,10)
		if hit_enemy:
			add_tempo_percentage(tempo_per_attack)
		manager._move_enemies()

func _move(new_map_position : Vector2i, new_position : Vector2):
	if manager._can_move(self, map_position, new_map_position):
		manager.astar.set_point_weight_scale(map_position, 1.0)
		manager.astar.set_point_weight_scale(new_map_position, 5.0)
		map_position = new_map_position
		destination = new_position
		_reset_tempo_decay()
	else:
		facing = facing_direction.RIGHT if facing == facing_direction.LEFT else facing_direction.LEFT

func add_tempo_percentage(amount: int) -> void:
	tempo_percentage += amount

## Gdy gracz nic nie robi, co tempo_decay_interval traci tempo_decay_amount %.
func _update_tempo_decay(delta: float) -> void:
	if tempo_percentage <= 0 or tempo_decay_interval <= 0.0:
		_tempo_decay_time = 0.0
		return
	_tempo_decay_time += delta
	while _tempo_decay_time >= tempo_decay_interval:
		_tempo_decay_time -= tempo_decay_interval
		add_tempo_percentage(-tempo_decay_amount)

## Każda akcja gracza zaczyna odliczanie od nowa.
func _reset_tempo_decay() -> void:
	_tempo_decay_time = 0.0

## Wydaje pełne punkty Tempa (np. na umiejętność). Zwraca false, jeśli za mało.
func spend_tempo(amount: int) -> bool:
	if tempo < amount:
		return false
	tempo_percentage -= amount * PERCENT_PER_TEMPO
	return true

func _take_damage(damage: int) -> void:
	current_hp = max(current_hp - damage, 0)
	update_player_healthbar.emit(current_hp)
