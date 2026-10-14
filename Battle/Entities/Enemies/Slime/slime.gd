class_name Slime
extends Enemy

func _decide_next_action(astar: AStarGrid2D, player_map_position: Vector2i) -> void:
	#Attacking
	var tiles_to_check : Array[Vector2i] = [Vector2i(map_position.x + 1 * (-1 if facing else 1), map_position.y)]
	if turnsUntilAttack:
		turnsUntilAttack -= 1
		if !turnsUntilAttack:
			_place_warning_tile(tiles_to_check)
	elif about_to_attack:
		_attack_tiles.emit(Attack.new(self, tiles_to_check, dmg))
		about_to_attack = false
		_remove_warning_tiles()
	elif manager._is_player_there(tiles_to_check):
		turnsUntilAttack = 1
	#Movement
	else:
		var path_right : Array[Vector2i] = _try_path_to(astar, Vector2i(min(player_map_position.x+1, 8), player_map_position.y))
		var path_left : Array[Vector2i] = _try_path_to(astar, Vector2i(max(player_map_position.x-1, 0), player_map_position.y))
		var chosen_path : Array[Vector2i] = path_right
		if path_right.size() > path_left.size() or path_right.size() == 0:
			chosen_path = path_left
		if chosen_path.size() <= 1:
			chosen_path = _try_path_to(astar, player_map_position)
		if not chosen_path.size() <= 1:
			_update_facing(chosen_path[1])
			if manager._can_move(self, map_position, chosen_path[1]):
				_commit_move(chosen_path)
