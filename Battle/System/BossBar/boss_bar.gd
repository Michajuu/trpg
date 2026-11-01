class_name BossBar
extends VBoxContainer

## View only. Big health bar at the top of the screen for the enemy with is_boss (Battle hides its own bar).
## Marks the HP percents where its AI gets a new move: every rule with an "hp_below" condition.
## A marker flashes and dims once that rule has run, so the player sees the new attack coming and when it fired.

## Marker of a move the boss hasn't used yet.
@export var marker_color: Color = Color(1, 0.85, 0.2, 1)
## Marker of a move the boss has already used.
@export var used_marker_color: Color = Color(1, 1, 1, 0.3)
@export var marker_width: float = 2.0
## Seconds the bar stays at 0 after the boss dies before hiding.
@export var hide_delay: float = 0.6

@onready var name_label: Label = $Name
@onready var bar: ProgressBar = $Bar

var boss: Enemy
# Rule index -> its marker (ColorRect on the bar).
var _markers: Dictionary = {}

func _ready() -> void:
	visible = boss != null

## Shows the bar for enemy. Call after the enemy is in the tree (its HP and AI are set in _ready).
func track(enemy: Enemy) -> void:
	boss = enemy
	name_label.text = enemy.unit_name
	bar.max_value = enemy.max_hp
	bar.value = enemy.current_hp
	enemy.hp_changed.connect(_on_hp_changed)
	enemy.enemy_died.connect(_on_boss_died)
	_build_markers(enemy.ai)
	show()

func _build_markers(ai: AIBehavior) -> void:
	for marker in _markers.values():
		marker.queue_free()
	_markers.clear()
	if ai == null:
		return
	for threshold in ai.hp_thresholds():
		var marker := ColorRect.new()
		marker.color = marker_color
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var at := clampf(threshold.percent / 100.0, 0.0, 1.0)
		marker.anchor_left = at
		marker.anchor_right = at
		marker.anchor_bottom = 1.0
		# Sticks out of the bar a little so it reads over both the fill and the background.
		marker.offset_left = -marker_width / 2
		marker.offset_right = marker_width / 2
		marker.offset_top = -2
		marker.offset_bottom = 2
		bar.add_child(marker)
		_markers[threshold.rule] = marker
	ai.rule_used.connect(_on_rule_used)

func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	bar.max_value = max_hp
	bar.value = current_hp

func _on_rule_used(rule: int) -> void:
	var marker: ColorRect = _markers.get(rule)
	if marker == null or marker.color == used_marker_color:
		return
	# Flash the marker and the bar, then leave the marker dimmed.
	var flash := create_tween().set_parallel()
	flash.tween_property(marker, "color", Color.WHITE, 0.1)
	flash.tween_property(bar, "modulate", Color(2, 2, 2, 1), 0.1)
	flash.chain().tween_property(marker, "color", used_marker_color, 0.5)
	flash.tween_property(bar, "modulate", Color.WHITE, 0.5)

func _on_boss_died(_enemy: Enemy) -> void:
	boss = null
	bar.value = 0
	get_tree().create_timer(hide_delay).timeout.connect(func() -> void:
		if boss == null:
			hide())
