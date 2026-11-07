class_name TurnOrderBar
extends HBoxContainer

## View only. Top-of-screen bar: the round number, then one portrait per unit in the order they act.
## The unit acting right now gets a bigger portrait that drops below the others.
## Battle drives it through turn_order_changed and active_unit_changed.

@export var round_text: String = "ROUND\n%d"
@export var portrait_size: Vector2 = Vector2(28, 28)
## Size of the acting unit's portrait compared to the others.
@export var active_scale: float = 1.4
## How far the acting unit's portrait drops below the others, in pixels.
@export var active_drop: float = 6.0
## Seconds the portrait takes to grow / shrink.
@export var tween_time: float = 0.12
@export var player_frame_color: Color = Color(0.45, 1, 0.55, 1)
@export var enemy_frame_color: Color = Color(1, 0.35, 0.35, 1)
@export var active_frame_color: Color = Color(1, 1, 1, 1)
@export var background_color: Color = Color(0, 0, 0, 0.75)
@export var border_width: int = 2

@onready var round_label: Label = $Round

# Unit -> {"slot": Control, "frame": Panel, "style": StyleBoxFlat, "color": Color, "on_exit": Callable}
var _portraits: Dictionary = {}
var _active: Unit
# Generated portraits, by scene path, so each kind of enemy is cropped once.
static var _portrait_cache: Dictionary = {}

## Connected to Battle_Manager.turn_order_changed. Rebuilds the portraits.
func show_order(order: Array[Unit], round_number: int) -> void:
	round_label.text = round_text % round_number
	for unit in _portraits.keys():
		_remove_portrait(unit)
	_active = null
	for unit in order:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			_add_portrait(unit)

## Connected to Battle_Manager.active_unit_changed.
func set_active(unit: Unit) -> void:
	if _active and _portraits.has(_active):
		_highlight(_active, false)
	_active = unit
	if _portraits.has(unit):
		_highlight(unit, true)

func _add_portrait(unit: Unit) -> void:
	var color := player_frame_color if unit is Player else enemy_frame_color
	var slot := Control.new()
	slot.custom_minimum_size = portrait_size
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = color
	style.set_border_width_all(border_width)
	var frame := Panel.new()
	frame.size = portrait_size
	frame.pivot_offset = Vector2(portrait_size.x / 2, 0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", style)
	var picture := TextureRect.new()
	picture.texture = _portrait_of(unit)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, border_width + 1)
	# Pixel art stays crisp; big hand-drawn sprites (e.g. scaled down in their scene) are smoothed.
	if picture.texture and maxf(picture.texture.get_width(), picture.texture.get_height()) > portrait_size.x * 2:
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(picture)
	slot.add_child(frame)
	add_child(slot)
	# Dead or merged enemies leave the bar right away.
	var on_exit := _remove_portrait.bind(unit)
	unit.tree_exiting.connect(on_exit)
	_portraits[unit] = {"slot": slot, "frame": frame, "style": style, "color": color, "on_exit": on_exit}

func _remove_portrait(unit: Unit) -> void:
	if not _portraits.has(unit):
		return
	var entry: Dictionary = _portraits[unit]
	entry.slot.queue_free()
	if is_instance_valid(unit) and unit.tree_exiting.is_connected(entry.on_exit):
		unit.tree_exiting.disconnect(entry.on_exit)
	_portraits.erase(unit)
	if _active == unit:
		_active = null

func _highlight(unit: Unit, on: bool) -> void:
	var entry: Dictionary = _portraits[unit]
	var frame: Panel = entry.frame
	var target_scale := active_scale if on else 1.0
	entry.style.border_color = active_frame_color if on else entry.color
	# The slot widens so neighbours make room; the frame scales inside it (containers reset child scale).
	entry.slot.custom_minimum_size.x = portrait_size.x * target_scale
	var tween := frame.create_tween().set_parallel()
	tween.tween_property(frame, "scale", Vector2.ONE * target_scale, tween_time)
	tween.tween_property(frame, "position", Vector2(portrait_size.x * (target_scale - 1.0) / 2, active_drop if on else 0.0), tween_time)

## The unit's own portrait, else its Sprite's first "idle" frame cropped to the visible pixels.
func _portrait_of(unit: Unit) -> Texture2D:
	if unit.portrait:
		return unit.portrait
	var key := unit.scene_file_path
	if not key.is_empty() and _portrait_cache.has(key):
		return _portrait_cache[key]
	var texture := _first_frame(unit)
	if texture:
		var image := texture.get_image()
		if image:
			var used := image.get_used_rect()
			if used.has_area():
				texture = ImageTexture.create_from_image(image.get_region(used))
	if not key.is_empty():
		_portrait_cache[key] = texture
	return texture

func _first_frame(unit: Unit) -> Texture2D:
	var sprite := unit.get_node_or_null("Sprite")
	if sprite is AnimatedSprite2D and sprite.sprite_frames:
		var frames: SpriteFrames = sprite.sprite_frames
		var animation: StringName = &"idle" if frames.has_animation(&"idle") else sprite.animation
		if frames.has_animation(animation) and frames.get_frame_count(animation) > 0:
			return frames.get_frame_texture(animation, 0)
	elif sprite is Sprite2D:
		return sprite.texture
	return null
