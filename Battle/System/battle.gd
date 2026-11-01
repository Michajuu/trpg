class_name Battle_Manager
extends Control

@export var encounter_json: JSON
@export var heart_bar: HeartBar
@export var tempo_bar: TempoBar
## Container that gets one skill slot per skill in skill_loadout.
@export var skill_bar: Container
## Ids of the skills the player brings into this battle (folder names in Battle/Skills).
## Set it before adding Battle to the tree, e.g. from the pre-battle skill selection.
@export var skill_loadout: Array[String] = ["Dash", "Bash", "Spin"]

var player : Player

var player_scene = preload("res://Battle/Entities/Player/player.tscn")
var skill_slot_scene = preload("res://Battle/System/Skills/skill.tscn")

const POSITION_ZERO = Vector2(200,190)

var grid = [
	[null,null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null,null],
	[null,null,null,null,null,null,null,null,null]
]

var astar = AStarGrid2D.new()

var enemies : Array[Enemy]
## Bodies of dead enemies that can be revived (Enemy.leaves_remains). Not in grid: units can stand on them.
var remains : Array[Remains]
## Bodies of exploding enemies waiting to go off (Enemy.explosion_tiles). Not in grid either.
var fuses : Array[Fuse]
## Enemies' turns started so far; fuses count their delay in these.
var turn: int = 0
var _enemy_turn_running: bool = false

const NO_TILE := Vector2i(-1, -1)

var map_size = Vector2i(8,4)

