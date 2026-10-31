class_name HeartBar
extends HBoxContainer

## View only. Player owns the HP value; this bar just displays it as hearts.
## Number of hearts = max_hp / hp_per_heart, so raising max_hp adds hearts.
## Each heart is split into two halves; a partially lost half still shows as a half heart,
## so the bar is never empty while the player is alive.

## How much HP a single full heart represents. 2 = HP is counted in half-hearts (Player).
@export var hp_per_heart: int = 2
@export var full_heart: Texture2D = preload("res://Battle/System/full-heart.png")
@export var half_heart: Texture2D = preload("res://Battle/System/half-heart.png")
@export var empty_heart: Texture2D = preload("res://Battle/System/empty-heart.png")

## Connected to the Player.hp_changed signal.
func update_hp(current_hp: int, max_hp: int) -> void:
	var heart_count := ceili(float(max_hp) / hp_per_heart)
	_set_heart_count(heart_count)
	# HP rounded up to whole half-hearts.
	var halves := ceili(current_hp * 2.0 / hp_per_heart)
	for i in heart_count:
		var heart: TextureRect = get_child(i)
		var heart_halves := clampi(halves - i * 2, 0, 2)
		heart.texture = [empty_heart, half_heart, full_heart][heart_halves]

## Adds or removes heart icons so there are exactly count of them.
func _set_heart_count(count: int) -> void:
	while get_child_count() > count:
		var last := get_child(get_child_count() - 1)
		remove_child(last)
		last.queue_free()
	while get_child_count() < count:
		var heart := TextureRect.new()
		heart.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		add_child(heart)
