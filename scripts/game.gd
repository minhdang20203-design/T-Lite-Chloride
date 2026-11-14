extends Node2D
# Màn chơi GĐ1: sàn đấu + tường, spawn người chơi qua MultiplayerSpawner,
# bù nhìn tập đánh, HUD (HP/MP/Burst), chat nhanh.
# Host thoát -> client nhận server_disconnected -> về menu ("phòng đóng").

const PlayerScene := preload("res://scenes/player.tscn")
const DummyScene := preload("res://scenes/dummy.tscn")
const ArenaScript := preload("res://scripts/arena.gd")

const ARENA_W := 1600
const ARENA_H := 1000

var players_root: Node2D
var spawner: MultiplayerSpawner
var dummy: Dummy = null
var hud: CanvasLayer
var hp_bar: ProgressBar
var mp_bar: ProgressBar
var burst_bar: ProgressBar
var count_label: Label
var chat_log: RichTextLabel
var chat_input: LineEdit
var leave_button: Button

var local_player: Player = null
var client_joined := false # host: đã có client vào phòng (dùng cho test)
var client_id := 0
var chat_seen := false # host: đã nhận được chat TEST_CHAT_MSG (dùng cho test)
var _chat_open := false
var _leaving := false

func _ready() -> void:
	# Sàn đấu (vẽ ô kẻ) + 4 bức tường.
	var arena: Node2D = ArenaScript.new()
	add_child(arena)
	_add_wall(Vector2(ARENA_W / 2, -16), Vector2(ARENA_W + 64, 32))
	_add_wall(Vector2(ARENA_W / 2, ARENA_H + 16), Vector2(ARENA_W + 64, 32))
	_add_wall(Vector2(-16, ARENA_H / 2), Vector2(32, ARENA_H))
	_add_wall(Vector2(ARENA_W + 16, ARENA_H / 2), Vector2(32, ARENA_H))

	# Bù nhìn tập đánh — có sẵn trên mọi máy (cùng node path để gọi RPC).
	dummy = DummyScene.instantiate()
	dummy.position = Vector2(ARENA_W / 2, 350)
	add_child(dummy)

	# Nơi chứa nhân vật người chơi + spawner đồng bộ.
	players_root = Node2D.new()
	players_root.name = "Players"
	add_child(players_root)
	spawner = MultiplayerSpawner.new()
	add_child(spawner) # cho spawner vào cây TRƯỚC khi đặt spawn_path
	spawner.spawn_path = players_root.get_path()
	spawner.add_spawnable_scene("res://scenes/player.tscn")
	spawner.spawn_function = _spawn_player

	_build_hud()

	# Host tự spawn cho mình; client nối vào thì spawn thêm.
	if multiplayer.is_server():
		spawner.spawn(1)
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Net.server_left.connect(_on_server_left)

func _process(_delta: float) -> void:
	if count_label == null:
		return # HUD chưa build xong
	if local_player == null:
		local_player = get_player(multiplayer.get_unique_id())
	if local_player != null:
		hp_bar.value = local_player.hp
		mp_bar.value = local_player.mp
		burst_bar.value = local_player.burst
	var count := 0
	for c in players_root.get_children():
		if c is Player:
			count += 1
	count_label.text = "Người chơi: %d/4" % count

# Vị trí spawn theo peer id (đứng thành hàng ngang giữa sàn).
func spawn_position(peer_id: int) -> Vector2:
	return Vector2(560.0 + float(peer_id - 1) * 80.0, 500.0)

func get_player(peer_id: int) -> Player:
	return players_root.get_node_or_null("P%d" % peer_id) as Player

func _spawn_player(data) -> Node:
	var p: Player = PlayerScene.instantiate()
	var pid := int(data)
	p.set_multiplayer_authority(pid)
	p.name = "P%d" % pid
	p.position = spawn_position(pid)
	return p

func _on_peer_joined(peer_id: int) -> void:
	if multiplayer.is_server():
		spawner.spawn(peer_id)
		rpc("_chat_broadcast", "HỆ THỐNG", "P%d đã vào phòng." % peer_id)
	if peer_id != 1:
		client_joined = true
		client_id = peer_id

