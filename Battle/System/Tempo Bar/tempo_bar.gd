@tool
extends Sprite2D

@export_range(0, 100) var percentage : int = 0

@onready var TempoBarCover = $TempoBarMask/TempoBarCover

func _ready():
	TempoBarCover.position.y = -100 - 2 * percentage 
