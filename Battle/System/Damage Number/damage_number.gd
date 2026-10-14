class_name DamageNumber
extends Node2D

## A damage number that arcs sideways out of the target and fades away.
## All animation parameters can be tweaked in the scene's Inspector.

## Range (min, max) in pixels of how far the number flies sideways.
@export var side_distance: Vector2 = Vector2(20, 30)
## Range (min, max) of the arc height before the number starts falling.
@export var arc_height: Vector2 = Vector2(8, 14)
## How many pixels below the start point the number ends its flight.
@export var fall_distance: float = 6.0
## Duration of the whole animation in seconds.
@export var duration: float = 0.6

@onready var label: Label = $Label

var _start: Vector2
var _offset_x: float = 0.0:
	set(value):
		_offset_x = value
		_apply_offset()
var _offset_y: float = 0.0:
	set(value):
		_offset_y = value
		_apply_offset()

## Call after add_child. direction: -1 = left, 1 = right.
func play(amount: int, direction: int, at_global_position: Vector2) -> void:
	label.text = str(amount)
	global_position = at_global_position.round()
	_start = position

	var side := direction * randf_range(side_distance.x, side_distance.y)
	var up := randf_range(arc_height.x, arc_height.y)

	# Sideways movement + fade-out at the end.
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "_offset_x", side, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.4) \
		.set_delay(duration * 0.6)
	tween.chain().tween_callback(queue_free)

	# Arc: up first, then falling.
	var arc := create_tween()
	arc.tween_property(self, "_offset_y", -up, duration * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_property(self, "_offset_y", fall_distance, duration * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# Round to whole pixels so the text doesn't "swim" between pixels.
func _apply_offset() -> void:
	position = (_start + Vector2(_offset_x, _offset_y)).round()
