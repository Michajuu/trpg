class_name TempoBar
extends Sprite2D

## View only. Player owns the Tempo value; this meter just displays it.
## The ring shows progress within the current Tempo level (each level fills up from zero).

## Progress within the current level (0.0 = empty, 1.0 = full).
@export_range(0.0, 1.0) var level_progress: float = 0.0:
	set(value):
		level_progress = clampf(value, 0.0, 1.0)
		_update_visuals()

## TempoBarCover value at which the ring looks empty (0%).
@export var cover_value_empty: float = 76.0
## TempoBarCover value at which the ring looks full (100%).
@export var cover_value_full: float = 24.0

## RichTextLabel that displays the current Tempo.
@export var tempo_counter: RichTextLabel

var tempo: int = 0

@onready var TempoBarCover: TextureProgressBar = $TempoBarMask/TempoBarCover

func _ready() -> void:
	_update_visuals()

## Connected to the Player.tempo_changed signal.
func update_tempo(new_tempo: int, new_level_progress: float) -> void:
	tempo = new_tempo
	level_progress = new_level_progress

func _update_visuals() -> void:
	if not is_node_ready():
		return
	TempoBarCover.value = lerpf(cover_value_empty, cover_value_full, level_progress)
	if tempo_counter:
		tempo_counter.text = str(tempo)
