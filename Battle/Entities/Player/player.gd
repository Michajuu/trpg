class_name Player
extends Unit

signal update_player_healthbar(new_hp: int)

@onready var sprite : AnimatedSprite2D = $Sprite
@onready var AttackCooldownTimer : Timer = $AttackCooldown

func _ready() -> void:
	current_hp = max_hp
	sprite.play("idle")

func _process(_delta: float) -> void:
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
		sprite.play("attack")
		_attack_tiles.emit(tile,10)
		manager._move_enemies()

func _move(new_map_position : Vector2i, new_position : Vector2):
	if manager._can_move(self, map_position, new_map_position):
		manager.astar.set_point_weight_scale(map_position, 1.0)
		manager.astar.set_point_weight_scale(new_map_position, 5.0)
		manager.print_astar_grid(manager.astar)
		map_position = new_map_position
		destination = new_position
	else:
		facing = facing_direction.RIGHT if facing == facing_direction.LEFT else facing_direction.LEFT

func _take_damage(damage: int) -> void:
	current_hp = max(current_hp - damage, 0)
	update_player_healthbar.emit(current_hp)
