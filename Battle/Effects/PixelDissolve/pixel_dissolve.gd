class_name PixelDissolve
extends Node2D

## Death effect: a copy of a sprite's current frame that crumbles into its own pixels, which drift up and fade.
## Purely visual: Battle adds it where an enemy (or destroyed remains) was, and it frees itself when done.
## Every opaque texel becomes one square, released top to bottom with a bit of randomness.

## Time over which pixels are released, from the top row to the bottom one.
@export var sweep_time: float = 0.45
## Extra random delay per pixel, so rows don't come off as straight lines.
@export var release_jitter: float = 0.15
## How long a released pixel lives before it has faded out.
@export var pixel_lifetime: float = 0.6
## Initial speed of a released pixel, in pixels per second (x: sideways spread, y: upward speed range).
@export var spread_speed: float = 18.0
@export var rise_speed_min: float = 10.0
@export var rise_speed_max: float = 35.0
## Acceleration of released pixels; negative y = they float upward like dust.
@export var acceleration: Vector2 = Vector2(0, -40)
## Released pixels blend toward this color while they fade.
@export var dissolve_color: Color = Color(1, 1, 1, 1)
## Texels with less alpha than this are skipped.
const ALPHA_THRESHOLD := 0.1

var _pixel_size: Vector2 = Vector2.ONE
var _start: PackedVector2Array
var _velocity: PackedVector2Array
var _colors: PackedColorArray
var _release: PackedFloat32Array
var _time: float = 0.0
var _duration: float = 0.0

## Builds the effect from a Sprite2D or AnimatedSprite2D (its current frame, flip, offset, scale and modulate).
## Returns null when the sprite has no readable frame. Position the result where the sprite's parent was.
static func from_sprite(sprite: Node2D) -> PixelDissolve:
	var texture := _current_texture(sprite)
	var image := _image_of(texture)
	if image == null:
		return null
	var effect := PixelDissolve.new()
	effect._build(sprite, image)
	return effect

static func _current_texture(sprite: Node2D) -> Texture2D:
	if sprite is AnimatedSprite2D:
		var frames: SpriteFrames = sprite.sprite_frames
		if frames and frames.has_animation(sprite.animation) and frames.get_frame_count(sprite.animation) > sprite.frame:
			return frames.get_frame_texture(sprite.animation, sprite.frame)
	elif sprite is Sprite2D:
		return sprite.texture
	return null

# Pixels of the texture; AtlasTextures (sprite sheet frames) are cut out of their atlas.
static func _image_of(texture: Texture2D) -> Image:
	if texture == null:
		return null
	var image: Image
	if texture is AtlasTexture and texture.atlas:
		image = texture.atlas.get_image()
		if image:
			image = image.get_region(Rect2i(texture.region))
	else:
		image = texture.get_image()
	if image and image.is_compressed():
		image.decompress()
	return image

func _build(sprite: Node2D, image: Image) -> void:
	var size := Vector2(image.get_size())
	var scale_abs: Vector2 = sprite.scale.abs()
	# Hi-res art scaled down (e.g. 0.25): one square per screen pixel, not per texel.
	var cell := maxi(1, ceili(1.0 / maxf(minf(scale_abs.x, scale_abs.y), 0.001)))
	var top_left: Vector2 = sprite.offset - (size / 2.0 if sprite.centered else Vector2.ZERO)
	_pixel_size = scale_abs * cell
	position = sprite.position
	var tint: Color = sprite.modulate * sprite.self_modulate
	for y in range(0, image.get_height(), cell):
		for x in range(0, image.get_width(), cell):
			var color := _cell_color(image, Rect2i(x, y, cell, cell))
			if color.a < ALPHA_THRESHOLD:
				continue
			# Flipped: the cell mirrors around the image's edge.
			var px: float = (size.x - x - cell) if sprite.flip_h else x
			var py: float = (size.y - y - cell) if sprite.flip_v else y
			_start.append((top_left + Vector2(px, py)) * scale_abs)
			_colors.append(color * tint)
			_velocity.append(Vector2(randf_range(-spread_speed, spread_speed), -randf_range(rise_speed_min, rise_speed_max)))
			# Top rows go first.
			_release.append(clampf(py / maxf(size.y - cell, 1.0), 0.0, 1.0) * sweep_time + randf() * release_jitter)
	_duration = sweep_time + release_jitter + pixel_lifetime

# Average color of the opaque texels in the cell; transparent when less than half of it is opaque (crisp edges).
static func _cell_color(image: Image, rect: Rect2i) -> Color:
	rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var sum := Color(0, 0, 0, 0)
	var opaque := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c := image.get_pixel(x, y)
			if c.a >= ALPHA_THRESHOLD:
				sum += c
				opaque += 1
	if opaque == 0 or opaque * 2 < rect.get_area():
		return Color(0, 0, 0, 0)
	return sum / opaque

func _process(delta: float) -> void:
	_time += delta
	if _time >= _duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for i in _start.size():
		var age := _time - _release[i]
		if age <= 0.0:
			draw_rect(Rect2(_start[i], _pixel_size), _colors[i])
			continue
		if age >= pixel_lifetime:
			continue
		var t := age / pixel_lifetime
		var pos := _start[i] + _velocity[i] * age + acceleration * (0.5 * age * age)
		var color := _colors[i].lerp(dissolve_color, t)
		color.a = _colors[i].a * (1.0 - t)
		# Snapped to whole pixels so it stays pixel art.
		draw_rect(Rect2(pos.round(), _pixel_size), color)
