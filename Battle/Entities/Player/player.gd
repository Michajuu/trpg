class_name Player
extends Unit

signal hp_changed(current_hp: int, max_hp: int)
signal tempo_changed(tempo: int, level_progress: float)

const MAX_TEMPO_PERCENTAGE := 200
## Input actions that trigger skills, in loadout order (skills[0] -> first action, ...).
const SKILL_ACTIONS: Array[String] = ["first_skill", "secound_skill", "thrid_skill"]

## Skills the player brought into this battle; set by Battle via set_skills.
var skills: Array[Skill] = []

## Player HP is counted in half-hearts (max_hp 8 = 4 hearts), Zelda-style.
## Incoming damage is converted: every started damage_per_half_heart takes one half-heart,
## so enemy dmg stats stay in the same units as enemy HP (friendly fire keeps working).
@export var damage_per_half_heart: int = 10

## How many Tempo percent a single basic attack grants.
@export var tempo_per_attack: int = 5
## Cumulative Tempo % required to reach each successive level (ascending).
## Equal spacing = every level fills up equally fast.
## Number of elements = maximum Tempo level.
## Between the last threshold and MAX_TEMPO_PERCENTAGE there is a buffer: the bar keeps filling,
## the level no longer increases, and Tempo decay eats into the buffer first.
@export var tempo_thresholds: Array[int] = [20, 40, 60, 80, 100, 120, 140, 160, 180]
## How many seconds of inactivity between Tempo decay ticks.
@export var tempo_decay_interval: float = 0.5
## How many Tempo percent are lost every tempo_decay_interval.
@export var tempo_decay_amount: int = 1
## How much faster Tempo decays per level (0.25 = +25% faster per level).
## 0 = decay is always the same speed.
@export var tempo_decay_speedup_per_level: float = 0.25
## How many seconds at the start of each player turn Tempo doesn't decay at all (reaction time).
## Tempo never decays during the enemies' turn.
@export var tempo_decay_grace_time: float = 0.4
## How much basic attack damage grows per Tempo level (0.1 = +10% dmg per level).
@export var tempo_damage_bonus_per_level: float = 0.1

# Time since the last action (move/attack) or the last decay tick.
var _tempo_decay_time: float = 0.0

var tempo_percentage: int = 0:
	set(value):
		tempo_percentage = clampi(value, 0, MAX_TEMPO_PERCENTAGE)
		tempo_changed.emit(tempo, tempo_level_progress)

## Full Tempo points: the number of tempo_thresholds the player has reached.
var tempo: int:
	get:
		var level := 0
		for threshold in tempo_thresholds:
			if tempo_percentage < threshold:
				break
			level += 1
		return level

## Progress (0.0–1.0) within the current Tempo level: from the current level's threshold to the next one.
## At max level it shows the buffer: from the last threshold to MAX_TEMPO_PERCENTAGE.
var tempo_level_progress: float:
	get:
		var level := tempo
		var start := 0 if level == 0 else tempo_thresholds[level - 1]
		var end := MAX_TEMPO_PERCENTAGE if level >= tempo_thresholds.size() else tempo_thresholds[level]
		if end <= start:
			return 1.0
		return float(tempo_percentage - start) / float(end - start)

@onready var sprite : AnimatedSprite2D = $Sprite
@onready var AttackCooldownTimer : Timer = $AttackCooldown

func _ready() -> void:
	current_hp = max_hp
	hp_changed.emit(current_hp, max_hp)
	sprite.play("idle")
	sprite.flip_h = facing
	if manager:
		manager.player_turn_started.connect(_reset_tempo_decay)

func _process(delta: float) -> void:
	# The clock only runs on the player's turn: the faster they act, the less Tempo they lose.
	var my_turn := manager.is_player_turn()
	if my_turn:
		_update_tempo_decay(delta)
	#Change sprite rotation according to direction
	sprite.flip_h = facing
	#Movement
	if !sprite.is_playing():
		sprite.play("idle")
	elif position != destination:
		_move_toward_destination(delta)
	elif not my_turn:
		pass
	elif Input.is_action_just_pressed("ui_right"):
		var new_map_position = Vector2i(map_position.x + 1, map_position.y)
		var new_position = Vector2(position.x+46, position.y)
		_move(new_map_position,new_position,facing_direction.RIGHT)
	elif Input.is_action_just_pressed("ui_left"):
		var new_map_position = Vector2i(map_position.x - 1, map_position.y)
		var new_position = Vector2(position.x-46, position.y)
		_move(new_map_position,new_position,facing_direction.LEFT)
	elif Input.is_action_just_pressed("ui_up"):
		var new_map_position = Vector2i(map_position.x, map_position.y - 1)
		var new_position = Vector2(position.x+32, position.y-32)
		_move(new_map_position,new_position)
	elif Input.is_action_just_pressed("ui_down"):
		var new_map_position = Vector2i(map_position.x, map_position.y + 1)
		var new_position = Vector2(position.x-32, position.y+32)
		_move(new_map_position,new_position)
	#Attacking (re-checked: a move or turn this frame has already ended the turn)
	if not manager.is_player_turn() or position != destination:
		return
	if Input.is_action_just_pressed("basic_attack") and AttackCooldownTimer.is_stopped():
		manager.finish_enemy_animations()
		var tile : Array[Vector2i] = [Vector2i(map_position.x+1*(-1 if facing else 1),map_position.y)]
		AttackCooldownTimer.start()
		_reset_tempo_decay()
		sprite.play("attack")
		# Tempo is granted only for hitting an enemy (not empty air or an obstacle).
		# Checked before emit, because the enemy may die from this hit.
		var hit_enemy: bool = manager._has_enemy_in(tile)
		_attack_tiles.emit(Attack.new(self, tile, get_basic_attack_damage()))
		if hit_enemy:
			add_tempo_percentage(tempo_per_attack)
		manager.end_player_turn()
		return
	#Skills
	for i in mini(skills.size(), SKILL_ACTIONS.size()):
		if Input.is_action_just_pressed(SKILL_ACTIONS[i]):
			_use_skill(skills[i])
			return

