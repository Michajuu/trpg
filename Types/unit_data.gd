class_name UnitData
extends Resource

var id: String
var position: Vector2i

static func from_dict(dict: Dictionary) -> UnitData:
	var obj = UnitData.new()
	obj.id = dict.get("id", "")
	obj.position = Vector2i(dict.get("x", 0), dict.get("y", 0))
	return obj