func _on_peer_left(peer_id: int) -> void:
	if multiplayer.is_server():
		var node := players_root.get_node_or_null("P%d" % peer_id)
		if node != null:
			spawner.despawn(node)
		rpc("_chat_broadcast", "HỆ THỐNG", "P%d đã rời phòng." % peer_id)

# Host đã thoát -> phòng đóng, về menu.
func _on_server_left() -> void:
	if _leaving:
		return
	_leaving = true
	Net.disconnect_peer()
	(get_parent() as Node).show_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("chat"):
		if not _chat_open:
			_chat_open = true
			chat_input.visible = true
			chat_input.grab_focus()
			get_viewport().set_input_as_handled()

func _send_chat() -> void:
	var text := chat_input.text.strip_edges()
	chat_input.text = ""
	chat_input.visible = false
	chat_input.release_focus()
	_chat_open = false
	if text.is_empty():
		return
	var sender := "P%d" % multiplayer.get_unique_id()
	rpc("_chat_broadcast", sender, text)

@rpc("any_peer", "call_local")
func _chat_broadcast(sender: String, text: String) -> void:
	if chat_log != null:
		chat_log.text += "[%s] %s\n" % [sender, text]
	print("[CHAT] [%s] %s" % [sender, text])
	if text == "TEST_CHAT_MSG":
		chat_seen = true

func _on_leave_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	Net.disconnect_peer()
	(get_parent() as Node).show_menu()

# --- Xây HUD bằng code (giữ scene gọn) ---

func _make_bar(color: Color, max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = max_value
	bar.value = max_value
	bar.custom_minimum_size = Vector2(220, 16)
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top.position = Vector2(12, 12)
	top.add_theme_constant_override("separation", 4)
	hud.add_child(top)
	var hp_label := Label.new()
	hp_label.text = "HP"
	top.add_child(hp_label)
	hp_bar = _make_bar(Color(0.85, 0.2, 0.2), 100)
	top.add_child(hp_bar)
	var mp_label := Label.new()
	mp_label.text = "MP"
	top.add_child(mp_label)
	mp_bar = _make_bar(Color(0.2, 0.4, 0.9), 50)
	top.add_child(mp_bar)
	var burst_label := Label.new()
	burst_label.text = "BURST (GĐ1 chỉ tích, chưa kích hoạt)"
	top.add_child(burst_label)
	burst_bar = _make_bar(Color(0.95, 0.8, 0.1), 100)
	burst_bar.value = 0
	top.add_child(burst_bar)

	count_label = Label.new()
	count_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	count_label.position = Vector2(-170, 12)
	count_label.text = "Người chơi: 1/4"
	hud.add_child(count_label)

	leave_button = Button.new()
	leave_button.text = "Thoát phòng"
	leave_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	leave_button.position = Vector2(-140, 40)
	leave_button.pressed.connect(_on_leave_pressed)
	hud.add_child(leave_button)

	var hint := Label.new()
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-360, -180)
	hint.text = "WASD di chuyển — Chuột: ngắm — Chuột trái: đánh — Enter: chat"
	hud.add_child(hint)

	chat_log = RichTextLabel.new()
	chat_log.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_log.position = Vector2(12, -170)
	chat_log.custom_minimum_size = Vector2(520, 130)
	chat_log.scroll_following = true
	chat_log.bbcode_enabled = false
	chat_log.text = ""
	hud.add_child(chat_log)

	chat_input = LineEdit.new()
	chat_input.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_input.position = Vector2(12, -36)
	chat_input.custom_minimum_size = Vector2(520, 28)
	chat_input.placeholder_text = "Nhập tin nhắn rồi Enter để gửi..."
	chat_input.visible = false
	chat_input.text_submitted.connect(func(_t: String) -> void: _send_chat())
	hud.add_child(chat_input)

func _add_wall(center: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.collision_layer = 8 # layer 4: tường
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = center
	wall.add_child(shape)
	add_child(wall)
