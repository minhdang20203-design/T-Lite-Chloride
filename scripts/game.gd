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
var skill_labels := {} # 1/2/3 -> Label hồi chiêu kỹ năng
var boss_bar: ProgressBar
var boss_label: Label
var boss_parts_label: Label
var burst_prompt: Label
var win_banner: Label
var win_button: Button
var count_label: Label
var chat_log: RichTextLabel
var chat_input: LineEdit
var leave_button: Button

var local_player: Player = null
var offline_mode := false # chơi đơn: không cần mạng, tự tạo nhân vật
var boss: Boss = null
var boss_defeated := false
var burst_uses := 0 # Full Burst tối đa 2 lần/trận boss
var burst_active := false
var _burst_t := 0.0
var _burst_hits := [] # {t, dmg, done} — các đòn trong chuỗi Full Burst
var _burst_done := false
var client_joined := false # host: đã có client vào phòng (dùng cho test)
var client_id := 0
var chat_seen := false # host: đã nhận được chat TEST_CHAT_MSG (dùng cho test)
var _chat_open := false
var _leaving := false

func _ready() -> void:
	var my_id := 0
	if _is_connected():
		my_id = multiplayer.get_unique_id()
	var role := "choi don" if offline_mode else ("host" if multiplayer.is_server() else "client")
	GameLog.info("Vao man choi — %s, peer id=%d" % [role, my_id])
	# Sàn đấu (vẽ ô kẻ) + 4 bức tường.
	var arena: Node2D = ArenaScript.new()
	add_child(arena)
	_add_wall(Vector2(ARENA_W / 2, -16), Vector2(ARENA_W + 64, 32))
	_add_wall(Vector2(ARENA_W / 2, ARENA_H + 16), Vector2(ARENA_W + 64, 32))
	_add_wall(Vector2(-16, ARENA_H / 2), Vector2(32, ARENA_H))
	_add_wall(Vector2(ARENA_W + 16, ARENA_H / 2), Vector2(32, ARENA_H))

	# Bù nhìn tập đánh — có sẵn trên mọi máy (cùng node path để gọi RPC).
	# Đặt ở góc sàn để test sát thương, tránh khu vực đấu boss ở giữa.
	dummy = DummyScene.instantiate()
	dummy.offline_mode = offline_mode
	dummy.position = Vector2(200, 200)
	add_child(dummy)

	# Boss Altoilia — có sẵn trên mọi máy (cùng node path để gọi RPC).
	# AI chỉ chạy trên server; các máy khác nhận chiêu qua RPC + HP qua đồng bộ.
	boss = Boss.new()
	boss.name = "Boss"
	boss.game = self
	boss.offline_mode = offline_mode
	boss.position = Vector2(ARENA_W / 2, 420)
	add_child(boss)

	# Nơi chứa nhân vật người chơi + spawner đồng bộ.
	players_root = Node2D.new()
	players_root.name = "Players"
	add_child(players_root)
	if offline_mode:
		# Chơi đơn: không có mạng, tạo nhân vật trực tiếp, không qua spawner.
		var p := _spawn_player(1) as Player
		p.offline_mode = true
		players_root.add_child(p)
		local_player = p
	else:
		spawner = MultiplayerSpawner.new()
		add_child(spawner) # cho spawner vào cây TRƯỚC khi đặt spawn_path
		spawner.spawn_path = players_root.get_path()
		spawner.add_spawnable_scene("res://scenes/player.tscn")
		spawner.spawn_function = _spawn_player
		# Host tự spawn cho mình; client nối vào thì spawn thêm.
		if multiplayer.is_server():
			spawner.spawn(1)

	_build_hud()
	Net.peer_joined.connect(_on_peer_joined)
	Net.peer_left.connect(_on_peer_left)
	Net.server_left.connect(_on_server_left)
	Net.join_failed.connect(_on_join_failed)

