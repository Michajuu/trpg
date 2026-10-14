class_name Skill
extends RefCounted

## Base for every skill.
## A skill lives in its own folder: Battle/Skills/<Id>/
##   <id>.json - data (name, tempo_cost, description), required
##   <id>.gd   - behaviour, optional; must extend Skill and override _activate()
## A skill without a script just logs its use.

const SKILLS_PATH := "res://Battle/Skills/%s/%s"

var data: SkillData
## Unit using the skill; set by Player.set_skills.
var user: Player

## Builds a skill from its folder. Returns null (and logs an error) if the skill doesn't exist.
static func load_skill(id: String) -> Skill:
	var base_path := SKILLS_PATH % [id, id.to_snake_case()]
	var json_path := base_path + ".json"
	if not ResourceLoader.exists(json_path):
		push_error("Skill '%s': missing %s" % [id, json_path])
		return null
	var skill: Skill = Skill.new()
	var script_path := base_path + ".gd"
	if ResourceLoader.exists(script_path):
		var instance = load(script_path).new()
		if not instance is Skill:
			push_error("Skill '%s': %s must extend Skill" % [id, script_path])
			return null
		skill = instance
	var json: JSON = load(json_path)
	skill.data = SkillData.from_dict(json.data)
	if skill.data.id.is_empty():
		skill.data.id = id
	return skill

func can_use() -> bool:
	return user != null and user.tempo >= data.tempo_cost

## Spends Tempo and runs the effect. Returns false if the user can't afford it.
func use() -> bool:
	if user == null or not user.spend_tempo(data.tempo_cost):
		return false
	_activate()
	return true

## The skill's effect. Override in the skill's own script; base behaviour only logs the use.
func _activate() -> void:
	print("[Skill] %s used (cost %d Tempo)" % [data.display_name, data.tempo_cost])
