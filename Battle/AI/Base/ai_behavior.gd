class_name AIBehavior
extends RefCounted

## Data-driven enemy AI, made in the editor (AI page).
## A behavior lives in its own folder: Battle/AI/<Id>/<id>.json
## Every enemy turn the rules are checked top to bottom. The first rule whose conditions all hold
## and whose action can actually be done (e.g. "attack" needs the player in its tiles) runs; the rest are skipped.
## No rule runs = the enemy waits.
##
## {
##   "id": "Brute", "name": "Brute", "description": "...",
##   "rules": [
##     {"conditions": [{"type": "hp_below", "percent": 30}], "action": {"type": "flee"}},
##     {"conditions": [], "action": {"type": "attack", "tiles": "in_front", "damage_multiplier": 1.0, "windup": 1}, "cooldown": 1},
##     {"conditions": [], "action": {"type": "approach"}}
##   ]
## }
##
## Conditions (all must hold; none = always):
##   hp_below / hp_above {percent}        enemy's own HP compared to max HP
##   player_within / player_farther_than {distance}   tiles to the player, no diagonals
##   player_behind {}                     player stands behind the enemy (it can be backstabbed)
##   chance {percent}                     random roll every turn
## Actions:
##   attack {tiles, damage_multiplier, windup, can_turn, needs_target, friendly_fire}
##     tiles: preset name or [[x, y], ...] like skills (see TilePattern). windup: turns the warning tiles
##     are shown before the hit (0 = hits at once). can_turn: may turn around to hit a player behind it.
##     needs_target: only attacks when the player is in the tiles. friendly_fire: also hurts other enemies.
##   charge {sight, damage_multiplier, windup, can_turn, friendly_fire, pierce, avoid_allies, speed}
##     Sees the player in its row (sight: max tiles, 0 = whole row; obstacles block the view, enemies don't),
##     winds up for windup turns with the lane shown as warning tiles, then rushes straight ahead to the first
##     wall (obstacle or map edge). The first unit in the lane stops it and takes the hit: the player, or another
##     enemy (hurt only with friendly_fire, default true). pierce (default false): run through enemies instead,
##     hitting each one, and stop only at the player or a wall. The direction is locked when the windup starts.
##     avoid_allies (default true): doesn't start a charge with another enemy between it and the player, and
##     approach looks for a clear lane instead; enemies are then hit only if they step in during the windup.
##     speed: run speed in pixels per second, only during the charge (default 2000; walking uses move_speed).
##     can_turn: also looks behind itself. Takes "windup_animation" like attack; "animation" plays while rushing.
##   approach {steps}   move toward a tile from which one of its attacks can hit the player (or a charge can see it)
##   flee {steps}       move away from the player
##   wander {}          step to a random free neighbour tile
##   face_player {}     turn toward the player
##   heal {percent}     heal % of max HP
##   wait {}            do nothing
##   possess {turns, steps}   walks to the nearest Remains (body of an enemy with leaves_remains, e.g. a Haunted Armor)
##     and after standing on it for turns of its own turns (default 2; turns spent attacking don't count, stepping off
##     resets them) disappears into it, bringing that enemy back with full HP. Can't be done without any Remains.
##   self_destruct {needs_target}   the enemy dies on the spot, leaving a lit Fuse that blows up its explosion tiles
##     (Enemy export group "Explosion") after explosion_delay turns. Needs explosion_tiles set on the enemy.
##     needs_target (default true): only when the player is within those tiles. approach walks to such a tile.
##   throw {enemy, count, distance, max_alive, speed, height}   throws count new enemies of id enemy (folder in
##     Battle/Entities/Enemies, e.g. "Bomboar") onto random free tiles at most distance tiles from the player
##     (default 2, never the player's own tile). They fly from the thrower in an arc (speed in pixels per second,
##     default 400; height in pixels, default 24) and act from the next turn. max_alive (default 0 = no limit):
##     never more than that many enemies of that id alive at once; count is cut down to fit. Fails with no free tile.
##   leap {distance, toward, tiles, damage_multiplier, windup, friendly_fire, speed, height}   jumps along its row
##     onto the farthest free tile up to distance tiles away (default 3), over obstacles and units, and on landing
##     hits tiles around itself (default "cross": left, right, up, down). toward: "far_wall" (default; the side edge
##     of the map farther from the player, fails once it stands there), "player" or "forward". windup (default 1):
##     turns the landing tile and the hit tiles are shown first; if the landing tile gets taken meanwhile, it lands
##     short of it. friendly_fire (default false) also hurts enemies. speed/height: like throw (default 300 / 24).
##     Takes "windup_animation" like attack; "animation" plays in the air.
## Every action also takes "animation": name of an animation in the enemy's Sprite (AnimatedSprite2D) to play
##   when the action runs; for attack it plays when the hit lands. Attack also takes "windup_animation", held
##   while the warning tiles are shown (e.g. a slime opening its mouth). Empty = "idle". A one-shot (non-looping)
##   animation goes back to "idle" when it ends; a missing one logs a warning and plays "idle".
## cooldown (per rule): after the rule runs it is skipped for that many turns.
## delay (per rule, default 0): turns the enemy takes to react before the action starts. The action has to be
##   possible for delay of its turns in a row first; on those turns the enemy only turns to face the player.
##   For attack, charge and self_destruct "possible" means the player is in reach; for other actions only the
##   conditions count. Stepping out of reach resets it. Turns on cooldown count too, so it doesn't add up with it.
## max_uses (per rule, default 0 = no limit): the rule runs at most that many times per enemy, e.g. 1 for a one-time
##   phase move at 50% HP. Counted per enemy, so a revived or newly spawned one starts again.

