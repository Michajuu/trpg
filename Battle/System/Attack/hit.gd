class_name Hit
extends RefCounted

## Outcome of an Attack landing on one target: final damage plus what modifiers applied.
## Passed to Unit._take_damage so reactions (damage numbers, effects) can tell what happened.

var damage: int
var is_critical: bool = false
var is_backstab: bool = false

func _init(p_damage: int) -> void:
	damage = p_damage
