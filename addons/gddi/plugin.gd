@tool
extends EditorPlugin

const AUTOLOAD_NAME := "GDDI"
const AUTOLOAD_PATH := "res://addons/gddi/gddi.gd"
const INITIALIZERS_SETTING := "application/GDDI/initializers"
const INITIALIZERS_DEFAULT: PackedStringArray = []
const VERBOSE_SETTING := "application/GDDI/verbose"
const VERBOSE_DEFAULT := false

const INITIALIZERS_PROPERTY := {
	"name": INITIALIZERS_SETTING,
	"type": TYPE_PACKED_STRING_ARRAY,
	"hint": PROPERTY_HINT_NONE,
}
const VERBOSE_PROPERTY := {
	"name": VERBOSE_SETTING,
	"type": TYPE_BOOL,
	"hint": PROPERTY_HINT_NONE,
}


func _enter_tree() -> void:
	if not ProjectSettings.has_setting(INITIALIZERS_SETTING):
		ProjectSettings.set_setting(INITIALIZERS_SETTING, INITIALIZERS_DEFAULT)
	ProjectSettings.set_initial_value(INITIALIZERS_SETTING, INITIALIZERS_DEFAULT)
	ProjectSettings.add_property_info(INITIALIZERS_PROPERTY)
	if not ProjectSettings.has_setting(VERBOSE_SETTING):
		ProjectSettings.set_setting(VERBOSE_SETTING, VERBOSE_DEFAULT)
	ProjectSettings.set_initial_value(VERBOSE_SETTING, VERBOSE_DEFAULT)
	ProjectSettings.add_property_info(VERBOSE_PROPERTY)

	if not ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
