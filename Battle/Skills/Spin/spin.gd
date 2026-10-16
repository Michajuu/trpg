extends Skill

## Example of a skill with its own behaviour script. Replace _activate() with the real effect.

func _activate() -> void:
	super()
	print("[Skill] %s - custom script" % data.display_name)
