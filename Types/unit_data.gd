class_name UnitData
extends Resource

var id: String
var position: Vector2i
## Which way the unit faces when the battle starts. JSON: "facing": "left" | "right" (default "right").
var facing: Unit.facing_direction = Unit.facing_direction.RIGHT

static func from_dict(dict: Dictionary) -> UnitData:
	var obj = UnitData.new()
	obj.id = dict.get("id", "")
	obj.position = Vector2i(dict.get("x", 0), dict.get("y", 0))
	obj.facing = parse_facing(dict.get("facing", "right"))
	return obj

## "left" / "right" (any case) -> Unit.facing_direction. Unknown values fall back to right with a warning.
static func parse_facing(value) -> Unit.facing_direction:
	match str(value).to_lower():
		"left":
			return Unit.facing_direction.LEFT
		"right":
			return Unit.facing_direction.RIGHT
	push_warning("Unknown facing '%s', expected \"left\" or \"right\"; using right" % [value])
	return Unit.facing_direction.RIGHT