const BEHAVIORS_PATH := "res://Battle/AI/%s/%s.json"
const CONDITIONS: Array[String] = ["hp_below", "hp_above", "player_within", "player_farther_than", "player_behind", "chance"]
const ACTIONS: Array[String] = ["attack", "charge", "approach", "flee", "wander", "face_player", "heal", "wait", "possess", "self_destruct", "throw", "leap"]
const NEIGHBOURS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]

## Parsed rules per JSON file path, shared by every enemy using it (read-only after loading).
static var _cache: Dictionary = {}

## A rule ran this turn (index in rules). The boss bar uses it to show when a phase move fires.
signal rule_used(rule: int)

var id: String
var display_name: String
var rules: Array[Dictionary] = []

# Per-enemy state: every enemy gets its own AIBehavior instance.
var _cooldowns: Array[int] = []
# Times each rule has run (for max_uses).
var _uses: Array[int] = []
# Turns in a row each rule's action has been possible (for delay).
var _ready_turns: Array[int] = []
var _pending_tiles: Array[Vector2i] = []
var _pending_damage: int = 0
var _pending_friendly_fire: bool = false
var _pending_turns: int = 0
var _pending_animation: String = ""
# What the telegraphed action is: "attack", "charge" or "leap".
var _pending_kind: String = ""
var _pending_pierce: bool = false
var _pending_speed: float = 0.0
var _pending_action: Dictionary = {}
var _pending_landing: Vector2i
var _pending_direction: int = 0
# Turns spent possessing the Remains the enemy stands on.
var _possess_turns: int = 0

## Builds a behavior from its folder by id (the encounter's "ai"). Returns null (and logs an error) if it doesn't exist.
static func load_behavior(behavior_id: String) -> AIBehavior:
	var json_path := BEHAVIORS_PATH % [behavior_id, behavior_id.to_snake_case()]
	if not ResourceLoader.exists(json_path):
		push_error("AI '%s': missing %s" % [behavior_id, json_path])
		return null
	return from_json(load(json_path))

## Builds a behavior from a behavior .json (e.g. an enemy's default_ai). Returns null (and logs an error) if it's invalid.
## The id is the file's "id", or its folder name when that's missing.
static func from_json(json: JSON) -> AIBehavior:
	if json == null or not json.data is Dictionary:
		var source := "null" if json == null else (json.resource_path if not json.resource_path.is_empty() else "JSON made in code")
		push_error("AI: %s is not a valid behavior JSON object" % [source])
		return null
	var behavior_id := str(json.data.get("id", json.resource_path.get_base_dir().get_file()))
	var key := json.resource_path
	# JSON made in code has no path; parse it every time instead of caching.
	var data: Dictionary = _cache.get(key, {}) if not key.is_empty() else {}
	if data.is_empty():
		data = _parse(behavior_id, json.data)
		if not key.is_empty():
			_cache[key] = data
	var behavior := AIBehavior.new()
	behavior.id = behavior_id
	behavior.display_name = data.name
	behavior.rules = data.rules
	for i in behavior.rules.size():
		behavior._cooldowns.append(0)
		behavior._uses.append(0)
		behavior._ready_turns.append(0)
	return behavior

