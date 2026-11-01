class_name Enemy
extends Unit


@export var warning_tile : PackedScene = preload("res://Battle/System/Warning Tile/warning_tile.tscn")
@export var health_bar: ProgressBar
@export var damage_number_scene : PackedScene = preload("res://Battle/System/Damage Number/damage_number.tscn")
## Where the damage number spawns, relative to the enemy's position.
@export var damage_number_offset : Vector2 = Vector2(0, 8)
@onready var sprite : AnimatedSprite2D = $Sprite
const WARNING_TILE_POSITION_ZERO = Vector2(200,220)

var warning_tiles : Array

signal enemy_died(enemy: Enemy)
## HP went up or down (damage, heal, death). The boss bar listens to it.
signal hp_changed(current_hp: int, max_hp: int)
signal _enemy_updated_position(enemy: Enemy, from_map_position: Vector2i, to_map_position: Vector2i)

var about_to_attack : bool = false
var turnsUntilAttack: int = 0

## AI behavior file (Battle/AI/<Id>/<id>.json, drag it here) used when the encounter doesn't pick one.
## Empty = the enemy's own script decides (_decide_next_action).
@export var default_ai: JSON
## Data-driven AI made in the editor. Set by Battle from the encounter's "ai", else from default_ai; null = own script.
var ai: AIBehavior

## Gets the big health bar at the top of the screen (BossBar) instead of the one over its head.
## Only the first boss in a battle gets it; any others keep their own bar.
@export var is_boss: bool = false

@export_group("Death")
## Enemy id (folder in Battle/Entities/Enemies) that falls out next to it when it dies, e.g. "Wisp". Empty = nothing.
@export var death_spawn_id: String = ""
## Crumbles into pixels when it dies (PixelDissolve). Never for exploding enemies: their body stays as a Fuse.
@export var dissolves_on_death: bool = true
## Color its pixels fade toward while they fly off.
@export var dissolve_color: Color = Color(1, 1, 1, 1)
## Leaves its body (Remains) on its tile when it dies. Any enemy with the AI action "possess" can revive it.
@export var leaves_remains: bool = false
## HP of the body; the player can destroy it so it can't be revived. 0 = indestructible.
@export var remains_hp: int = 0
## Look of the body; empty = the first "idle" frame of the Sprite.
@export var remains_texture: Texture2D
## Tint of the body, so it reads as lifeless.
@export var remains_modulate: Color = Color(0.5, 0.5, 0.6, 1.0)
@export_group("Explosion")
## Tiles blown up when it dies (any death: killed, by another explosion, or the AI action "self_destruct").
## A tile pattern preset name like skills use (Battle/Skills/tile_patterns.json), e.g. "explosion". Empty = no explosion.
## The body stays as a lit Fuse with the tiles shown as warnings, so the player can step away.
@export var explosion_tiles: String = ""
## Explosion damage = dmg * this.
@export var explosion_damage_multiplier: float = 1.0
## Player actions the player gets to escape before it goes off (counted from the next one after the death).
@export_range(0, 10) var explosion_delay: int = 1
## Also hurts enemies (and their remains). A killed enemy with explosion_tiles explodes too: chain reaction.
@export var explosion_friendly_fire: bool = true
## Blasts of exploding enemies (Fuses, its own kind included) heal it by their damage instead of hurting it.
@export var heals_from_explosions: bool = false
@export_group("")

## Id (folder name) this enemy was spawned from and the encounter's AI override; set by Battle.spawn_enemy.
var enemy_id: String
var ai_id: String
var _missing_animations: Array[String] = []
# Set by play_animation_until_arrival: go back to idle once the move animation reaches destination.
var _idle_on_arrival: bool = false
# move_speed to restore on arrival after set_move_speed_until_arrival; negative = nothing to restore.
var _normal_move_speed: float = -1.0
# Hits waiting for the move animation, in path order: {"at": Vector2, "hit": Callable}.
var _contact_hits: Array[Dictionary] = []
# Parsed explosion_tiles, filled on first use.
var _explosion_offsets: Array[Vector2i] = []
# Sprite height above the ground while hopping (play_hop); the Sprite's own position.y is the ground.
var _sprite_ground_y: float = 0.0
var _hop: Tween

