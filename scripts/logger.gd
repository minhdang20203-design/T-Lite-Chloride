class_name GameLog
# Ghi log của game ra file game.log trong thư mục logs của game.
# Dùng class tĩnh (không cần autoload) để mọi script gọi GameLog.info(...).
# File log: user://logs/game.log
# Trên Windows: %APPDATA%\Godot\app_userdata\T-Lite Chloride\logs\game.log
# Godot tự ghi thêm file godot.log (lỗi của engine) trong cùng thư mục.

const LOG_PATH := "user://logs/game.log"
const GAME_VERSION := "GĐ1"

static var _started := false

static func log_path() -> String:
	return ProjectSettings.globalize_path(LOG_PATH)

static func info(msg: String) -> void:
	_write("INFO", msg)

static func warn(msg: String) -> void:
	_write("WARN", msg)

static func error(msg: String) -> void:
	_write("ERROR", msg)

# Ghi dòng mở đầu phiên chơi (gọi 1 lần khi game khởi động).
static func begin_session() -> void:
	if _started:
		return
	_started = true
	_ensure_dir()
	var f := _open_append()
	if f == null:
		push_error("[GameLog] Khong mo duoc file log: " + LOG_PATH)
		return
	f.store_string("\n===== T-Lite Chloride %s | %s =====\n" % [GAME_VERSION, Time.get_datetime_string_from_system()])
	f.close()
	info("File log: " + log_path())

static func _write(level: String, msg: String) -> void:
	var line := "[%s] [%s] %s" % [Time.get_time_string_from_system(), level, msg]
	print(line)
	_ensure_dir()
	var f := _open_append()
	if f == null:
		return
	f.store_string(line + "\n")
	f.close()

# Mở file để ghi thêm vào cuối. Lưu ý: FileAccess.READ_WRITE KHÔNG tạo
# file mới (mở file chưa tồn tại sẽ lỗi), nên file chưa có thì mở bằng
# WRITE (tự tạo file), file đã có thì mở READ_WRITE + seek về cuối.
static func _open_append() -> FileAccess:
	if FileAccess.file_exists(LOG_PATH):
		var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
		return f
	return FileAccess.open(LOG_PATH, FileAccess.WRITE)

static func _ensure_dir() -> void:
	var dir := ProjectSettings.globalize_path("user://logs")
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