## Checks the rules once and drops broken ones, so mistakes are reported on load instead of every turn.
static func _parse(behavior_id: String, dict: Dictionary) -> Dictionary:
	var rules: Array[Dictionary] = []
	for raw in dict.get("rules", []):
		if not raw is Dictionary or not raw.get("action") is Dictionary:
			push_error("AI '%s': rule %s has no action" % [behavior_id, raw])
			continue
		var action: Dictionary = raw.action.duplicate()
		if str(action.get("type", "")) not in ACTIONS:
			push_error("AI '%s': unknown action '%s' (actions: %s)" % [behavior_id, action.get("type"), ACTIONS])
			continue
		if action.type == "attack":
			action.offsets = TilePattern.parse(action.get("tiles", "in_front"))
		elif action.type == "leap":
			action.offsets = TilePattern.parse(action.get("tiles", "cross"))
		var conditions: Array[Dictionary] = []
		var valid := true
		for condition in raw.get("conditions", []):
			if not condition is Dictionary or str(condition.get("type", "")) not in CONDITIONS:
				push_error("AI '%s': unknown condition %s (conditions: %s)" % [behavior_id, condition, CONDITIONS])
				valid = false
				break
			conditions.append(condition)
		if valid:
			rules.append({"conditions": conditions, "action": action, "cooldown": maxi(int(raw.get("cooldown", 0)), 0),
				"max_uses": maxi(int(raw.get("max_uses", 0)), 0), "delay": maxi(int(raw.get("delay", 0)), 0)})
	return {"name": str(dict.get("name", behavior_id)), "rules": rules}

## One enemy turn. Called by Enemy.take_turn every time the player acts.
func take_turn(enemy: Enemy, astar: AStarGrid2D) -> void:
	var used := _act(enemy, astar)
	for i in _cooldowns.size():
		_cooldowns[i] = maxi(_cooldowns[i] - 1, 0)
	if used >= 0:
		_cooldowns[used] = rules[used].cooldown
		_uses[used] += 1
		rule_used.emit(used)
	if enemy.manager.remains_at(enemy.map_position) == null:
		_possess_turns = 0

## HP percents where rules with an "hp_below" condition unlock, as {"rule": index in rules, "percent": p}.
## The boss bar marks them as the moments the enemy gets a new move.
func hp_thresholds() -> Array[Dictionary]:
	var thresholds: Array[Dictionary] = []
	for i in rules.size():
		for condition in rules[i].conditions:
			if condition.type == "hp_below":
				thresholds.append({"rule": i, "percent": float(condition.get("percent", 50))})
	return thresholds

## Returns the index of the rule that ran, or -1.
func _act(enemy: Enemy, astar: AStarGrid2D) -> int:
	# A telegraphed attack keeps the enemy busy until it lands.
	if _pending_turns > 0:
		_pending_turns -= 1
		if _pending_turns == 0:
			match _pending_kind:
				"charge":
					_release_charge(enemy)
				"leap":
					_release_leap(enemy)
				_:
					_release_attack(enemy)
		return -1
	for i in rules.size():
		var rule: Dictionary = rules[i]
		if rule.max_uses > 0 and _uses[i] >= rule.max_uses:
			continue
		if rule.delay > 0:
			var possible := _conditions_hold(rule.conditions, enemy) and _can_run(rule.action, enemy)
			_ready_turns[i] = _ready_turns[i] + 1 if possible else 0
			if _cooldowns[i] > 0 or not possible:
				continue
			if _ready_turns[i] <= rule.delay:
				# Noticed the player, not ready yet: only turns toward them, so the player sees it coming.
				_face_player(enemy)
				enemy.play_animation("")
				return -1
		elif _cooldowns[i] > 0 or not _conditions_hold(rule.conditions, enemy):
			continue
		if _run_action(rule.action, enemy, astar):
			_ready_turns[i] = 0
			# Attacks, charges and leaps pick their own animation (windup or hit).
			if rule.action.type not in ["attack", "charge", "leap"]:
				enemy.play_animation(str(rule.action.get("animation", "")))
			return i
	enemy.play_animation("")
	return -1

func _conditions_hold(conditions: Array[Dictionary], enemy: Enemy) -> bool:
	for condition in conditions:
		if not _condition_holds(condition, enemy):
			return false
	return true

func _condition_holds(condition: Dictionary, enemy: Enemy) -> bool:
	var player_pos: Vector2i = enemy.manager.player.map_position
	match condition.type:
		"hp_below":
			return enemy.current_hp * 100.0 < float(condition.get("percent", 50)) * enemy.max_hp
		"hp_above":
			return enemy.current_hp * 100.0 > float(condition.get("percent", 50)) * enemy.max_hp
		"player_within":
			return _distance(enemy.map_position, player_pos) <= int(condition.get("distance", 1))
		"player_farther_than":
			return _distance(enemy.map_position, player_pos) > int(condition.get("distance", 1))
		"player_behind":
			return enemy.is_hit_from_behind(player_pos)
		"chance":
			return randf() * 100.0 < float(condition.get("percent", 50))
	return false

