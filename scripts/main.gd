extends Node
# Root của game: chuyển qua lại giữa menu và màn chơi.
# Test headless: chạy với tham số -- --test-host, -- --test-client,
# -- --test-solo, -- --test-fail, -- --test-swing, -- --test-skills,
# -- --test-boss hoặc -- --test-boss-atk để tự kiểm tra mà không cần mở cửa sổ.

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
	elif "--test-solo" in args:
		_run_headless_test("solo")
	elif "--test-fail" in args:
		_run_headless_test("fail")
	elif "--test-swing" in args:
		_run_headless_test("swing")
	elif "--test-skills" in args:
		_run_headless_test("skills")
	elif "--test-boss" in args:
		_run_headless_test("boss")
	elif "--test-boss-atk" in args:
		_run_headless_test("boss-atk")
	elif "--test-ai" in args:
		_run_headless_test("ai")
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

# Vào màn chơi sau khi host/join thành công, hoặc chơi đơn (không cần mạng).
func start_game(offline: bool = false) -> void:
	if menu != null:
		menu.queue_free()
		menu = null
	if game == null:
		game = GameScene.instantiate()
		game.offline_mode = offline
		add_child(game)

# Chơi đơn: vào màn chơi ngay, không cần mạng.
func start_solo() -> void:
	start_game(true)

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
	elif mode == "solo":
		start_solo()
		await get_tree().create_timer(1.0).timeout
		var solo_count := 0
		for c in game.players_root.get_children():
			if c is Player:
				solo_count += 1
		print("[TEST] solo player count=", solo_count, " (expect 1)")
		var me = game.get_player(1)
		print("[TEST] solo tim thay nhan vat: ", me != null)
		var start_x := 0.0
		if me != null:
			start_x = me.position.x
			me.test_move_dir = Vector2.RIGHT
		await get_tree().create_timer(1.2).timeout
		if me != null:
			me.test_move_dir = Vector2.ZERO
		var moved := 0.0
		if me != null:
			moved = me.position.x - start_x
		print("[TEST] solo di chuyen dx=", moved)
		print("[TEST] solo-move: ", "PASS" if moved > 50.0 else "FAIL")
		var hp_before: int = game.dummy.hp
		game.dummy.request_damage(10)
		await get_tree().create_timer(0.5).timeout
		var hp_after: int = game.dummy.hp
		print("[TEST] solo dummy hp truoc=", hp_before, " sau=", hp_after)
		print("[TEST] solo-dummy-damage: ", "PASS" if hp_after == hp_before - 10 else "FAIL")
		print("[TEST_SOLO_DONE]")
	elif mode == "fail":
		# Hồi quy lỗi 15/11: vào màn chơi lúc join chưa nối được host —
		# không được spam lỗi, phải tự về menu khi nối thất bại.
		Net.join("127.0.0.1")
		start_game() # giả lập bấm "Bắt đầu chơi" khi join chưa xong
		await get_tree().create_timer(5.0).timeout
		var back_to_menu: bool = game == null and menu != null
		print("[TEST] fail ve menu sau khi noi that bai: ", back_to_menu)
		print("[TEST] fail-back-to-menu: ", "PASS" if back_to_menu else "FAIL")
		print("[TEST_FAIL_DONE]")
	elif mode == "swing":
		# Kiểm tra đánh thường thật: đứng sát bù nhìn, ngắm đúng, vung kiếm.
		start_solo()
		await get_tree().create_timer(1.0).timeout
		var me = game.get_player(1)
		var dm = game.dummy
		print("[TEST] swing nhan vat: ", me != null, ", bu nhin: ", dm != null)
		# Cự ly gần (40px): kiếm với tới (tầm ~31px + nửa rộng bù nhìn 14px).
		me.position = dm.position + Vector2(-40, 0)
		me.test_aim_angle = (dm.position - me.position).angle()
		var hp0: int = dm.hp
		me._start_swing()
		await get_tree().create_timer(0.12).timeout
		var area = me.get_node("SwordPivot/SwordArea")
		print("[TEST] swing monitoring=", area.monitoring, " overlapping=", area.get_overlapping_bodies().size())
		await get_tree().create_timer(0.4).timeout
		var hp1: int = dm.hp
		print("[TEST] swing gan hp truoc=", hp0, " sau=", hp1)
		print("[TEST] swing-gan: ", "PASS" if hp1 == hp0 - 10 else "FAIL")
		# Cự ly xa (100px): kiếm không với tới, máu không đổi.
		me.position = dm.position + Vector2(-100, 0)
		me.test_aim_angle = (dm.position - me.position).angle()
		var hp2: int = dm.hp
		me._start_swing()
		await get_tree().create_timer(0.5).timeout
		var hp3: int = dm.hp
		print("[TEST] swing xa hp truoc=", hp2, " sau=", hp3)
		print("[TEST] swing-xa-khong-trung: ", "PASS" if hp3 == hp2 else "FAIL")
		print("[TEST_SWING_DONE]")
	elif mode == "skills":
		# Kiểm tra cây Kiếm 3 chiêu + né + đỡ trên bù nhìn.
		start_solo()
		await get_tree().create_timer(1.0).timeout
		var me = game.get_player(1)
		var dm = game.dummy
		print("[TEST] skills nhan vat: ", me != null, ", bu nhin: ", dm != null)
		# Đứng sát bù nhìn, ngắm đúng.
		me.position = dm.position + Vector2(-40, 0)
		me.test_aim_angle = (dm.position - me.position).angle()
		# Kiếm 1: 25 dmg, tốn 10 MP (đánh trúng hồi lại 4 MP -> còn 44), hồi chiêu 3s.
		var hp0: int = dm.hp
		var mp0: int = me.mp
		var ok1: bool = me.cast_skill(1)
		await get_tree().create_timer(0.4).timeout
		print("[TEST] skill1 cast=", ok1, " hp ", hp0, "->", dm.hp, " (expect -25), mp ", mp0, "->", me.mp, " (expect 44)")
		print("[TEST] skill1: ", "PASS" if ok1 and dm.hp == hp0 - 25 and me.mp == 44 else "FAIL")
		# Kiếm 1 đang hồi chiêu thì không dùng lại được.
		var ok1b: bool = me.cast_skill(1)
		print("[TEST] skill1-trong-hoi-chieu cast=", ok1b, " (expect false)")
		print("[TEST] skill1-cd-block: ", "PASS" if not ok1b else "FAIL")
		# Kiếm 2: 12 dmg, tốn 8 MP (đánh trúng hồi lại 4 MP -> còn 46).
		me.mp = 50
		var hp1: int = dm.hp
		var ok2: bool = me.cast_skill(2)
		await get_tree().create_timer(0.4).timeout
		print("[TEST] skill2 cast=", ok2, " hp ", hp1, "->", dm.hp, " (expect -12), mp 50->", me.mp, " (expect 46)")
		print("[TEST] skill2: ", "PASS" if ok2 and dm.hp == hp1 - 12 and me.mp == 46 else "FAIL")
		# Kiếm 3: hồi 20 HP, tốn 15 MP.
		me.hp = 50
		me.mp = 50
		var ok3: bool = me.cast_skill(3)
		print("[TEST] skill3 cast=", ok3, " hp 50->", me.hp, " (expect 70), mp 50->", me.mp, " (expect 35)")
		print("[TEST] skill3: ", "PASS" if ok3 and me.hp == 70 and me.mp == 35 else "FAIL")
		# Thiếu MP thì không dùng được (xóa hồi chiêu trước để test đúng MP).
		me.mp = 5
		me.skill_cd[1] = 0.0
		var ok4: bool = me.cast_skill(1)
		print("[TEST] skill1-thieu-mp cast=", ok4, " (expect false)")
		print("[TEST] skill1-mp-block: ", "PASS" if not ok4 else "FAIL")
		# Né lướt: 128px + bất tử 0.3s (chờ 0.15s: lướt 128px + đi thường ~6px).
		me.mp = 50
		me.position = Vector2(800, 500)
		me.test_move_dir = Vector2.RIGHT
		me.test_aim_angle = 0.0
		var x0: float = me.position.x
		me._try_dash()
		await get_tree().create_timer(0.15).timeout
		me.test_move_dir = Vector2.ZERO
		var dx: float = me.position.x - x0
		print("[TEST] dash dx=", dx, " (expect 100..160), invuln=", me._invuln_timer > 0.0)
		print("[TEST] dash: ", "PASS" if dx > 100.0 and dx < 160.0 and me._invuln_timer > 0.0 else "FAIL")
		# Đỡ: giảm 60% sát thương nhận (20 -> 8).
		me.position = Vector2(800, 500)
		me.hp = 100
		me._invuln_timer = 0.0
		me._try_block()
		var block_on: bool = me.blocking
		me.take_damage(20, Vector2.ZERO, 0.0)
		print("[TEST] block on=", block_on, " hp 100->", me.hp, " (expect 92)")
		print("[TEST] block: ", "PASS" if block_on and me.hp == 92 else "FAIL")
		print("[TEST_SKILLS_DONE]")
	elif mode == "boss":
		# Kiểm tra boss Altoilia: nhận sát thương, đổi phase, phá bộ phận,
		# Tụ lực bị ngắt, Full Burst, hồi sinh, thắng.
		start_solo()
		await get_tree().create_timer(1.0).timeout
		var me = game.get_player(1)
		var boss = game.boss
		boss.ai_enabled = false # tắt AI để boss không đánh trong lúc kiểm tra
		print("[TEST] boss ton tai: ", boss != null, ", hp=", boss.hp if boss != null else -1, " (expect 600), phase=", boss.phase if boss != null else -1)
		# 1. Đánh thường trúng boss qua kiếm (đứng sát, ngắm đúng, tránh bộ phận).
		me.position = boss.position + Vector2(-50, 30)
		me.test_aim_angle = (boss.position - me.position).angle()
		var bhp0: int = boss.hp
		me._start_swing()
		await get_tree().create_timer(0.4).timeout
		print("[TEST] boss swing hp ", bhp0, "->", boss.hp, " (expect -10)")
		print("[TEST] boss-swing: ", "PASS" if boss.hp == bhp0 - 10 else "FAIL")
		# 2. Đổi phase: 300 -> phase 2, 150 -> phase 3; hồi máu không lùi phase.
		boss.debug_set_hp(300)
		print("[TEST] boss phase o 300hp: ", boss.phase, " (expect 2)")
		print("[TEST] boss-phase2: ", "PASS" if boss.phase == 2 else "FAIL")
		boss.debug_set_hp(150)
		print("[TEST] boss phase o 150hp: ", boss.phase, " (expect 3)")
		print("[TEST] boss-phase3: ", "PASS" if boss.phase == 3 else "FAIL")
		boss.debug_set_hp(270)
		print("[TEST] boss phase sau khi hoi len 270hp: ", boss.phase, " (expect 3)")
		print("[TEST] boss-phase-khong-lui: ", "PASS" if boss.phase == 3 else "FAIL")
		# 3. Phá bộ phận: cánh hoa (100 HP) -> mất Lốc xoáy.
		var flower = boss.get_part("flower")
		flower.take_damage(100, "")
		await get_tree().create_timer(0.2).timeout
		var pool: Array = boss.available_attacks()
		print("[TEST] pha canh hoa: broken=", flower.broken, ", pool con tornado=", "tornado" in pool, " (expect true/false)")
		print("[TEST] boss-part-flower: ", "PASS" if flower.broken and not ("tornado" in pool) else "FAIL")
		# Phá 3 bộ phận còn lại -> mất Sóng nhạc, Tia laser, Tụ lực.
		boss.get_part("music").take_damage(100, "")
		boss.get_part("core").take_damage(100, "")
		boss.get_part("crown").take_damage(100, "")
		await get_tree().create_timer(0.2).timeout
		pool = boss.available_attacks()
		print("[TEST] pha 3 bo phan con lai: rings=", "rings" in pool, " laser=", "laser" in pool, " charge=", "charge" in pool, " (expect false/false/false)")
		print("[TEST] boss-parts-rest: ", "PASS" if not ("rings" in pool) and not ("laser" in pool) and not ("charge" in pool) else "FAIL")
		# 4. Tụ lực bị Đập choáng ngắt: ép boss tụ lực, dùng Kiếm 2 vào boss.
		boss.debug_set_hp(400)
		boss.debug_start_attack("charge")
		await get_tree().create_timer(0.5).timeout
		var charging: bool = boss._attack.get("id", "") == "charge"
		me.position = boss.position + Vector2(-50, 30)
		me.test_aim_angle = (boss.position - me.position).angle()
		me.mp = 50
		me.skill_cd[2] = 0.0
		var bhp1: int = boss.hp
		me.cast_skill(2)
		await get_tree().create_timer(0.5).timeout
		var charge_gone: bool = boss._attack.is_empty()
		print("[TEST] charge dang chay: ", charging, ", sau skill2: attack rong=", charge_gone, " hp ", bhp1, "->", boss.hp, " (expect -12, khong hoi mau)")
		print("[TEST] boss-charge-interrupt: ", "PASS" if charging and charge_gone and boss.hp == bhp1 - 12 else "FAIL")
		# 5. Full Burst: thanh Burst 100 -> kích hoạt, gây ~84 dmg (solo: 2 đòn x 42).
		me.burst = 100.0
		var bhp2: int = boss.hp
		game.request_burst()
		await get_tree().create_timer(3.5).timeout
		print("[TEST] burst uses=", game.burst_uses, " (expect 1), boss hp ", bhp2, "->", boss.hp, " (expect -84), burst cua minh=", me.burst, " (expect 0)")
		print("[TEST] burst: ", "PASS" if game.burst_uses == 1 and boss.hp == bhp2 - 84 and me.burst == 0.0 else "FAIL")
		# 6. Hồi sinh: người chơi chết -> 3s sau hồi sinh đầy HP, boss giữ HP.
		me.hp = 5
		me._invuln_timer = 0.0
		me.take_damage(20, Vector2.ZERO, 0.0)
		var died: bool = me.dead
		var bhp3: int = boss.hp
		await get_tree().create_timer(3.5).timeout
		print("[TEST] chet: ", died, ", sau 3.5s: dead=", me.dead, " hp=", me.hp, " (expect 100), boss hp=", boss.hp, " (expect ", bhp3, ")")
		print("[TEST] respawn: ", "PASS" if died and not me.dead and me.hp == 100 and boss.hp == bhp3 else "FAIL")
		# 7. Thắng: boss hết HP -> banner thắng hiện.
		# (Xóa debuff kiệt sức sau Burst để cú đánh gây đủ 10 dmg.)
		me._weakened_timer = 0.0
		boss.debug_set_hp(10)
		me.position = boss.position + Vector2(-50, 30)
		me.test_aim_angle = (boss.position - me.position).angle()
		me._start_swing()
		await get_tree().create_timer(0.5).timeout
		print("[TEST] boss hp=", boss.hp, " dead=", boss.dead, " boss_defeated=", game.boss_defeated, " banner=", game.win_banner.visible)
		print("[TEST] win: ", "PASS" if boss.dead and game.boss_defeated and game.win_banner.visible else "FAIL")
		print("[TEST_BOSS_DONE]")
	elif mode == "boss-atk":
		# Kiểm tra 6 chiêu của boss gây sát thương thật lên người chơi.
		# Tắt AI để boss chỉ dùng chiêu được ép; trước mỗi chiêu reset vị trí/HP.
		start_solo()
		await get_tree().create_timer(1.0).timeout
		var me = game.get_player(1)
		var boss = game.boss
		boss.ai_enabled = false
		var reset_player := func(pos: Vector2) -> void:
			me.position = pos
			me.hp = 100
			me.dead = false
			me._invuln_timer = 0.0
			me._stagger_timer = 0.0
			me._slow_timer = 0.0
			me._kb_timer = 0.0
		# 1. Gai đất: người chơi đứng trên đường gai -> 15 dmg.
		reset_player.call(boss.position + Vector2(300, 0))
		boss.debug_start_attack("spikes")
		await get_tree().create_timer(1.2).timeout
		print("[TEST] spikes hp 100->", me.hp, " (expect 85)")
		print("[TEST] atk-spikes: ", "PASS" if me.hp == 85 else "FAIL")
		# 2. AoE tròn: vòng đỏ nổ tại chỗ người chơi đứng -> 20 dmg.
		reset_player.call(boss.position + Vector2(300, 0))
		boss.debug_start_attack("aoe")
		await get_tree().create_timer(2.0).timeout
		print("[TEST] aoe hp 100->", me.hp, " (expect 80)")
		print("[TEST] atk-aoe: ", "PASS" if me.hp == 80 else "FAIL")
		# 3. Sóng nhạc: 3 vòng lan ra, người chơi đứng yên trúng cả 3 -> 36 dmg.
		reset_player.call(boss.position + Vector2(300, 0))
		boss.debug_start_attack("rings")
		await get_tree().create_timer(3.5).timeout
		print("[TEST] rings hp 100->", me.hp, " (expect 64)")
		print("[TEST] atk-rings: ", "PASS" if me.hp == 64 else "FAIL")
		# 4. Tia laser: quét qua chỗ người chơi đứng -> 25 dmg.
		reset_player.call(boss.position + Vector2(300, 0))
		boss.debug_start_attack("laser")
		await get_tree().create_timer(2.8).timeout
		print("[TEST] laser hp 100->", me.hp, " (expect 75)")
		print("[TEST] atk-laser: ", "PASS" if me.hp == 75 else "FAIL")
		# 5. Lốc xoáy: lốc đi tới chỗ người chơi, tick 10 dmg sau ~2.6s.
		reset_player.call(boss.position + Vector2(200, 0))
		boss.debug_start_attack("tornado")
		await get_tree().create_timer(3.0).timeout
		print("[TEST] tornado hp 100->", me.hp, " (expect 90, 1 tick)")
		print("[TEST] atk-tornado: ", "PASS" if me.hp == 90 else "FAIL")
		# 6. Tụ lực không bị ngắt: boss hồi 120 HP sau 3s.
		boss.debug_set_hp(300)
		boss.debug_start_attack("charge")
		await get_tree().create_timer(3.5).timeout
		print("[TEST] charge heal hp 300->", boss.hp, " (expect 420)")
		print("[TEST] atk-charge-heal: ", "PASS" if boss.hp == 420 else "FAIL")
		print("[TEST_BOSS_ATK_DONE]")
	elif mode == "ai":
		# Kiểm tra AI boss tự chạy: không ép chiêu, để boss tự chọn chiêu.
		# Người chơi đứng yên ở điểm spawn (boss sẽ nhắm vào đó).
		start_solo()
		await get_tree().create_timer(12.0).timeout
		var boss = game.boss
		var me = game.get_player(1)
		print("[TEST] ai attacks_started=", boss.attacks_started, " (expect >= 2), boss hp=", boss.hp, ", player hp=", me.hp if me != null else -1)
		print("[TEST] ai-autonomous: ", "PASS" if boss.attacks_started >= 2 else "FAIL")
		print("[TEST_AI_DONE]")
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