func _process(delta: float) -> void:
	if count_label == null:
		return # HUD chưa build xong
	if local_player == null and _is_connected():
		local_player = get_player(multiplayer.get_unique_id())
	if local_player != null:
		hp_bar.value = local_player.hp
		mp_bar.value = local_player.mp
		burst_bar.value = local_player.burst
		_update_skill_labels()
		_update_burst_prompt()
	var count := 0
	for c in players_root.get_children():
		if c is Player:
			count += 1
	count_label.text = "Người chơi: %d/4" % count
	if boss != null:
		boss_bar.value = boss.hp
		if boss.dead:
			boss_label.text = "Altoilia — ĐÃ BỊ ĐÁNH BẠI"
		else:
			boss_label.text = "Altoilia — Phase %d" % boss.phase
		_update_boss_parts_label()
	if burst_active:
		_update_burst(delta)

# Chỉ gọi multiplayer.get_unique_id() khi peer đang nối thật — peer chết
# (nối host thất bại) mà gọi sẽ spam lỗi "multiplayer instance isn't
# currently active" mỗi khung hình.
func _is_connected() -> bool:
	var p := multiplayer.multiplayer_peer
	return p != null and p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

# Vị trí spawn theo peer id (đứng thành hàng ngang giữa sàn).
func spawn_position(peer_id: int) -> Vector2:
	return Vector2(560.0 + float(peer_id - 1) * 80.0, 500.0)

func get_player(peer_id: int) -> Player:
	return players_root.get_node_or_null("P%d" % peer_id) as Player

func get_players() -> Array:
	var out := []
	for c in players_root.get_children():
		if c is Player:
			out.append(c)
	return out

func get_alive_players() -> Array:
	var out := []
	for p in get_players():
		if not (p as Player).dead:
			out.append(p)
	return out

# Thanh Burst trung bình cả đội (chơi đơn: thanh của mình).
func team_burst_average() -> float:
	var players := get_players()
	if players.is_empty():
		return 0.0
	var total := 0.0
	for p in players:
		total += (p as Player).burst
	return total / float(players.size())

# --- Full Burst (GDD §6) ---

# Người chơi bấm F: gửi yêu cầu lên server (hoặc xử lý trực tiếp khi chơi đơn).
func request_burst() -> void:
	if offline_mode:
		_try_begin_burst()
	else:
		rpc("request_burst_rpc")

@rpc("any_peer", "call_local")
func request_burst_rpc() -> void:
	if not offline_mode and not multiplayer.is_server():
		return
	_try_begin_burst()

func _try_begin_burst() -> void:
	if burst_active or boss == null or boss.dead or boss_defeated:
		return
	if burst_uses >= 2:
		GameLog.info("Full Burst đã dùng hết 2 lần/trận.")
		return
	if team_burst_average() < 100.0:
		return
	var n := get_alive_players().size()
	if n <= 0:
		return
	# Sát thương tổng theo số người (công thức tạm): 50 + 30n + 5n^2.
	# 1 người ~85, 2 người ~130, 4 người ~250 (khớp số mẫu GDD §6).
	var total := 50 + 30 * n + 5 * n * n
	if offline_mode:
		_begin_burst(n, total)
	else:
		rpc("_begin_burst", n, total)

@rpc("authority", "call_local")
func _begin_burst(n: int, total: int) -> void:
	burst_uses += 1
	burst_active = true
	_burst_t = 0.0
	_burst_done = false
	# Chuỗi 3 giây: mỗi thành viên tung 1 đòn (cách nhau 0.5s), rồi đòn kết hợp cuối.
	_burst_hits = []
	var per: int = total / (n + 1)
	for i in range(n):
		_burst_hits.append({"t": 0.5 + 0.5 * float(i), "dmg": per, "done": false})
	_burst_hits.append({"t": 0.5 + 0.5 * float(n) + 0.5, "dmg": per, "done": false})
	if boss != null:
		boss.lock(3.0) # boss bị khóa 3s, không đánh lại
	for p in get_players():
		(p as Player).set_invulnerable(3.0) # cả đội bất tử 3s
	GameLog.info("FULL BURST! %d người hợp sức, tổng %d sát thương." % [n, total])

func _update_burst(delta: float) -> void:
	if not burst_active:
		return
	_burst_t += delta
	for hit in _burst_hits:
		if not hit["done"] and _burst_t >= float(hit["t"]):
			hit["done"] = true
			if boss != null:
				boss._hit_flash = 0.2 # chớp hiệu ứng trên mọi máy
				# take_damage tự chặn ở client (chỉ server áp dụng).
				boss.take_damage(int(hit["dmg"]), "")
	if _burst_t >= 3.0 and not _burst_done:
		_burst_done = true
		_end_burst()

