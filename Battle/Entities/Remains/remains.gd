class_name Remains
extends Unit

## Body a dead enemy leaves on its tile (Enemy.leaves_remains). It isn't in Battle.grid: units can stand on it.
## Any enemy using the AI action "possess" (e.g. a Wisp) can stand on it to bring the enemy back (Battle.revive_remains).
## With Enemy.remains_hp > 0 it can be destroyed: attacks that hurt enemies also hit the remains on their tiles.

signal destroyed(remains: Remains)

var damage_number_scene : PackedScene = preload("res://Battle/System/Damage Number/damage_number.tscn")

## Enemy id to revive and the AI override it had (empty = its default_ai).
var enemy_id: String
var ai_id: String
var health_bar: ProgressBar

## Builds the body from a dying enemy: remains_texture (or its first idle frame) tinted with remains_modulate,
## with remains_hp HP and a copy of the enemy's health bar.
static func from_enemy(enemy: Enemy) -> Remains:
	var remains := Remains.new()
	remains.name = "%sRemains" % enemy.enemy_id
	remains.unit_name = "%s Remains" % enemy.unit_name
	remains.enemy_id = enemy.enemy_id
	remains.ai_id = enemy.ai_id
	remains.facing = enemy.facing
	remains.max_hp = maxi(enemy.remains_hp, 0)
	remains.crit_chance = 0.0
	remains.map_position = enemy.map_position
	# Drawn on the floor of its row: right below the units standing there (map_position sets the unit depth).
	remains.z_as_relative = false
	remains.z_index = Unit.depth_z_index(enemy.map_position.y) - 1
	# Also works on an enemy that was never added to the tree (encounter remains), so no @onready vars.
	var enemy_sprite: AnimatedSprite2D = enemy.get_node("Sprite")
	var sprite := Sprite2D.new()
	sprite.texture = enemy.remains_texture
	var frames := enemy_sprite.sprite_frames
	if sprite.texture == null and frames and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		sprite.texture = frames.get_frame_texture("idle", 0)
	sprite.position = enemy_sprite.position
	sprite.offset = enemy_sprite.offset
	sprite.centered = enemy_sprite.centered
	sprite.flip_h = enemy.facing == Unit.facing_direction.LEFT
	sprite.modulate = enemy.remains_modulate
	remains.add_child(sprite)
	var enemy_bar: ProgressBar = enemy.health_bar if enemy.health_bar else enemy.get_node_or_null("HealthBar")
	if remains.is_destructible() and enemy_bar:
		remains.health_bar = enemy_bar.duplicate()
		remains.health_bar.max_value = remains.max_hp
		remains.health_bar.value = remains.max_hp
		remains.add_child(remains.health_bar)
	return remains

## False = remains_hp was 0: nothing can destroy it.
func is_destructible() -> bool:
	return max_hp > 0

func _take_damage(hit: Hit) -> void:
	if not is_destructible() or current_hp <= 0:
		return
	current_hp = maxi(current_hp - hit.damage, 0)
	if health_bar:
		health_bar.value = current_hp
	_spawn_damage_number(hit)
	if current_hp == 0:
		destroyed.emit(self)
		queue_free()

# Added to the parent (Battle), so it outlives the destroyed body; flies away from the player like on enemies.
func _spawn_damage_number(hit: Hit) -> void:
	if not damage_number_scene or not get_parent():
		return
	var direction := 1 if randf() < 0.5 else -1
	if manager and manager.player and map_position.x != manager.player.map_position.x:
		direction = signi(map_position.x - manager.player.map_position.x)
	var number : DamageNumber = damage_number_scene.instantiate()
	get_parent().add_child(number)
	number.play(hit.damage, direction, global_position + Vector2(0, 8), hit.is_critical)