## Runs the action; false if it can't be done right now (then the next rule gets a chance).
func _run_action(action: Dictionary, enemy: Enemy, astar: AStarGrid2D) -> bool:
	match action.type:
		"attack":
			return _attack(action, enemy)
		"charge":
			return _charge(action, enemy)
		"approach":
			return _approach(enemy, astar, maxi(int(action.get("steps", 1)), 1))
		"flee":
			return _flee(enemy, maxi(int(action.get("steps", 1)), 1))
		"wander":
			return _wander(enemy)
		"face_player":
			return _face_player(enemy)
		"heal":
			return enemy.heal(roundi(enemy.max_hp * float(action.get("percent", 25)) / 100.0)) > 0
		"wait":
			return true
		"possess":
			return _possess(enemy, astar, maxi(int(action.get("turns", 2)), 1), maxi(int(action.get("steps", 1)), 1))
		"self_destruct":
			return _self_destruct(action, enemy)
		"throw":
			return _throw(action, enemy)
		"leap":
			return _leap(action, enemy)
	return false

func _throw(action: Dictionary, enemy: Enemy) -> bool:
	var manager := enemy.manager
	var thrown_id := str(action.get("enemy", ""))
	if thrown_id.is_empty():
		push_warning("%s: throw needs \"enemy\" (an enemy id, e.g. \"Bomboar\")" % enemy.name)
		return false
	var count := maxi(int(action.get("count", 1)), 1)
	var max_alive := maxi(int(action.get("max_alive", 0)), 0)
	if max_alive > 0:
		count = mini(count, max_alive - _alive_count(manager, thrown_id))
		if count <= 0:
			return false
	var player_tile := _player_tile(enemy)
	var reach := maxi(int(action.get("distance", 2)), 1)
	var options: Array[Vector2i] = []
	for y in manager.map_size.y + 1:
		for x in manager.map_size.x + 1:
			var tile := Vector2i(x, y)
			var gap := _distance(tile, player_tile)
			if gap >= 1 and gap <= reach and _is_free(enemy, tile):
				options.append(tile)
	options.shuffle()
	var speed := maxf(float(action.get("speed", 400)), 1.0)
	var height := float(action.get("height", 24))
	var thrown_any := false
	for tile: Vector2i in options.slice(0, count):
		var facing := Unit.facing_direction.LEFT if player_tile.x < tile.x else Unit.facing_direction.RIGHT
		var thrown := manager.spawn_enemy(thrown_id, tile, facing)
		if thrown == null:
			break
		thrown.position = enemy.position
		thrown.set_move_speed_until_arrival(speed)
		thrown.play_hop(height)
		thrown_any = true
	return thrown_any

func _alive_count(manager: Battle_Manager, enemy_id: String) -> int:
	var alive := 0
	for other in manager.enemies:
		if is_instance_valid(other) and not other.is_queued_for_deletion() and other.enemy_id == enemy_id:
			alive += 1
	return alive

## Picks the landing tile now; with a windup the jump itself happens when it ends (_release_leap).
func _leap(action: Dictionary, enemy: Enemy) -> bool:
	var direction := _leap_direction(action, enemy)
	if direction == 0:
		return false
	var landing := _leap_landing(enemy, direction, maxi(int(action.get("distance", 3)), 1))
	if landing == Battle_Manager.NO_TILE:
		return false
	enemy.set_facing(Unit.facing_direction.LEFT if direction < 0 else Unit.facing_direction.RIGHT)
	var windup := maxi(int(action.get("windup", 1)), 0)
	if windup == 0:
		_jump(action, enemy, landing)
		return true
	enemy.play_animation(str(action.get("windup_animation", "")))
	_pending_kind = "leap"
	_pending_action = action
	_pending_landing = landing
	_pending_direction = direction
	_pending_turns = windup
	var warned: Array[Vector2i] = [landing]
	for tile in TilePattern.to_tiles(action.offsets, landing, enemy.facing):
		if enemy.manager._is_in_bounds(tile) and tile not in warned:
			warned.append(tile)
	enemy._place_warning_tile(warned)
	return true

