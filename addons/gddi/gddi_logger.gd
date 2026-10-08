@abstract
extends RefCounted
class_name GDDILogger


## Formats timestamped, severity-colored messages emitted by GDDI.
## Severity threshold used by the GDDI logger. Higher values suppress less severe messages.
enum LogLevel {
	DEBUG,
	INFO,
	WARNING,
	ERROR,
	NONE
}

const _TAG: String = 'GDDI'

## Current logging threshold. GDDI initializes this from the Verbose project setting at startup.
static var current_log_level: int

## Emits a debug message when the current threshold includes [enum LogLevel.DEBUG].
static func debug(message: String) -> void:
	if current_log_level <= LogLevel.DEBUG:
		_print_log("DEBUG", message, '#797979')

## Emits an informational message when the current threshold includes [enum LogLevel.INFO].
static func info(message: String) -> void:
	if current_log_level <= LogLevel.INFO:
		_print_log("INFO", message, "white")

## Emits a warning when the current threshold includes [enum LogLevel.WARNING].
static func warn(message: String) -> void:
	if current_log_level <= LogLevel.WARNING:
		_print_log("WARNING", message, "#d1ba75")

## Emits an error when the current threshold includes [enum LogLevel.ERROR].
static func error(message: String) -> void:
	if current_log_level <= LogLevel.ERROR:
		_print_log("ERROR", message, "#e24d37")

static func _print_log(level_str: String, message: String, color: String) -> void:
	var caller: String = _get_caller_info()
	var timestamp: String = _get_timestamp_with_ms()
	
	var text: String
	if caller.is_empty():
		text = "[%s] [%s] [%s]: %s" % [timestamp, level_str, _TAG, message]
	else:
		text = "[%s] [%s] [%s] (%s): %s" % [timestamp, level_str, _TAG, caller, message]
	var output := "[color=%s]%s[/color]" % [color, text]

	if OS.has_feature("web"):
		print(text)
	else:
		print_rich(output)

static func _get_timestamp_with_ms() -> String:
	var datetime: Dictionary = Time.get_datetime_dict_from_system()
	var msec: int = Time.get_ticks_msec() % 1000
	return "%04d-%02d-%02d %02d:%02d:%02d.%03d" % [
		datetime.year,
		datetime.month,
		datetime.day,
		datetime.hour,
		datetime.minute,
		datetime.second,
		msec
	]

static func _get_caller_info() -> String:
	var stack: Array = get_stack()
	for index in range(3, stack.size()):
		var caller: Dictionary = stack[index]
		var source: String = caller.get("source", "")
		if source.ends_with("/addons/gddi/gddi.gd"):
			continue
		var file_name: String = source.get_file()
		var line_num: int = caller.get("line", 0)
		var fn_name: String = caller.get("function", "")
		return "%s:%d -> %s()" % [file_name, line_num, fn_name]
	return ""