func _end_burst() -> void:
	burst_active = false
	for p in get_players():
		var pl := p as Player
		pl.burst = 0.0 # thanh Burst cả đội về 0
		pl.apply_weakened(5.0) # kiệt sức: -20% sát thương 5s
	if boss != null and not boss.dead:
		boss.try_stun(2.0) # boss Choáng 2s sau chuỗi
	GameLog.info("Full Burst kết thúc: cả đội kiệt sức 5s, boss Choáng 2s.")

# --- Thắng boss ---

# Boss (server) gọi khi boss hết HP. Hiện banner thắng + báo cho các máy khác.
func on_boss_died() -> void:
	if boss_defeated:
		return
	boss_defeated = true
	burst_active = false
	_show_win_banner()
	GameLog.info("Đã đánh bại Altoilia!")
	if not offline_mode:
		rpc("_boss_died_remote")

@rpc("authority", "call_local")
func _boss_died_remote() -> void:
	if boss_defeated:
		return
	boss_defeated = true
	burst_active = false
	_show_win_banner()
	GameLog.info("Đã đánh bại Altoilia!")

func _show_win_banner() -> void:
	if win_banner != null:
		win_banner.visible = true
	if win_button != null:
		win_button.visible = true

func _on_win_leave_pressed() -> void:
	if _leaving:
		return
	GameLog.info("Thắng boss, về menu.")
	_leaving = true
	Net.disconnect_peer()
	(get_parent() as Node).show_menu()

# --- Cập nhật HUD ---

func _update_skill_labels() -> void:
	if local_player == null:
		return
	var names := {1: "Chém mạnh", 2: "Đập choáng", 3: "Hồi sức"}
	for n in [1, 2, 3]:
		var label: Label = skill_labels.get(n)
		if label == null:
			continue
		var cd: float = local_player.skill_cd.get(n, 0.0)
		var cost: int = (Player.SKILLS[n] as Dictionary)["mp"]
		if cd > 0.0:
			label.text = "%d %s — %.1fs" % [n, names[n], cd]
		elif local_player.mp < cost:
			label.text = "%d %s — hết MP" % [n, names[n]]
		else:
			label.text = "%d %s — sẵn sàng" % [n, names[n]]

func _update_burst_prompt() -> void:
	if burst_prompt == null or local_player == null:
		return
	var ready := not burst_active and boss != null and not boss.dead and burst_uses < 2 and team_burst_average() >= 100.0
	burst_prompt.visible = ready

func _update_boss_parts_label() -> void:
	if boss == null or boss_parts_label == null:
		return
	var names := {"flower": "Cánh hoa", "music": "Đàn nhạc", "core": "Lõi máy", "crown": "Vương miện"}
	var broken_names: Array = []
	for p_id in ["flower", "music", "core", "crown"]:
		if boss.is_part_broken(p_id):
			broken_names.append(names[p_id])
	if broken_names.is_empty():
		boss_parts_label.text = "Bộ phận: còn đủ 4"
	else:
		boss_parts_label.text = "Đã phá: " + ", ".join(broken_names)

func _spawn_player(data) -> Node:
	var p: Player = PlayerScene.instantiate()
	var pid := int(data)
	p.set_multiplayer_authority(pid)
	p.game = self
	p.name = "P%d" % pid
	p.position = spawn_position(pid)
	return p

func _on_peer_joined(peer_id: int) -> void:
	GameLog.info("P%d da vao phong, spawn nhan vat." % peer_id)
	if multiplayer.is_server():
		spawner.spawn(peer_id)
		rpc("_chat_broadcast", "HỆ THỐNG", "P%d đã vào phòng." % peer_id)
	if peer_id != 1:
		client_joined = true
		client_id = peer_id

func _on_peer_left(peer_id: int) -> void:
	GameLog.info("P%d da roi phong." % peer_id)
	if multiplayer.is_server():
		var node := players_root.get_node_or_null("P%d" % peer_id)
		if node != null:
			spawner.despawn(node)
		rpc("_chat_broadcast", "HỆ THỐNG", "P%d đã rời phòng." % peer_id)

