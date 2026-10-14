class_name SkillSlot
extends TextureRect

## View only. Shows a skill's Tempo cost and how close the player is to affording it.
## The ColorRect cover darkens the slot and drops lower as Tempo approaches the cost; it's gone once affordable.
## Battle creates one slot per skill in the loadout and feeds it Player.tempo_changed.

## Full Tempo points needed to use the skill. Overwritten by the assigned skill's cost.
@export var tempo_cost: int = 1:
	set(value):
		tempo_cost = maxi(value, 0)
		_update_visuals()

## Skill shown in this slot. Sets the cost and the name label.
var skill: Skill:
	set(value):
		skill = value
		if skill:
			tempo_cost = skill.data.tempo_cost
		_update_visuals()

@onready var cover: ColorRect = $"Skill Mask/ColorRect"
@onready var name_label: Label = $"Skill Mask/Placeholder"
@onready var cost_label: Label = $TempoCost
# Cover's top/bottom as laid out in the editor = fully covered slot.
@onready var _cover_top: float = cover.offset_top
@onready var _cover_bottom: float = cover.offset_bottom

var tempo: int = 0
var level_progress: float = 0.0

func _ready() -> void:
	_update_visuals()

## Connected to the Player.tempo_changed signal (same signature as Tempometer.update_tempo).
func update_tempo(new_tempo: int, new_level_progress: float) -> void:
	tempo = new_tempo
	level_progress = new_level_progress
	_update_visuals()

## 0.0 = no Tempo at all, 1.0 = skill affordable. Includes progress toward the next point,
## so the cover moves smoothly instead of jumping one full point at a time.
func get_readiness() -> float:
	if tempo_cost <= 0 or tempo >= tempo_cost:
		return 1.0
	return clampf((tempo + level_progress) / tempo_cost, 0.0, 1.0)

func _update_visuals() -> void:
	if not is_node_ready():
		return
	cost_label.text = str(tempo_cost)
	if skill:
		name_label.text = skill.data.display_name
	# Only the top edge moves down; the bottom stays put, so the cover shrinks toward the bottom.
	cover.offset_top = lerpf(_cover_top, _cover_bottom, get_readiness())
	if get_readiness() == 1:
		cost_label.add_theme_color_override("font_color", Color("#fff"))
	else:
		cost_label.add_theme_color_override("font_color", Color("#2b2b2b"))
