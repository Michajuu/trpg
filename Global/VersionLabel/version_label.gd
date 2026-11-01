extends CanvasLayer

## Shows the game version in the bottom-right corner of every screen (autoload "VersionLabel").
## The version comes from Project Settings > Application > Config > Version (application/config/version);
## bump it together with changelog.md.

const VERSION_SETTING := "application/config/version"

@onready var label: Label = $Label

func _ready() -> void:
	var version := str(ProjectSettings.get_setting(VERSION_SETTING, ""))
	label.text = "v%s" % version if not version.is_empty() else "dev"
