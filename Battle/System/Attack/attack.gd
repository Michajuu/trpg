class_name Attack
extends RefCounted

## A single hit: who attacks, which tiles, how hard.
## Basic attacks and skills both build one of these, so hit modifiers
## (like backstab) live here and apply to every source of damage.

const DEFAULT_BACKSTAB_MULTIPLIER := 1.2

var attacker: Unit
var tiles: Array[Vector2i]
## Base damage, before hit modifiers (already includes attacker-side bonuses like Tempo).
var damage: int
## Tile the hit comes from; decides whether it lands from behind.
## Defaults to the attacker's tile. Override for e.g. dashes or projectiles that hit from elsewhere.
var source_position: Vector2i
## Damage multiplier when the target is hit from behind. 1.0 = no backstab bonus.
var backstab_multiplier: float = DEFAULT_BACKSTAB_MULTIPLIER
## Chance (0.0–1.0) to crit, rolled separately for each target. Defaults to the attacker's stat.
var crit_chance: float
## Damage multiplier on a critical hit. Defaults to the attacker's stat.
var crit_multiplier: float

func _init(p_attacker: Unit, p_tiles: Array[Vector2i], p_damage: int) -> void:
	attacker = p_attacker
	tiles = p_tiles
	damage = p_damage
	source_position = p_attacker.map_position
	crit_chance = p_attacker.crit_chance
	crit_multiplier = p_attacker.crit_multiplier

## Resolves this attack against target: rolls crit and applies all hit modifiers.
func resolve_against(target: Unit) -> Hit:
	var multiplier := 1.0
	var is_backstab := target.is_hit_from_behind(source_position)
	if is_backstab:
		multiplier *= backstab_multiplier
	var is_critical := randf() < crit_chance
	if is_critical:
		multiplier *= crit_multiplier
	var hit := Hit.new(roundi(damage * multiplier))
	hit.is_backstab = is_backstab
	hit.is_critical = is_critical
	return hit
