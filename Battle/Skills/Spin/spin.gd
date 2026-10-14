extends Skill

## Example of a skill with its own behaviour script. Replace _activate() with the real effect.

func _activate() -> void:
	print("[Skill] %s used (cost %d Tempo) - custom script" % [data.display_name, data.tempo_cost])