func _ready() -> void:
	astar.region = Rect2i(0, 0, map_size.x+1, map_size.y+1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	var encounter_data = EncounterData.from_dict(encounter_json.data)
	var player_instance : Player = player_scene.instantiate()
	# Setting player position on grid
	player_instance.position.x = POSITION_ZERO.x + (encounter_data.player_spawn.x * 46) - (encounter_data.player_spawn.y * 32)
	player_instance.position.y = POSITION_ZERO.y + (encounter_data.player_spawn.y * 32)
	player_instance.destination = player_instance.position
	# Setting map position for movement
	player_instance.map_position = Vector2i(encounter_data.player_spawn.x, encounter_data.player_spawn.y)
	player_instance.facing = encounter_data.player_facing
	# Setting player position on matrix
	grid[encounter_data.player_spawn.y][encounter_data.player_spawn.x] = player_instance
	# Connecting signals
	player_instance._attack_tiles.connect(_on_attack_tiles)
	if heart_bar:
		player_instance.hp_changed.connect(heart_bar.update_hp)
	if tempo_bar:
		player_instance.tempo_changed.connect(tempo_bar.update_tempo)
		tempo_bar.update_tempo(player_instance.tempo, player_instance.tempo_level_progress)
	_setup_skills(player_instance)
	# Setting refrence to parent
	player_instance.manager = self
	
	player = player_instance
	add_child(player_instance)
	
	for enemy : UnitData in encounter_data.enemies:
		spawn_enemy(enemy.id, enemy.position, enemy.facing, enemy.ai)
	for body : UnitData in encounter_data.remains:
		spawn_remains(body.id, body.position, body.facing, body.ai)

	for obstacle : UnitData in encounter_data.obstacles:
		var obstacle_scene = load("res://Battle/Entities/Obstacles/%s/%s.tscn" % [obstacle.id, obstacle.id])
		var obstacle_instance = obstacle_scene.instantiate()
		obstacle_instance.position = map_position_to_position(obstacle.position)
		grid[obstacle.position.y][obstacle.position.x] = obstacle_instance
		astar.set_point_solid(obstacle.position, true)
		add_child(obstacle_instance)

## Adds an enemy (folder name in Battle/Entities/Enemies) on a free tile. Works mid-battle too (death spawns,
## revives); an enemy added during the enemies' turn acts from the next one. ai_id: AI override, empty = default_ai.
func spawn_enemy(id: String, tile: Vector2i, facing: Unit.facing_direction, ai_id: String = "") -> Enemy:
	var scene_path := "res://Battle/Entities/Enemies/%s/%s.tscn" % [id, id]
	if not ResourceLoader.exists(scene_path):
		push_error("Enemy '%s': missing %s" % [id, scene_path])
		return null
	var enemy_instance : Enemy = load(scene_path).instantiate()
	enemy_instance.enemy_id = id
	enemy_instance.ai_id = ai_id
	enemy_instance.position = map_position_to_position(tile)
	enemy_instance.destination = enemy_instance.position
	# Setting map position for movement
	enemy_instance.map_position = tile
	enemy_instance.facing = facing
	# AI picked in the encounter; without one the enemy uses its default_ai or own script
	if not ai_id.is_empty():
		enemy_instance.ai = AIBehavior.load_behavior(ai_id)
	grid[tile.y][tile.x] = enemy_instance
	enemies.append(enemy_instance)
	enemy_instance._enemy_updated_position.connect(_on_enemy_update_position)
	enemy_instance._attack_tiles.connect(_on_attack_tiles)
	enemy_instance.enemy_died.connect(_on_enemy_death)
	enemy_instance.manager = self
	add_child(enemy_instance)
	return enemy_instance

## Brings remains back as their enemy with full HP. The possessor (e.g. a Wisp) merges into it and disappears.
func revive_remains(target: Remains, possessor: Enemy) -> Enemy:
	_remove_enemy(possessor)
	remains.erase(target)
	target.queue_free()
	return spawn_enemy(target.enemy_id, target.map_position, possessor.facing, target.ai_id)

## Places an empty body of enemy id on tile (encounter "remains"), as if it had died there.
## Any enemy with the AI action "possess" can bring it to life.
func spawn_remains(id: String, tile: Vector2i, facing: Unit.facing_direction, ai_id: String = "") -> Remains:
	var scene_path := "res://Battle/Entities/Enemies/%s/%s.tscn" % [id, id]
	if not ResourceLoader.exists(scene_path):
		push_error("Remains '%s': missing %s" % [id, scene_path])
		return null
	# Never added to the tree: only read for its look and remains settings.
	var template : Enemy = load(scene_path).instantiate()
	template.enemy_id = id
	template.ai_id = ai_id
	template.map_position = tile
	template.facing = facing
	var body := _add_remains(template)
	template.free()
	return body

func _add_remains(enemy: Enemy) -> Remains:
	var body := Remains.from_enemy(enemy)
	body.position = map_position_to_position(body.map_position)
	body.manager = self
	body.destroyed.connect(_on_remains_destroyed)
	remains.append(body)
	add_child(body)
	return body

func _on_remains_destroyed(body: Remains) -> void:
	remains.erase(body)

## Remains lying on tile, or null.
func remains_at(tile: Vector2i) -> Remains:
	for body in remains:
		if body.map_position == tile:
			return body
	return null

## Loads the skills from skill_loadout, gives them to the player and builds their slots.
func _setup_skills(player_instance: Player) -> void:
	var skills: Array[Skill] = []
	for id in skill_loadout:
		var skill := Skill.load_skill(id)
		if skill:
			skills.append(skill)
	if skills.size() > Player.SKILL_ACTIONS.size():
		push_warning("Loadout has %d skills, but only %d skill keys exist" % [skills.size(), Player.SKILL_ACTIONS.size()])
	player_instance.set_skills(skills)
	if not skill_bar:
		return
	for skill in skills:
		var slot : SkillSlot = skill_slot_scene.instantiate()
		skill_bar.add_child(slot)
		slot.skill = skill
		player_instance.tempo_changed.connect(slot.update_tempo)
		slot.update_tempo(player_instance.tempo, player_instance.tempo_level_progress)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

func _move_enemies() -> void:
	turn += 1
	_enemy_turn_running = true
	# Fuses go off first, like telegraphed attacks landing. Copy: a blast can light new fuses (chain reaction);
	# those wait for the next turn.
	for fuse : Fuse in fuses.duplicate():
		if is_instance_valid(fuse) and not fuse.is_queued_for_deletion():
			fuse.tick(turn)
	# Copy: an enemy can die during the loop (e.g. friendly fire), which erases it from enemies.
	for enemy : Enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.take_turn(astar, player.map_position)
	_enemy_turn_running = false

## Snaps every enemy to the end of its move, landing queued hits (e.g. a charge) before the player's
## next action changes the grid. The player calls it at the start of every action.
func finish_enemy_animations() -> void:
	# Copy: a landed hit can kill an enemy, which erases it from enemies.
	for enemy : Enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.finish_animations()

func _can_move(unit: Unit ,from_map_position: Vector2i,to_map_position: Vector2i) -> bool:
	if to_map_position.x <= map_size.x and to_map_position.y <= map_size.y and to_map_position.x != -1 and to_map_position.y != -1:
		if !grid[to_map_position.y][to_map_position.x]:
			grid[from_map_position.y][from_map_position.x] = null
			grid[to_map_position.y][to_map_position.x] = unit
			if unit is Player:
				_move_enemies()
			return true
	return false

func _on_attack_tiles(attack: Attack) -> void:
	for tile in attack.tiles:
		if _is_in_bounds(tile):
			var unit = grid[tile.y][tile.x]
			# Patterns may include the attacker's own tile; never hit yourself.
			if unit is Unit and unit != attack.attacker:
				if not attack.hits_allies and unit is Enemy and attack.attacker is Enemy:
					continue
				unit._take_damage(attack.resolve_against(unit))
			# Attacks that can hurt enemies also hit the remains lying on the tile (even under a unit).
			var body := remains_at(tile)
			if body and body.is_destructible() and (attack.attacker is Player or attack.hits_allies):
				body._take_damage(attack.resolve_against(body))

func _on_enemy_death(enemy: Enemy):
	_remove_enemy(enemy)
	if enemy.leaves_remains:
		_add_remains(enemy)
	if enemy.explodes():
		light_fuse(enemy)
	if not enemy.death_spawn_id.is_empty():
		# Deferred: the attack that killed it is still resolving and would hit the newcomer too.
		# It also lets the newcomer sit out the enemies' turn that follows the killing blow.
		_spawn_from_death.call_deferred(enemy.death_spawn_id, enemy.map_position, enemy.facing, enemy.position)

## Leaves a lit Fuse on the enemy's tile; it explodes after the player has taken explosion_delay more actions.
## Lit during the player's action, the enemies' turn that follows that action doesn't count yet.
func light_fuse(enemy: Enemy) -> Fuse:
	var explode_turn := turn + enemy.explosion_delay + (0 if _enemy_turn_running else 1)
	var fuse := Fuse.from_enemy(enemy, explode_turn)
	fuse.position = map_position_to_position(fuse.map_position)
	fuse.manager = self
	fuse._attack_tiles.connect(_on_attack_tiles)
	fuse.exploded.connect(func(f: Fuse) -> void: fuses.erase(f))
	fuses.append(fuse)
	add_child(fuse)
	return fuse

func _remove_enemy(enemy: Enemy) -> void:
	if grid[enemy.map_position.y][enemy.map_position.x] == enemy:
		grid[enemy.map_position.y][enemy.map_position.x] = null
	enemies.erase(enemy)
	enemy.queue_free()

# The spawned enemy falls out of the dead one: it starts at its body and slides to a free neighbour tile.
func _spawn_from_death(id: String, tile: Vector2i, facing: Unit.facing_direction, from_position: Vector2) -> void:
	var landing := _death_spawn_tile(tile)
	if landing == NO_TILE:
		push_warning("No free tile around %s to spawn '%s'" % [tile, id])
		return
	var spawned := spawn_enemy(id, landing, facing)
	if spawned:
		spawned.position = from_position

# Free neighbour tile farthest from the player, else the dead enemy's own tile, else NO_TILE.
func _death_spawn_tile(tile: Vector2i) -> Vector2i:
	var best := NO_TILE
	for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var candidate: Vector2i = tile + step
		if _is_free_tile(candidate) and (best == NO_TILE or _player_distance(candidate) > _player_distance(best)):
			best = candidate
	if best == NO_TILE and _is_free_tile(tile):
		best = tile
	return best

func _is_free_tile(tile: Vector2i) -> bool:
	return _is_in_bounds(tile) and grid[tile.y][tile.x] == null and not astar.is_point_solid(tile)

func _player_distance(tile: Vector2i) -> int:
	return absi(tile.x - player.map_position.x) + absi(tile.y - player.map_position.y)

func _is_player_there(tiles: Array[Vector2i]) -> bool:
	for tile in tiles:
		if tile.x <= map_size.x:
			if grid[tile.y][tile.x] is Player:
				return true
	return false

func _is_in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.y >= 0 and tile.x <= map_size.x and tile.y <= map_size.y

func _has_enemy_in(tiles: Array[Vector2i]) -> bool:
	for tile in tiles:
		if _is_in_bounds(tile) and grid[tile.y][tile.x] is Enemy:
			return true
	return false

func _on_enemy_update_position(unit: Unit, from_map_position: Vector2i, to_map_position: Vector2i) -> void:
	grid[from_map_position.y][from_map_position.x] = null
	grid[to_map_position.y][to_map_position.x] = unit

func map_position_to_position(map_position: Vector2i) -> Vector2:
	var position = Vector2(0,0)
	position.x = POSITION_ZERO.x + (map_position.x * 46) - (map_position.y * 32)
	position.y = POSITION_ZERO.y + (map_position.y * 32)
	
	return position

func print_astar_grid(astar: AStarGrid2D, path: Array[Vector2i] = []) -> void:
	var region := astar.region  
	for y in range(region.position.y, region.end.y):
		var row := ""
		for x in range(region.position.x, region.end.x):
			var cell := Vector2i(x, y)
			if astar.is_point_solid(cell):
				row += " ## "
			elif cell in path:
				row += " ** "
			else:
				row += "%4.1f" % astar.get_point_weight_scale(cell)
			row += " "
		print(row)
	print("")   # blank line between prints

func _print_grid() -> void:
	for row in grid:
		print(row)
	print("-----------------")