func _release_leap(enemy: Enemy) -> void:
	enemy._remove_warning_tiles()
	enemy.about_to_attack = false
	var landing := _pending_landing
	if not _is_free(enemy, landing):
		landing = _leap_landing(enemy, _pending_direction, _distance(enemy.map_position, landing))
	if landing == Battle_Manager.NO_TILE:
		enemy.play_animation("")
		return
	_jump(_pending_action, enemy, landing)

## -1 = left, 1 = right, 0 = no leap.
func _leap_direction(action: Dictionary, enemy: Enemy) -> int:
	var x: int = enemy.map_position.x
	var player_x := _player_tile(enemy).x
	match str(action.get("toward", "far_wall")):
		"far_wall":
			var right_wall: int = enemy.manager.map_size.x
			var wall := right_wall if player_x * 2 < right_wall else 0
			# Player in the middle column: both walls are as far, keep to the nearer one.
			if player_x * 2 == right_wall:
				wall = right_wall if x * 2 >= right_wall else 0
			return signi(wall - x)
		"player":
			return signi(player_x - x)
		"forward":
			return -1 if enemy.facing == Unit.facing_direction.LEFT else 1
	push_warning("%s: unknown leap toward '%s' (far_wall, player, forward)" % [enemy.name, action.get("toward")])
	return 0

## Farthest free tile in the row, up to distance tiles away in direction; obstacles and units in between don't matter.
func _leap_landing(enemy: Enemy, direction: int, distance: int) -> Vector2i:
	for d in range(distance, 0, -1):
		var tile: Vector2i = enemy.map_position + Vector2i(direction * d, 0)
		if _is_free(enemy, tile):
			return tile
	return Battle_Manager.NO_TILE

## Takes the tile at once (nothing can step onto it mid-air); the landing hit comes when the sprite gets there.
func _jump(action: Dictionary, enemy: Enemy, landing: Vector2i) -> void:
	var manager := enemy.manager
	var damage := roundi(enemy.dmg * float(action.get("damage_multiplier", 1.0)))
	var friendly_fire: bool = action.get("friendly_fire", false)
	var tiles := TilePattern.to_tiles(action.offsets, landing, enemy.facing)
	enemy._enemy_updated_position.emit(enemy, enemy.map_position, landing)
	enemy.map_position = landing
	enemy.destination = manager.map_position_to_position(landing)
	enemy.play_animation_until_arrival(str(action.get("animation", "")))
	enemy.set_move_speed_until_arrival(maxf(float(action.get("speed", 300)), 1.0))
	enemy.play_hop(float(action.get("height", 24)))
	enemy.add_contact_hit(enemy.destination, func() -> void:
		_emit_attack(enemy, tiles, damage, friendly_fire, landing))

# Reads the grid instead of player.map_position: when the player walks, enemies act before it is updated.
func _player_tile(enemy: Enemy) -> Vector2i:
	var manager := enemy.manager
	for y in manager.grid.size():
		for x in manager.grid[y].size():
			if manager.grid[y][x] is Player:
				return Vector2i(x, y)
	return manager.player.map_position

## Kills the enemy; Battle lights its fuse (Battle.light_fuse), which does the damage later.
## Whether the action could start now, without doing it (for delay). Only actions that need the player in reach
## check anything; the rest count as possible.
func _can_run(action: Dictionary, enemy: Enemy) -> bool:
	match action.type:
		"attack":
			var offsets: Array[Vector2i] = action.offsets
			if offsets.is_empty():
				return false
			if not action.get("needs_target", true):
				return true
			var player_pos: Vector2i = enemy.manager.player.map_position
			if player_pos in TilePattern.to_tiles(offsets, enemy.map_position, enemy.facing):
				return true
			return action.get("can_turn", true) 				and player_pos in TilePattern.to_tiles(offsets, enemy.map_position, _opposite(enemy.facing))
		"charge":
			var sight := maxi(int(action.get("sight", 0)), 0)
			var avoid_allies: bool = action.get("avoid_allies", true)
			return _sees_player(enemy, enemy.facing, sight, avoid_allies) or (action.get("can_turn", true) 				and _sees_player(enemy, _opposite(enemy.facing), sight, avoid_allies))
		"self_destruct":
			if not action.get("needs_target", true):
				return enemy.explodes()
			return enemy.explodes() and _player_on(enemy, TilePattern.to_tiles(enemy.get_explosion_offsets(), enemy.map_position, enemy.facing))
	return true

