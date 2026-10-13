class_name Dummy
extends Enemy

func _decide_next_action(astar: AStarGrid2D, player_map_position: Vector2i) -> void:
	current_hp = max_hp
