class_name Fuse
extends Unit

## Body of a dead enemy with Enemy.explosion_tiles, about to blow up (Battle.light_fuse).
## It isn't in Battle.grid: units can walk onto it (and get caught in the blast). Its tiles are shown as warning
## tiles until it goes off; then every unit and remains on them is hit. Killing another exploding enemy lights
## that one's fuse too, so explosions chain.

signal exploded(fuse: Fuse)

## Blinks between these tints while lit.
const BLINK_COLOR := Color(1.0, 0.35, 0.25, 1.0)
const BLINK_TIME := 0.15

var warning_tile_scene : PackedScene = preload("res://Battle/System/Warning Tile/warning_tile.tscn")

## Enemy id it came from (folder in Battle/Entities/Enemies).
var enemy_id: String
var tiles: Array[Vector2i] = []
var damage: int
var friendly_fire: bool = true
## Battle.turn on which it explodes (checked at the start of the enemies' turn).
var explode_turn: int

## Builds a lit fuse from a dying enemy: its tiles around the enemy's tile and facing, damage = dmg *
## explosion_damage_multiplier, and a copy of its Sprite playing "fuse" (or "idle" when it has no such animation).
static func from_enemy(enemy: Enemy, turn: int) -> Fuse:
	var fuse := Fuse.new()
	fuse.name = "%sFuse" % enemy.enemy_id
	fuse.unit_name = enemy.unit_name
	fuse.enemy_id = enemy.enemy_id
	fuse.facing = enemy.facing
	fuse.map_position = enemy.map_position
	fuse.crit_chance = 0.0
	fuse.explode_turn = turn
	fuse.tiles = TilePattern.to_tiles(enemy.get_explosion_offsets(), enemy.map_position, enemy.facing)
	fuse.damage = roundi(enemy.dmg * enemy.explosion_damage_multiplier)
	fuse.friendly_fire = enemy.explosion_friendly_fire
	var enemy_sprite: AnimatedSprite2D = enemy.get_node("Sprite")
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = enemy_sprite.sprite_frames
	sprite.position = enemy_sprite.position
	sprite.offset = enemy_sprite.offset
	sprite.scale = enemy_sprite.scale
	sprite.centered = enemy_sprite.centered
	sprite.flip_h = enemy.facing == Unit.facing_direction.LEFT
	if sprite.sprite_frames:
		sprite.animation = "fuse" if sprite.sprite_frames.has_animation("fuse") else "idle"
	fuse.add_child(sprite)
	return fuse

func _ready() -> void:
	current_hp = max_hp
	# Only the body blinks, not the warning tiles added below.
	for child in get_children():
		if child is AnimatedSprite2D:
			child.play()
			var blink := create_tween().set_loops()
			blink.tween_property(child, "modulate", BLINK_COLOR, BLINK_TIME)
			blink.tween_property(child, "modulate", Color.WHITE, BLINK_TIME)
	_place_warning_tiles()

## Called by Battle at the start of every enemies' turn; explodes once explode_turn comes.
func tick(turn: int) -> void:
	if turn >= explode_turn:
		explode()

func explode() -> void:
	if is_queued_for_deletion():
		return
	var attack := Attack.new(self, tiles, damage)
	attack.hits_allies = friendly_fire
	# A blast has no back to hit.
	attack.backstab_multiplier = 1.0
	attack.is_explosion = true
	_attack_tiles.emit(attack)
	exploded.emit(self)
	queue_free()

# Fuses can't be hurt; the blast that lit it is already over.
func _take_damage(_hit: Hit) -> void:
	pass

func _place_warning_tiles() -> void:
	for tile in tiles:
		if manager and not manager._is_in_bounds(tile):
			continue
		var warning: Node2D = warning_tile_scene.instantiate()
		add_child(warning)
		warning.global_position = Enemy.WARNING_TILE_POSITION_ZERO + Vector2(tile.x * 46 - tile.y * 32, tile.y * 32)