func _self_destruct(action: Dictionary, enemy: Enemy) -> bool:
	if not enemy.explodes():
		push_warning("%s: self_destruct needs explosion_tiles set on the enemy" % enemy.name)
		return false
	if action.get("needs_target", true):
		var tiles := TilePattern.to_tiles(enemy.get_explosion_offsets(), enemy.map_position, enemy.facing)
		if not _player_on(enemy, tiles):
			return false
	enemy.die()
	return true

# Reads the grid instead of player.map_position: when the player walks, enemies act before it is updated.
func _player_on(enemy: Enemy, tiles: Array[Vector2i]) -> bool:
	for tile in tiles:
		if enemy.manager._is_in_bounds(tile) and enemy.manager.grid[tile.y][tile.x] is Player:
			return true
	return false

func _attack(action: Dictionary, enemy: Enemy) -> bool:
	var offsets: Array[Vector2i] = action.offsets
	if offsets.is_empty():
		return false
	var player_pos: Vector2i = enemy.manager.player.map_position
	var tiles := TilePattern.to_tiles(offsets, enemy.map_position, enemy.facing)
	if action.get("needs_target", true) and player_pos not in tiles:
		if not action.get("can_turn", true):
			return false
		var other := _opposite(enemy.facing)
		var turned := TilePattern.to_tiles(offsets, enemy.map_position, other)
		if player_pos not in turned:
			return false
		enemy.set_facing(other)
		tiles = turned
	var damage := roundi(enemy.dmg * float(action.get("damage_multiplier", 1.0)))
	var friendly_fire: bool = action.get("friendly_fire", false)
	var windup := maxi(int(action.get("windup", 1)), 0)
	var animation := str(action.get("animation", ""))
	if windup == 0:
		enemy.play_animation(animation)
		_emit_attack(enemy, tiles, damage, friendly_fire, enemy.map_position)
		return true
	enemy.play_animation(str(action.get("windup_animation", "")))
	_pending_animation = animation
	_pending_tiles = tiles
	_pending_damage = damage
	_pending_friendly_fire = friendly_fire
	_pending_turns = windup
	_pending_kind = "attack"
	var visible: Array[Vector2i] = []
	for tile in tiles:
		if enemy.manager._is_in_bounds(tile):
			visible.append(tile)
	enemy._place_warning_tile(visible)
	return true

func _release_attack(enemy: Enemy) -> void:
	enemy._remove_warning_tiles()
	enemy.about_to_attack = false
	enemy.play_animation(_pending_animation)
	_emit_attack(enemy, _pending_tiles, _pending_damage, _pending_friendly_fire, enemy.map_position)

func _emit_attack(enemy: Enemy, tiles: Array[Vector2i], damage: int, friendly_fire: bool, source: Vector2i) -> void:
	var attack := Attack.new(enemy, tiles, damage)
	attack.hits_allies = friendly_fire
	attack.source_position = source
	enemy._attack_tiles.emit(attack)

func _charge(action: Dictionary, enemy: Enemy) -> bool:
	var sight := maxi(int(action.get("sight", 0)), 0)
	var avoid_allies: bool = action.get("avoid_allies", true)
	if not _sees_player(enemy, enemy.facing, sight, avoid_allies):
		if not action.get("can_turn", true) or not _sees_player(enemy, _opposite(enemy.facing), sight, avoid_allies):
			return false
		enemy.set_facing(_opposite(enemy.facing))
	var damage := roundi(enemy.dmg * float(action.get("damage_multiplier", 1.0)))
	var friendly_fire: bool = action.get("friendly_fire", true)
	var pierce: bool = action.get("pierce", false)
	var speed := maxf(float(action.get("speed", 2000)), 1.0)
	var windup := maxi(int(action.get("windup", 1)), 0)
	var animation := str(action.get("animation", ""))
	if windup == 0:
		_rush(enemy, damage, friendly_fire, pierce, speed, animation)
		return true
	enemy.play_animation(str(action.get("windup_animation", "")))
	_pending_animation = animation
	_pending_damage = damage
	_pending_friendly_fire = friendly_fire
	_pending_turns = windup
	_pending_kind = "charge"
	_pending_pierce = pierce
	_pending_speed = speed
	enemy._place_warning_tile(_charge_lane(enemy, enemy.facing))
	return true

func _release_charge(enemy: Enemy) -> void:
	enemy._remove_warning_tiles()
	enemy.about_to_attack = false
	_rush(enemy, _pending_damage, _pending_friendly_fire, _pending_pierce, _pending_speed, _pending_animation)