func set_skills(new_skills: Array[Skill]) -> void:
	skills = new_skills
	for skill in skills:
		skill.user = self

## Using a skill counts as an action: ends the player's turn.
func _use_skill(skill: Skill) -> void:
	manager.finish_enemy_animations()
	if not skill.use():
		return
	_reset_tempo_decay()
	manager.end_player_turn()

## True while the player's action is still playing out (move or attack animation). Battle waits for it
## before the enemies act.
func is_busy() -> bool:
	return position != destination or (sprite.is_playing() and sprite.animation == &"attack")

## new_facing is applied only if the move succeeds. A move blocked by an enemy behind the player turns them
## toward it instead (costs an action); any other blocked move changes nothing.
func _move(new_map_position : Vector2i, new_position : Vector2, new_facing : facing_direction = facing):
	manager.finish_enemy_animations()
	var old_facing := facing
	facing = new_facing
	if manager._can_move(self, map_position, new_map_position):
		manager.astar.set_point_weight_scale(map_position, 1.0)
		manager.astar.set_point_weight_scale(new_map_position, 5.0)
		map_position = new_map_position
		destination = new_position
		_reset_tempo_decay()
		manager.end_player_turn()
	elif new_facing != old_facing and manager._has_enemy_in([new_map_position] as Array[Vector2i]):
		# Turning toward the enemy costs as much as a move: it ends the turn.
		_reset_tempo_decay()
		manager.end_player_turn()
	else:
		facing = old_facing

## Basic attack damage: dmg scaled by the current Tempo level.
func get_basic_attack_damage() -> int:
	return roundi(dmg * (1.0 + tempo * tempo_damage_bonus_per_level))

func add_tempo_percentage(amount: int) -> void:
	tempo_percentage += amount

## While the player is idle, loses tempo_decay_amount % every _current_decay_interval().
func _update_tempo_decay(delta: float) -> void:
	if tempo_percentage <= 0 or tempo_decay_interval <= 0.0:
		_tempo_decay_time = 0.0
		return
	_tempo_decay_time += delta
	# Interval is recalculated every tick, because dropping a level slows further decay.
	var interval := _current_decay_interval()
	while tempo_percentage > 0 and _tempo_decay_time >= interval:
		_tempo_decay_time -= interval
		add_tempo_percentage(-tempo_decay_amount)
		interval = _current_decay_interval()

## The higher the Tempo level, the shorter the interval between decay ticks.
func _current_decay_interval() -> float:
	return tempo_decay_interval / (1.0 + tempo * maxf(tempo_decay_speedup_per_level, 0.0))

## Every player action and the start of every player turn restarts the countdown.
## Starting from a negative value = grace time before the first decay tick happens.
func _reset_tempo_decay() -> void:
	_tempo_decay_time = -maxf(tempo_decay_grace_time, 0.0)

## Spends full Tempo points (e.g. on a skill). Returns false if there aren't enough.
## The percentage drops to the new level's threshold; progress above it is lost.
func spend_tempo(amount: int) -> bool:
	if tempo < amount:
		return false
	var new_level := tempo - amount
	tempo_percentage = 0 if new_level <= 0 else tempo_thresholds[new_level - 1]
	return true

## Converts raw damage into half-hearts, rounding up: any hit that deals damage costs at least half a heart.
func damage_to_half_hearts(damage: int) -> int:
	if damage <= 0:
		return 0
	return ceili(float(damage) / maxi(damage_per_half_heart, 1))

func _take_damage(hit: Hit) -> void:
	current_hp = max(current_hp - damage_to_half_hearts(hit.damage), 0)
	hp_changed.emit(current_hp, max_hp)
