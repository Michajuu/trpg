class_name TempoBar
extends Sprite2D

## Tylko widok. Wartość Tempa trzyma Player, pasek ją wyświetla.

@export_range(0, 100) var percentage: int = 0:
	set(value):
		percentage = clampi(value, 0, 100)
		_update_visuals()

## RichTextLabel, który pokazuje aktualne Tempo.
@export var tempo_counter: RichTextLabel

var tempo: int = 0

@onready var TempoBarCover: ColorRect = $TempoBarMask/TempoBarCover

func _ready() -> void:
	_update_visuals()

## Podpinane pod sygnał Player.tempo_changed.
func update_tempo(new_percentage: int, new_tempo: int) -> void:
	tempo = new_tempo
	percentage = new_percentage

func _update_visuals() -> void:
	if not is_node_ready():
		return
	TempoBarCover.position.y = -100 - 2 * percentage
	if tempo_counter:
		tempo_counter.text = str(tempo)