# Hits whoever stands on tile when the charging sprite reaches from (a target that stepped away is missed).
func _queue_contact_hit(enemy: Enemy, tile: Vector2i, from: Vector2i, damage: int, friendly_fire: bool) -> void:
	var at := enemy.manager.map_position_to_position(from)
	enemy.add_contact_hit(at, func() -> void:
		var tiles: Array[Vector2i] = [tile]
		_emit_attack(enemy, tiles, damage, friendly_fire, from))

## Tiles from the enemy (excluded) to the first wall (excluded) in the given direction.
func _charge_lane(enemy: Enemy, direction: Unit.facing_direction) -> Array[Vector2i]:
	var step := Vector2i(-1 if direction == Unit.facing_direction.LEFT else 1, 0)
	var lane: Array[Vector2i] = []
	var tile: Vector2i = enemy.map_position + step
	while enemy.manager._is_in_bounds(tile) and not enemy.manager.astar.is_point_solid(tile):
		lane.append(tile)
		tile += step
	return lane

# Reads the grid instead of player.map_position: when the player walks, enemies act before it is updated.
# avoid_allies: another enemy in front of the player blocks the view (charging would hit it).
func _sees_player(enemy: Enemy, direction: Unit.facing_direction, sight: int, avoid_allies: bool) -> bool:
	var lane := _charge_lane(enemy, direction)
	if sight > 0:
		lane.resize(mini(sight, lane.size()))
	for tile in lane:
		var unit = enemy.manager.grid[tile.y][tile.x]
		if unit is Player:
			return true
		if unit is Enemy and avoid_allies:
			return false
	return false

## Runs down the lane and stops before the first unit (hitting it) or the wall.
## With pierce, enemies are hit on the way and only the player or the wall stops it.
## Where it stops is decided now; each hit lands when the sprite reaches the tile in front of the target.
func _rush(enemy: Enemy, damage: int, friendly_fire: bool, pierce: bool, speed: float, animation: String) -> void:
	var manager := enemy.manager
	var landing: Vector2i = enemy.map_position
	var from: Vector2i = enemy.map_position
	for tile in _charge_lane(enemy, enemy.facing):
		var unit = manager.grid[tile.y][tile.x]
		if unit is Player or (unit is Enemy and friendly_fire):
			_queue_contact_hit(enemy, tile, from, damage, friendly_fire)
		if unit is Player or (unit is Enemy and not pierce):
			break
		if unit == null:
			landing = tile
		from = tile
	if landing != enemy.map_position:
		enemy._enemy_updated_position.emit(enemy, enemy.map_position, landing)
		enemy.map_position = landing
		enemy.destination = manager.map_position_to_position(landing)
		enemy.play_animation_until_arrival(animation)
		enemy.set_move_speed_until_arrival(speed)
	else:
		enemy.play_animation(animation)

## Walks toward the closest tile from which one of the behavior's attacks reaches the player.
func _approach(enemy: Enemy, astar: AStarGrid2D, steps: int) -> bool:
	var player_pos: Vector2i = enemy.manager.player.map_position
	var goals := _attack_spots(enemy, player_pos)
	if enemy.map_position in goals:
		return false
	var best: Array[Vector2i] = []
	# Path around other enemies, not through them (a step into an occupied tile would fail).
	var blocked := _block_other_enemies(enemy, astar)
	for goal in goals:
		var path := enemy._try_path_to(astar, goal)
		if path.size() > 1 and (best.is_empty() or path.size() < best.size()):
			best = path
	for tile in blocked:
		astar.set_point_solid(tile, false)
	# No free spot reachable: at least head for the player.
	if best.is_empty():
		best = enemy._try_path_to(astar, player_pos)
		best.resize(maxi(best.size() - 1, 0))
	var moved := false
	for i in range(1, mini(steps + 1, best.size())):
		if not _step(enemy, best[i]):
			break
		moved = true
	return moved

## Marks the tiles of all other enemies solid; returns them so the caller can clear them again.
func _block_other_enemies(enemy: Enemy, astar: AStarGrid2D) -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	for other in enemy.manager.enemies:
		if other != enemy and is_instance_valid(other) and not astar.is_point_solid(other.map_position):
			astar.set_point_solid(other.map_position, true)
			blocked.append(other.map_position)
	return blocked

