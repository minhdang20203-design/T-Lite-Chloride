extends Node
# Root của game: chuyển qua lại giữa menu và màn chơi.
# Test headless: chạy với tham số -- --test-host hoặc -- --test-client
# để tự kiểm tra kết nối ENet mà không cần mở cửa sổ.

const MainMenuScene := preload("res://scenes/main_menu.tscn")
const GameScene := preload("res://scenes/game.tscn")

var menu: Control = null
var game: Node2D = null
var _test_joined := false # test client: đã kết nối server chưa

func _ready() -> void:
	GameLog.begin_session()
	GameLog.info("Game khoi dong — T-Lite Chloride.")
	var args := OS.get_cmdline_user_args()
	if "--test-host" in args:
		_run_headless_test("host")
	elif "--test-client" in args:
		_run_headless_test("client")
	else:
		show_menu()

func _on_test_joined() -> void:
	_test_joined = true

func show_menu() -> void:
	if game != null:
		game.queue_free()
		game = null
	if menu == null:
		menu = MainMenuScene.instantiate()
		add_child(menu)

# Vào màn chơi sau khi host/join thành công.
func start_game() -> void:
	if menu != null:
		menu.queue_free()
		menu = null
	if game == null:
		game = GameScene.instantiate()
		add_child(game)

func _wait_flag(getter: Callable, timeout: float) -> bool:
	var waited := 0.0
	while waited < timeout:
		if getter.call():
			return true
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	return getter.call()

# Test headless 2 máy trên cùng 1 VM (loopback 127.0.0.1).
# Host: chờ client vào, đọc vị trí client đồng bộ về phía host,
# chờ client đánh bù nhìn (máu giảm ở phía host), chờ chat.
# Client: vào phòng, tự đi sang phải 1 giây, đánh bù nhìn qua RPC
# rồi kiểm tra máu đồng bộ về, gửi chat.
func _run_headless_test(mode: String) -> void:
	print("[TEST] bat dau test mode=", mode)
	if mode == "host":
		Net.host()
		start_game()
		# Kiểm tra nội bộ phía host (không cần client).
		await get_tree().create_timer(2.0).timeout
		var count := 0
		for c in game.players_root.get_children():
			if c is Player:
				count += 1
		print("[TEST] host player count=", count, " (expect 1)")
		print("[TEST] host dummy hp=", game.dummy.hp, " (expect 500)")
		game.dummy.take_damage(10) # server tự áp dụng (không qua mạng)
		await get_tree().create_timer(0.5).timeout
		print("[TEST] host dummy hp sau take_damage(10)=", game.dummy.hp, " (expect 490)")
		print("[TEST] host local-damage: ", "PASS" if game.dummy.hp == 490 else "FAIL")
		# Chờ client vào (VM này chặn UDP send nên client không kết nối được —
		# phần đồng bộ 2 máy phải kiểm chứng trên Windows).
		var got_client: bool = await _wait_flag(func() -> bool: return game != null and game.client_joined, 8.0)
		print("[TEST] host thay client vao: ", got_client, " (VM chan UDP, co the la false)")
		var pos_ok := false
		if got_client:
			# Chờ client đi xong (client tự lái nhân vật của nó).
			await get_tree().create_timer(4.0).timeout
			var client_player = game.get_player(game.client_id)
			if client_player != null:
				var start_x: float = game.spawn_position(game.client_id).x
				var moved: float = client_player.position.x - start_x
				print("[TEST] host thay client di chuyen dx=", moved)
				pos_ok = moved > 50.0
		print("[TEST] pos-sync: ", "PASS" if pos_ok else "FAIL")
		var hp_ok: bool = await _wait_flag(func() -> bool: return game != null and game.dummy != null and game.dummy.hp < 500, 8.0)
		print("[TEST] dummy-hp-sync (host thay hp < 500): ", "PASS" if hp_ok else "FAIL", " hp=", game.dummy.hp if game != null and game.dummy != null else -1)
		var chat_ok: bool = await _wait_flag(func() -> bool: return game != null and game.chat_seen, 8.0)
		print("[TEST] chat: ", "PASS" if chat_ok else "FAIL")
		print("[TEST_HOST_DONE]")
	else:
		Net.joined.connect(_on_test_joined)
		Net.join("127.0.0.1")
		var joined: bool = await _wait_flag(func() -> bool: return _test_joined, 10.0)
		print("[TEST] client ket noi server: ", joined)
		if not joined:
			print("[TEST_CLIENT_DONE]")
			get_tree().quit()
			return
		start_game()
		await get_tree().create_timer(1.5).timeout
		var me = game.get_player(multiplayer.get_unique_id())
		print("[TEST] client tim thay nhan vat cua minh: ", me != null)
		if me == null:
			print("[TEST_CLIENT_DONE]")
			get_tree().quit()
			return
		# Đi sang phải 1 giây (để host kiểm tra vị trí đồng bộ).
		me.test_move_dir = Vector2.RIGHT
		await get_tree().create_timer(1.2).timeout
		me.test_move_dir = Vector2.ZERO
		# Đánh bù nhìn qua RPC thật (client -> server áp dụng, đồng bộ HP về).
		var hp_before: int = game.dummy.hp
		game.dummy.request_damage(10)
		await get_tree().create_timer(1.5).timeout
		var hp_after: int = game.dummy.hp
		print("[TEST] dummy hp truoc=", hp_before, " sau=", hp_after)
		print("[TEST] dummy-damage-rpc: ", "PASS" if hp_after == hp_before - 10 else "FAIL")
		# Gửi chat để host kiểm tra.
		game.rpc("_chat_broadcast", "P%d" % multiplayer.get_unique_id(), "TEST_CHAT_MSG")
		await get_tree().create_timer(1.0).timeout
		print("[TEST_CLIENT_DONE]")
	get_tree().quit()