# Host đã thoát -> phòng đóng, về menu.
func _on_server_left() -> void:
	if _leaving:
		return
	GameLog.warn("Host da thoat, phong dong, ve menu.")
	_leaving = true
	Net.disconnect_peer()
	(get_parent() as Node).show_menu()

# Nối host thất bại trong lúc đang ở màn chơi -> về menu, không ở lại
# màn chơi rỗng.
func _on_join_failed() -> void:
	if _leaving:
		return
	GameLog.warn("Ket noi host that bai, ve menu.")
	_leaving = true
	Net.disconnect_peer()
	(get_parent() as Node).show_menu()

func _unhandled_input(event: InputEvent) -> void:
	if offline_mode:
		return # chơi đơn không có chat (chat chỉ dùng khi chơi mạng)
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
	if not _is_connected():
		return
	var sender := "P%d" % multiplayer.get_unique_id()
	rpc("_chat_broadcast", sender, text)

@rpc("any_peer", "call_local")
func _chat_broadcast(sender: String, text: String) -> void:
	if chat_log != null:
		chat_log.text += "[%s] %s\n" % [sender, text]
	print("[CHAT] [%s] %s" % [sender, text])
	GameLog.info("[CHAT] [%s] %s" % [sender, text])
	if text == "TEST_CHAT_MSG":
		chat_seen = true

func _on_leave_pressed() -> void:
	if _leaving:
		return
	GameLog.info("Nhan 'Thoat phong', ve menu.")
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
	burst_label.text = "BURST — bấm F khi đầy để Full Burst"
	top.add_child(burst_label)
	burst_bar = _make_bar(Color(0.95, 0.8, 0.1), 100)
	burst_bar.value = 0
	top.add_child(burst_bar)
	for n in [1, 2, 3]:
		var sl := Label.new()
		sl.add_theme_font_size_override("font_size", 13)
		top.add_child(sl)
		skill_labels[n] = sl

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

	# Thanh HP boss + phase (giữa trên).
	var boss_box := VBoxContainer.new()
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.position = Vector2(-220, 12)
	boss_box.add_theme_constant_override("separation", 2)
	hud.add_child(boss_box)
	boss_label = Label.new()
	boss_label.text = "Altoilia — Phase 1"
	boss_label.horizontal_alignment = 1
	boss_box.add_child(boss_label)
	boss_bar = _make_bar(Color(0.85, 0.15, 0.35), 600)
	boss_bar.custom_minimum_size = Vector2(440, 18)
	boss_box.add_child(boss_bar)
	boss_parts_label = Label.new()
	boss_parts_label.horizontal_alignment = 1
	boss_parts_label.add_theme_font_size_override("font_size", 13)
	boss_box.add_child(boss_parts_label)

	# Nhắc bấm F khi Full Burst sẵn sàng (giữa dưới).
	burst_prompt = Label.new()
	burst_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	burst_prompt.position = Vector2(-180, -220)
	burst_prompt.text = "Bấm F — FULL BURST SẴN SÀNG!"
	burst_prompt.add_theme_font_size_override("font_size", 20)
	burst_prompt.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	burst_prompt.visible = false
	hud.add_child(burst_prompt)

	# Banner thắng + nút về menu (giữa màn hình, chỉ hiện khi thắng).
	win_banner = Label.new()
	win_banner.set_anchors_preset(Control.PRESET_CENTER)
	win_banner.position = Vector2(-220, -60)
	win_banner.text = "Đã đánh bại Altoilia!"
	win_banner.add_theme_font_size_override("font_size", 36)
	win_banner.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	win_banner.visible = false
	hud.add_child(win_banner)
	win_button = Button.new()
	win_button.text = "Về menu"
	win_button.set_anchors_preset(Control.PRESET_CENTER)
	win_button.position = Vector2(-70, 10)
	win_button.custom_minimum_size = Vector2(140, 44)
	win_button.visible = false
	win_button.pressed.connect(_on_win_leave_pressed)
	hud.add_child(win_button)

	var hint := Label.new()
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position = Vector2(-360, -180)
	hint.text = "WASD di chuyển — Chuột: ngắm — Chuột trái: đánh — 1/2/3: kỹ năng Kiếm — Shift/Space: né — Chuột phải: đỡ — F: Full Burst — Enter: chat"
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