func _ready() -> void:
	sprite.play("idle")
	sprite.flip_h = facing
	_sprite_ground_y = sprite.position.y
	current_hp = max_hp
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current_hp
	if ai == null and default_ai:
		ai = AIBehavior.from_json(default_ai)
	sprite.animation_finished.connect(_on_sprite_animation_finished)

## Plays an animation from the Sprite's SpriteFrames (used by the AI's "animation" fields).
## Empty or missing name = "idle"; missing names are reported once per enemy.
func play_animation(animation_name: String) -> void:
	if animation_name.is_empty():
		animation_name = "idle"
	if not sprite.sprite_frames or not sprite.sprite_frames.has_animation(animation_name):
		if animation_name not in _missing_animations:
			_missing_animations.append(animation_name)
			push_warning("%s: no animation '%s' in its Sprite's SpriteFrames, playing idle" % [name, animation_name])
		animation_name = "idle"
	if sprite.animation != animation_name or not sprite.is_playing():
		sprite.play(animation_name)

## Runs hit once the sprite reaches at on its current straight move (e.g. a charge hitting what's in front).
## If at is the current position, it runs on the next frame.
func add_contact_hit(at: Vector2, hit: Callable) -> void:
	_contact_hits.append({"at": at, "hit": hit})

## Plays an animation while the enemy moves (e.g. a charge) and returns to idle when it arrives.
func play_animation_until_arrival(animation_name: String) -> void:
	play_animation(animation_name)
	_idle_on_arrival = true

# A hit point is reached once the sprite is no farther from destination than it (moves are straight lines).
func _run_contact_hits() -> void:
	while not _contact_hits.is_empty() and not is_queued_for_deletion():
		var next: Dictionary = _contact_hits.front()
		if position.distance_to(destination) > next.at.distance_to(destination) + 0.5:
			return
		_contact_hits.pop_front()
		next.hit.call()

# One-shot (non-looping) animations return to idle when they end.
func _on_sprite_animation_finished() -> void:
	sprite.play("idle")

## The enemy's turn; Battle calls it every time the player acts.
func take_turn(astar: AStarGrid2D, player_map_position: Vector2i) -> void:
	if ai:
		ai.take_turn(self, astar)
	else:
		_decide_next_action(astar, player_map_position)

func set_facing(new_facing: facing_direction) -> void:
	facing = new_facing
	sprite.flip_h = facing

## Heals up to max_hp and shows the amount. Returns how much was actually healed.
func heal(amount: int) -> int:
	var healed := clampi(amount, 0, max_hp - current_hp)
	current_hp += healed
	if health_bar:
		health_bar.value = current_hp
	hp_changed.emit(current_hp, max_hp)
	if healed > 0:
		_spawn_number(healed, false, true)
	return healed

## Arcs the Sprite up by height pixels and back down while the enemy moves to destination (a leap, or being thrown).
## Call after setting destination and move speed: the arc lasts as long as the move.
func play_hop(height: float) -> void:
	_stop_hop()
	var gap := (destination - position).abs()
	var time := maxf(gap.x, gap.y) / maxf(move_speed, 1.0)
	if time <= 0.0 or height <= 0.0:
		return
	_hop = create_tween()
	_hop.tween_property(sprite, "position:y", _sprite_ground_y - height, time / 2) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop.tween_property(sprite, "position:y", _sprite_ground_y, time / 2) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _stop_hop() -> void:
	if _hop:
		_hop.kill()
		_hop = null
		sprite.position.y = _sprite_ground_y

func _process(delta: float) -> void:
	if position != destination:
		_move_toward_destination(delta)
	_run_contact_hits()
	if position == destination:
		_on_arrived()

## Ends the current move animation at once and lands its queued hits.
## Battle calls it before the player acts, so an unfinished charge can't be dodged by moving mid-run.
func finish_animations() -> void:
	_stop_hop()
	position = destination
	_run_contact_hits()
	_on_arrived()

