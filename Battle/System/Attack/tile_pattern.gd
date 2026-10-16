class_name TilePattern
extends RefCounted

## Turns a skill's "tiles" value into tile offsets, and offsets into grid tiles.
## Offsets are relative to the user: +x = forward (the way the user faces), y = grid row (-1 = up).
## Presets live in tile_patterns.json, so adding one needs no code.

const PRESETS_PATH := "res://Battle/Skills/tile_patterns.json"

static var _presets: Dictionary = {}

## value: a preset name ("in_front") or an explicit list of offsets ([[1, 0], [2, 0]]).
static func parse(value) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	var raw = value
	if value is String:
		var presets := _get_presets()
		if not presets.has(value):
			push_error("Unknown tile pattern '%s' (presets: %s, see %s)" % [value, presets.keys(), PRESETS_PATH])
			return offsets
		raw = presets[value]
	if not raw is Array:
		push_error("Tile pattern must be a preset name or a list of [x, y] offsets, got %s" % [raw])
		return offsets
	for pair in raw:
		if pair is Array and pair.size() == 2:
			offsets.append(Vector2i(int(pair[0]), int(pair[1])))
		else:
			push_error("Invalid tile offset %s, expected [x, y]" % [pair])
	return offsets

## Offsets -> grid tiles around origin; mirrored horizontally when facing left.
static func to_tiles(offsets: Array[Vector2i], origin: Vector2i, facing: Unit.facing_direction) -> Array[Vector2i]:
	var forward := -1 if facing == Unit.facing_direction.LEFT else 1
	var tiles: Array[Vector2i] = []
	for offset in offsets:
		tiles.append(origin + Vector2i(offset.x * forward, offset.y))
	return tiles

static func _get_presets() -> Dictionary:
	if _presets.is_empty():
		var json: JSON = load(PRESETS_PATH)
		if json and json.data is Dictionary:
			_presets = json.data
		else:
			push_error("Could not load tile pattern presets from %s" % PRESETS_PATH)
	return _presets
