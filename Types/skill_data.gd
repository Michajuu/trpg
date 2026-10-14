class_name SkillData
extends Resource

var id: String
var display_name: String
var tempo_cost: int
var description: String

static func from_dict(dict: Dictionary) -> SkillData:
	var obj = SkillData.new()
	obj.id = dict.get("id", "")
	obj.display_name = dict.get("name", obj.id)
	obj.tempo_cost = int(dict.get("tempo_cost", 1))
	obj.description = dict.get("description", "")
	return obj