## Moves at speed until the current move ends (e.g. a charge), then goes back to move_speed.
func set_move_speed_until_arrival(speed: float) -> void:
	if _normal_move_speed < 0.0:
		_normal_move_speed = move_speed
	move_speed = speed

func _on_arrived() -> void:
	if _normal_move_speed >= 0.0:
		move_speed = _normal_move_speed
		_normal_move_speed = -1.0
	if _idle_on_arrival:
		_idle_on_arrival = false
		play_animation("")

func _take_damage(hit: Hit) -> void:
	if hit.is_explosion and heals_from_explosions:
		heal(hit.damage)
		return
	current_hp = max(current_hp - hit.damage, 0)
	if health_bar:
		health_bar.value = current_hp
	hp_changed.emit(current_hp, max_hp)
	_spawn_number(hit.damage, hit.is_critical)
	if !current_hp:
		die()

## Removes the enemy from the battle; Battle handles what it leaves behind (remains, death spawn, explosion).
func die() -> void:
	if is_queued_for_deletion():
		return
	current_hp = 0
	if health_bar:
		health_bar.value = 0
	hp_changed.emit(current_hp, max_hp)
	enemy_died.emit(self)
	queue_free()

## True if the enemy blows up when it dies (explosion_tiles set).
func explodes() -> bool:
	return not get_explosion_offsets().is_empty()

## explosion_tiles as offsets (see TilePattern); empty = no explosion.
func get_explosion_offsets() -> Array[Vector2i]:
	if _explosion_offsets.is_empty() and not explosion_tiles.is_empty():
		_explosion_offsets = TilePattern.parse(explosion_tiles)
	return _explosion_offsets

# The number is added to the parent (Battle) so it doesn't disappear along with a killed enemy.
func _spawn_number(amount: int, is_critical: bool, is_heal: bool = false) -> void:
	if !damage_number_scene or !get_parent():
		return
	var number : DamageNumber = damage_number_scene.instantiate()
	get_parent().add_child(number)
	number.play(amount, _damage_number_direction(), global_position + damage_number_offset, is_critical, is_heal)

# The number flies away from the player, like knockback from the hit.
func _damage_number_direction() -> int:
	if manager and manager.player:
		var dx : int = map_position.x - manager.player.map_position.x
		if dx != 0:
			return signi(dx)
	return 1 if randf() < 0.5 else -1

func _decide_next_action(astar: AStarGrid2D, player_map_position : Vector2i) -> void:
	print(self.name + ": I don't have an AI ;P")

func _try_path_to(astar: AStarGrid2D, tile: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = astar.get_id_path(map_position, tile)
	return path

func _commit_move(path: Array[Vector2i]) -> void:
	var new_map_position := path[1]
	_update_facing(new_map_position)
	_enemy_updated_position.emit(self, map_position, new_map_position)
	map_position = new_map_position
	destination = manager.map_position_to_position(new_map_position)

func _update_facing(new_map_position: Vector2i):
	var direction = new_map_position-map_position
	if direction.x:
		facing = facing_direction.LEFT if direction.x == -1 else facing_direction.RIGHT
		sprite.flip_h = facing
	else:
		var player_map_position = manager.player.map_position
		var direction_to_player = clamp(player_map_position.x - new_map_position.x,-1,1)
		facing = facing_direction.LEFT if direction_to_player == -1 else facing_direction.RIGHT
		sprite.flip_h = facing

func _place_warning_tile(tiles: Array[Vector2i]) -> void:
	for tile in tiles:
		var warning_tile_instance = warning_tile.instantiate()
		warning_tiles.append(warning_tile_instance)
		add_child(warning_tile_instance)
		warning_tile_instance.global_position.x = WARNING_TILE_POSITION_ZERO.x + (tile.x * 46) - (tile.y * 32)
		warning_tile_instance.global_position.y = WARNING_TILE_POSITION_ZERO.y + (tile.y * 32)
	about_to_attack = true

func _remove_warning_tiles() -> void:
	for warning_tile in warning_tiles:
		warning_tile.queue_free()
	warning_tiles = []
