class_name DamageNumber
extends Node2D

## Liczba obrażeń, która wylatuje z celu łukiem w bok i znika.
## Wszystkie parametry animacji można zmieniać w Inspectorze sceny.

## Zakres odległości (min, max) w pikselach, na jaką liczba odlatuje w bok.
@export var side_distance: Vector2 = Vector2(20, 30)
## Zakres wysokości (min, max) łuku, zanim liczba zacznie opadać.
@export var arc_height: Vector2 = Vector2(8, 14)
## O ile pikseli poniżej punktu startu liczba kończy lot.
@export var fall_distance: float = 6.0
## Czas całej animacji w sekundach.
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

## Wywołaj po add_child. direction: -1 = w lewo, 1 = w prawo.
func play(amount: int, direction: int, at_global_position: Vector2) -> void:
	label.text = str(amount)
	global_position = at_global_position.round()
	_start = position

	var side := direction * randf_range(side_distance.x, side_distance.y)
	var up := randf_range(arc_height.x, arc_height.y)

	# Ruch w bok + zanikanie pod koniec.
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "_offset_x", side, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.4) \
		.set_delay(duration * 0.6)
	tween.chain().tween_callback(queue_free)

	# Łuk: najpierw w górę, potem opadanie.
	var arc := create_tween()
	arc.tween_property(self, "_offset_y", -up, duration * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_property(self, "_offset_y", fall_distance, duration * 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# Zaokrąglamy do pełnych pikseli, żeby tekst nie "pływał" między pikselami.
func _apply_offset() -> void:
	position = (_start + Vector2(_offset_x, _offset_y)).round()
