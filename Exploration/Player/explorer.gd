class_name Explorer
extends CharacterBody2D

## Player character in the Exploration segment: free 8-directional walking with collisions.
## Tuning lives in exported vars, so each level/class variant can override them in the Inspector
## without touching code.

## Top walking speed in pixels per second.
@export var move_speed: float = 120.0
## How fast the explorer reaches move_speed (px/s^2). Higher = snappier start.
@export var acceleration: float = 900.0
## How fast the explorer stops after the input is released (px/s^2).
@export var friction: float = 1200.0

## Input actions, exposed so a remap or a second control scheme does not need a code change.
@export var action_left: StringName = &"ui_left"
@export var action_right: StringName = &"ui_right"
@export var action_up: StringName = &"ui_up"
@export var action_down: StringName = &"ui_down"

## Animation names looked up in the sprite's SpriteFrames. "walk" falls back to "idle" when the
## sprite has no walking animation yet.
const ANIM_IDLE := &"idle"
const ANIM_WALK := &"walk"

## Layer whose painted area bounds the camera, so it never shows what lies outside the map.
## Left empty, the first TileMapLayer sibling (e.g. "Ground") is used.
@export var camera_bounds: TileMapLayer

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var camera: Camera2D = $Camera

## Last non-zero movement direction; future interactions (talking to NPCs, pushing) read it.
var facing_vector: Vector2 = Vector2.RIGHT

func _ready() -> void:
	if camera_bounds == null:
		camera_bounds = _find_sibling_layer()
	refresh_camera_limits()
	# With stretch aspect "keep_width" the visible height depends on the window, so re-clamp on resize.
	get_viewport().size_changed.connect(refresh_camera_limits)

## Call after painting cells into camera_bounds at runtime (TileMapLayer has no signal for it).
func refresh_camera_limits() -> void:
	if camera_bounds:
		_apply_camera_limits(camera_bounds)

func _find_sibling_layer() -> TileMapLayer:
	if get_parent() == null:
		return null
	for child in get_parent().get_children():
		if child is TileMapLayer:
			return child
	return null

## Sets Camera2D limits to the layer's used rect (in global pixels). On an axis where the map is
## smaller than the screen, the map is centered instead, since Camera2D cannot fit there.
func _apply_camera_limits(layer: TileMapLayer) -> void:
	var used := layer.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var tile := Vector2(layer.tile_set.tile_size)
	var top_left := layer.to_global(Vector2(used.position) * tile)
	var bottom_right := layer.to_global(Vector2(used.end) * tile)
	var screen := get_viewport_rect().size / camera.zoom
	var lim_min := top_left
	var lim_max := bottom_right
	for axis in 2:
		var gap := screen[axis] - (bottom_right[axis] - top_left[axis])
		if gap > 0.0:
			lim_min[axis] -= gap / 2.0
			lim_max[axis] += gap / 2.0
	camera.limit_left = floori(lim_min.x)
	camera.limit_top = floori(lim_min.y)
	camera.limit_right = ceili(lim_max.x)
	camera.limit_bottom = ceili(lim_max.y)
	camera.reset_smoothing()

func _physics_process(delta: float) -> void:
	# get_vector normalizes the result, so diagonals are not faster than straight moves.
	var input := Input.get_vector(action_left, action_right, action_up, action_down)
	if input != Vector2.ZERO:
		velocity = velocity.move_toward(input * move_speed, acceleration * delta)
		facing_vector = input
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
	_update_animation(input)

func _update_animation(input: Vector2) -> void:
	# Only flip on a clear horizontal input, so walking straight up/down keeps the last facing.
	if input.x != 0.0:
		sprite.flip_h = input.x < 0.0
	var wanted := ANIM_IDLE
	if velocity.length_squared() > 1.0 and sprite.sprite_frames.has_animation(ANIM_WALK):
		wanted = ANIM_WALK
	if sprite.animation != wanted or not sprite.is_playing():
		sprite.play(wanted)