## Free tiles from which some attack or self_destruct of this behavior (in either facing) would hit the player,
## plus tiles in the player's row from which a charge would see it.
## Without attacks or charges: the four tiles around the player.
func _attack_spots(enemy: Enemy, player_pos: Vector2i) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	var candidates: Array[Vector2i] = []
	for rule in rules:
		if rule.action.type == "attack":
			offsets.append_array(rule.action.offsets)
		elif rule.action.type == "self_destruct":
			offsets.append_array(enemy.get_explosion_offsets())
		elif rule.action.type == "charge":
			var sight := maxi(int(rule.action.get("sight", 0)), 0)
			candidates.append_array(_charge_spots(enemy, player_pos, sight, rule.action.get("avoid_allies", true)))
	if offsets.is_empty() and candidates.is_empty():
		for n in NEIGHBOURS:
			candidates.append(player_pos + n)
	else:
		for offset in offsets:
			candidates.append(player_pos - offset)
			candidates.append(player_pos - Vector2i(-offset.x, offset.y))
	var spots: Array[Vector2i] = []
	for tile in candidates:
		if tile not in spots and (tile == enemy.map_position or _is_free(enemy, tile)):
			spots.append(tile)
	return spots

## Tiles in the player's row, on both sides up to the first wall (and within sight; 0 = whole row).
## avoid_allies: also stops at the first other enemy, so the lane to the player is clear.
func _charge_spots(enemy: Enemy, player_pos: Vector2i, sight: int, avoid_allies: bool) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	for step in [Vector2i.LEFT, Vector2i.RIGHT]:
		var tile: Vector2i = player_pos + step
		while enemy.manager._is_in_bounds(tile) and not enemy.manager.astar.is_point_solid(tile):
			if sight > 0 and _distance(tile, player_pos) > sight:
				break
			var unit = enemy.manager.grid[tile.y][tile.x]
			if avoid_allies and unit is Enemy and unit != enemy:
				break
			spots.append(tile)
			tile += step
	return spots

## Stands on Remains for turns turns, then revives them; otherwise walks steps tiles toward the nearest reachable one.
func _possess(enemy: Enemy, astar: AStarGrid2D, turns: int, steps: int) -> bool:
	var manager := enemy.manager
	var body := manager.remains_at(enemy.map_position)
	if body:
		_possess_turns += 1
		if _possess_turns >= turns:
			_possess_turns = 0
			manager.revive_remains(body, enemy)
		return true
	var best: Array[Vector2i] = []
	var blocked := _block_other_enemies(enemy, astar)
	for other in manager.remains:
		var path := enemy._try_path_to(astar, other.map_position)
		if path.size() > 1 and (best.is_empty() or path.size() < best.size()):
			best = path
	for tile in blocked:
		astar.set_point_solid(tile, false)
	var moved := false
	for i in range(1, mini(steps + 1, best.size())):
		if not _step(enemy, best[i]):
			break
		moved = true
	return moved

func _flee(enemy: Enemy, steps: int) -> bool:
	var player_pos: Vector2i = enemy.manager.player.map_position
	var moved := false
	for i in steps:
		var best: Vector2i = enemy.map_position
		for n in NEIGHBOURS:
			var tile: Vector2i = enemy.map_position + n
			if _is_free(enemy, tile) and _distance(tile, player_pos) > _distance(best, player_pos):
				best = tile
		if best == enemy.map_position or not _step(enemy, best):
			break
		moved = true
	return moved

func _wander(enemy: Enemy) -> bool:
	var options: Array[Vector2i] = []
	for n in NEIGHBOURS:
		var tile: Vector2i = enemy.map_position + n
		if _is_free(enemy, tile):
			options.append(tile)
	return not options.is_empty() and _step(enemy, options.pick_random())

func _face_player(enemy: Enemy) -> bool:
	var dx: int = enemy.manager.player.map_position.x - enemy.map_position.x
	var wanted := Unit.facing_direction.LEFT if dx < 0 else Unit.facing_direction.RIGHT
	if dx == 0 or wanted == enemy.facing:
		return false
	enemy.set_facing(wanted)
	return true

func _step(enemy: Enemy, tile: Vector2i) -> bool:
	if not enemy.manager._can_move(enemy, enemy.map_position, tile):
		return false
	var path: Array[Vector2i] = [enemy.map_position, tile]
	enemy._commit_move(path)
	return true

func _is_free(enemy: Enemy, tile: Vector2i) -> bool:
	var manager := enemy.manager
	return manager._is_in_bounds(tile) and manager.grid[tile.y][tile.x] == null and not manager.astar.is_point_solid(tile)

static func _distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

static func _opposite(f: Unit.facing_direction) -> Unit.facing_direction:
	return Unit.facing_direction.LEFT if f == Unit.facing_direction.RIGHT else Unit.facing_direction.RIGHT
