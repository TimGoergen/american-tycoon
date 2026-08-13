class_name ActionTracer
extends RefCounted

## ActionTracer logs high-frequency gameplay and UI actions to `user://action_trace.log`.
## Every log entry is flushed immediately to disk so that if the app native process is killed
## or crashes unexpectedly, the last written line pinpoints the exact event immediately prior to closure.

const TRACE_FILE_PATH := "user://action_trace.log"
const LAST_RUN_FILE_PATH := "user://action_trace_last_run.log"

static var _file: FileAccess = null
static var _start_ticks: int = 0


static func init_tracer() -> void:
	_start_ticks = Time.get_ticks_msec()
	# Preserve previous session's log file for crash inspection
	if FileAccess.file_exists(TRACE_FILE_PATH):
		if FileAccess.file_exists(LAST_RUN_FILE_PATH):
			DirAccess.remove_absolute(LAST_RUN_FILE_PATH)
		DirAccess.rename_absolute(TRACE_FILE_PATH, LAST_RUN_FILE_PATH)

	_file = FileAccess.open(TRACE_FILE_PATH, FileAccess.WRITE)
	if _file != null:
		trace("SYSTEM", "Tracer initialized. OS=%s, mobile=%s" % [OS.get_name(), OS.has_feature("mobile")])


static func trace(category: String, message: String) -> void:
	var timestamp := Time.get_ticks_msec() - _start_ticks
	var line := "[%8d ms] [%s] %s" % [timestamp, category, message]
	print(line)
	if _file != null:
		_file.store_line(line)
		_file.flush()


static func get_last_run_trace() -> String:
	if FileAccess.file_exists(LAST_RUN_FILE_PATH):
		var f := FileAccess.open(LAST_RUN_FILE_PATH, FileAccess.READ)
		if f != null:
			return f.get_as_text()
	if FileAccess.file_exists(TRACE_FILE_PATH):
		var f := FileAccess.open(TRACE_FILE_PATH, FileAccess.READ)
		if f != null:
			return f.get_as_text()
	return "No previous trace log found."
