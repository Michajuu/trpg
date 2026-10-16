class_name SkillData
extends Resource

var id: String
var display_name: String
var tempo_cost: int
var description: String
## Skill damage = user's dmg * damage_multiplier.
var damage_multiplier: float
## Tiles the skill hits, as offsets from the user (see TilePattern). Empty = deals no damage.
var tile_offsets: Array[Vector2i]

static func from_dict(dict: Dictionary) -> SkillData:
	var obj = SkillData.new()
	obj.id = dict.get("id", "")
	obj.display_name = dict.get("name", obj.id)
	obj.tempo_cost = int(dict.get("tempo_cost", 1))
	obj.description = dict.get("description", "")
	obj.damage_multiplier = float(dict.get("damage_multiplier", 1.0))
	obj.tile_offsets = TilePattern.parse(dict.get("tiles", []))
	return obj
