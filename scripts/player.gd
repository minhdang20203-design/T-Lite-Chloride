extends CharacterBody2D
class_name Player
# Nhân vật người chơi GĐ2: WASD di chuyển, chuột ngắm, chuột trái đánh thường,
# phím 1/2/3 dùng cây Kiếm 3 chiêu, Shift/Space né lướt, giữ chuột phải đỡ,
# F kích hoạt Full Burst (khi thanh Burst đội đầy).
# Chỉ peer có authority mới điều khiển nhân vật này; vị trí + góc ngắm +
# trạng thái vung kiếm + HP/MP/Burst được đồng bộ qua MultiplayerSynchronizer.
# Số liệu theo GDD §3: HP 100, MP 50, ATK 10, DEF 0, tốc chạy 3.2 ô/giây.
# Đánh thường 10 sát thương, +4 MP/đòn trúng, Burst tích 1 điểm / 50 sát thương.

const SPEED := 200.0 # ~3.2 ô/giây với ô 64px
const ATK := 10
const ATTACK_COOLDOWN := 0.45
const SWING_TIME := 0.25
const DEF := 0 # giáp hiện tại (GDD §3: DEF 0)

# Cây Kiếm 3 chiêu (GDD §3).
const SKILLS := {
	1: {"name": "Chém mạnh", "dmg": 25, "mp": 10, "cd": 3.0},
	2: {"name": "Đập choáng", "dmg": 12, "mp": 8, "cd": 8.0},
	3: {"name": "Hồi sức", "dmg": 0, "mp": 15, "cd": 12.0},
}
const SKILL_HEAL := 20 # Kiếm 3 hồi 20 HP
# Né lướt: 128px (2 ô), bất tử 0.3s, hồi chiêu 1.5s, không tốn MP.
const DASH_TIME := 0.12
const DASH_DIST := 128.0
const DASH_SPEED := DASH_DIST / DASH_TIME
const DASH_CD := 1.5
# Đỡ (chỉ Kiếm): giảm 60% sát thương trong 0.5s, hồi chiêu 2s.
const BLOCK_TIME := 0.5
const BLOCK_CD := 2.0

var max_hp := 100
var hp := 100
var max_mp := 50
var mp := 50
var burst := 0.0 # 0..100
var aim_angle := 0.0 # đồng bộ
var swinging := false # đồng bộ
var dead := false # đồng bộ (chết -> hồi sinh sau 3s)
var test_move_dir := Vector2.ZERO # chỉ dùng cho test headless
var test_aim_angle = null # chỉ dùng cho test headless: ép góc ngắm thay cho chuột
var offline_mode := false # chơi đơn: tự điều khiển, không cần authority mạng
var game: Node2D = null # game.gd gắn khi spawn (để gọi Full Burst, vị trí hồi sinh)

var skill_cd := {1: 0.0, 2: 0.0, 3: 0.0} # hồi chiêu còn lại từng kỹ năng
var dash_cd := 0.0
var block_cd := 0.0
var blocking := false
var _attack_damage := ATK # sát thương của cú vung hiện tại (thường / kỹ năng)
var _attack_effect := "" # "" hoặc "stun" (Đập choáng)

var _swing_timer := 0.0
var _cooldown := 0.0
var _dash_timer := 0.0
var _dash_dir := Vector2.RIGHT
var _invuln_timer := 0.0 # bất tử (né lướt / Full Burst)
var _weakened_timer := 0.0 # sau Full Burst: -20% sát thương 5s
var _slow_timer := 0.0 # Sóng nhạc: chậm 50% trong 1s
var _stagger_timer := 0.0 # Gai đất hất ngã: không di chuyển 0.4s
var _kb_timer := 0.0 # hất văng
var _kb_dir := Vector2.ZERO
var _kb_speed := 0.0
var _block_timer := 0.0
var _respawn_timer := 0.0
var _hit_flash := 0.0
var _heal_flash := 0.0

const PLAYER_COLORS := [
	Color(0.25, 0.5, 0.95), # P1 xanh dương
	Color(0.25, 0.8, 0.35), # P2 xanh lá
	Color(0.95, 0.35, 0.3), # P3 đỏ
	Color(0.95, 0.75, 0.15), # P4 vàng
]

# Chơi đơn: không có mạng nên không có authority — nhân vật của mình thì
# mình tự điều khiển, không cần chờ server cấp quyền.
func _controls_mine() -> bool:
	return offline_mode or is_multiplayer_authority()

func _enter_tree() -> void:
	# Cấu hình đồng bộ sớm (trước khung hình đầu tiên).
	var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(".:position")
	cfg.add_property(".:aim_angle")
	cfg.add_property(".:swinging")
	cfg.add_property(".:hp")
	cfg.add_property(".:mp")
	cfg.add_property(".:burst")
	cfg.add_property(".:dead")
	sync.replication_config = cfg

func _ready() -> void:
	var pid := get_multiplayer_authority()
	$Sprite2D.texture = PlaceholderArt.make_player_texture(PLAYER_COLORS[pid % PLAYER_COLORS.size()])
	$SwordPivot/SwordSprite.texture = PlaceholderArt.make_sword_texture()
	$NameLabel.text = "P%d" % pid
	$NameLabel.position = Vector2(-32, -38)
	$NameLabel.size = Vector2(64, 16)
	# Chỉ nhân vật của mình mới có camera.
	$Camera2D.enabled = _controls_mine()
	if _controls_mine():
		$Camera2D.make_current()
	$SwordPivot/SwordArea.monitoring = false
	$SwordPivot/SwordArea.body_entered.connect(_on_sword_body_entered)

func _unhandled_input(event: InputEvent) -> void:
	if not _controls_mine() or dead:
		return
	if event.is_action_pressed("skill_1"):
		cast_skill(1)
	elif event.is_action_pressed("skill_2"):
		cast_skill(2)
	elif event.is_action_pressed("skill_3"):
		cast_skill(3)
	elif event.is_action_pressed("dash"):
		_try_dash()
	elif event.is_action_pressed("block"):
		_try_block()
	elif event.is_action_pressed("burst"):
		_try_burst()

func _physics_process(delta: float) -> void:
	if not _controls_mine():
		return
	# Hồi chiêu / hiệu ứng (chạy cả khi chết để hồi sinh đúng giờ).
	_cooldown = maxf(_cooldown - delta, 0.0)
	for k in skill_cd:
		skill_cd[k] = maxf(skill_cd[k] - delta, 0.0)
	dash_cd = maxf(dash_cd - delta, 0.0)
	block_cd = maxf(block_cd - delta, 0.0)
	if _block_timer > 0.0:
		_block_timer -= delta
		if _block_timer <= 0.0:
			blocking = false
	if _invuln_timer > 0.0:
		_invuln_timer -= delta
	if _weakened_timer > 0.0:
		_weakened_timer -= delta
	if _slow_timer > 0.0:
		_slow_timer -= delta
	if _stagger_timer > 0.0:
		_stagger_timer -= delta
	if _kb_timer > 0.0:
		_kb_timer -= delta
	if dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return
	# Ngắm theo chuột (hoặc góc ép từ test headless).
	if test_aim_angle != null:
		aim_angle = test_aim_angle
	else:
		aim_angle = (get_global_mouse_position() - global_position).angle()
	# Di chuyển WASD (hoặc hướng ép từ test headless).
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if test_move_dir != Vector2.ZERO:
		dir = test_move_dir
	if _stagger_timer > 0.0:
		dir = Vector2.ZERO # hất ngã: không di chuyển được
	var speed := SPEED
	if _slow_timer > 0.0:
		speed *= 0.5 # Sóng nhạc làm chậm
	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * DASH_SPEED
	elif _kb_timer > 0.0:
		velocity = _kb_dir * _kb_speed
	else:
		velocity = dir * speed
	move_and_slide()
	# Đánh: chuột trái, có hồi chiêu.
	if _cooldown <= 0.0 and Input.is_action_just_pressed("attack"):
		_start_swing()

func _process(delta: float) -> void:
	# Xoay kiếm theo hướng ngắm; khi vung thì quét một vòng cung.
	var offset := 0.0
	if swinging:
		if _controls_mine():
			_swing_timer -= delta
			var progress := 1.0 - (_swing_timer / SWING_TIME)
			offset = lerpf(-1.3, 1.3, clampf(progress, 0.0, 1.0))
			if _swing_timer <= 0.0:
				swinging = false
				_attack_damage = ATK
				_attack_effect = ""
		else:
			offset = 0.6 # máy khác chỉ thấy tư thế vung
	$SwordPivot.rotation = aim_angle + offset
	# Chỉ máy của mình mới bật vùng quét kiếm (tránh tính sát thương 2 lần).
	$SwordPivot/SwordArea.monitoring = swinging and _controls_mine() and not dead
	# Màu nhân vật theo trạng thái: chết (xám) > trúng đòn (đỏ) >
	# hồi máu (xanh lá) > đỡ (xanh dương).
	var mod := Color(1, 1, 1)
	if dead:
		mod = Color(0.45, 0.45, 0.5)
	elif _hit_flash > 0.0:
		mod = Color(1.6, 0.5, 0.5)
		_hit_flash -= delta
	elif _heal_flash > 0.0:
		mod = Color(0.6, 1.6, 0.6)
		_heal_flash -= delta
	elif blocking:
		mod = Color(0.6, 0.8, 1.4)
	$Sprite2D.modulate = mod
	if blocking:
		queue_redraw()

func _draw() -> void:
	# Vòng cung đỡ trước mặt khi đang đỡ.
	if blocking:
		draw_arc(Vector2.ZERO, 28.0, aim_angle - 1.1, aim_angle + 1.1, 20, Color(0.45, 0.7, 1.0, 0.9), 4.0)

func _start_swing(damage: int = ATK, effect: String = "") -> void:
	_attack_damage = damage
	_attack_effect = effect
	swinging = true
	_swing_timer = SWING_TIME
	_cooldown = ATTACK_COOLDOWN

func _on_sword_body_entered(body: Node2D) -> void:
	if not _controls_mine():
		return
	if dead:
		return
	# Đánh được mọi mục tiêu có request_damage: bù nhìn, boss, bộ phận boss.
	if body.has_method("request_damage"):
		var dmg := _attack_damage
		if _weakened_timer > 0.0:
			dmg = int(dmg * 0.8) # sau Full Burst: -20% sát thương 5s
		dmg = maxi(dmg, 1)
		body.request_damage(dmg, _attack_effect)
		mp = mini(mp + 4, max_mp) # hồi MP khi đánh trúng
		burst = minf(burst + float(dmg) / 50.0, 100.0) # 1 điểm Burst / 50 sát thương

# --- Cây Kiếm 3 chiêu ---

func cast_skill(n: int) -> bool:
	if dead:
		return false
	var s: Dictionary = SKILLS.get(n, {})
	if s.is_empty():
		return false
	if float(skill_cd.get(n, 0.0)) > 0.0:
		return false # đang hồi chiêu
	var cost: int = s["mp"]
	if mp < cost:
		GameLog.info("P%d hết MP, không dùng được %s." % [get_multiplayer_authority(), s["name"]])
		return false
	mp -= cost
	skill_cd[n] = float(s["cd"])
	if n == 3:
		# Hồi sức: hồi máu ngay, không cần vung kiếm.
		var healed := mini(SKILL_HEAL, max_hp - hp)
		hp = mini(hp + SKILL_HEAL, max_hp)
		burst = minf(burst + float(SKILL_HEAL) / 30.0, 100.0) # 1 điểm Burst / 30 HP hồi
		_heal_flash = 0.3
		GameLog.info("P%d dùng Hồi sức: +%d HP." % [get_multiplayer_authority(), healed])
		return true
	# Kiếm 1/2: vung kiếm với sát thương + hiệu ứng của chiêu.
	# Kiếm 2 mang hiệu ứng "stun" để ngắt chiêu Tụ lực của boss.
	_start_swing(int(s["dmg"]), "stun" if n == 2 else "")
	return true

# --- Né lướt ---

func _try_dash() -> void:
	if dead or dash_cd > 0.0 or _dash_timer > 0.0:
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if test_move_dir != Vector2.ZERO:
		dir = test_move_dir
	if dir == Vector2.ZERO:
		dir = Vector2.from_angle(aim_angle) # đứng yên thì lướt theo hướng ngắm
	_dash_dir = dir.normalized()
	_dash_timer = DASH_TIME
	_invuln_timer = 0.3 # bất tử 0.3s
	dash_cd = DASH_CD

# --- Đỡ (chỉ Kiếm) ---

func _try_block() -> void:
	if dead or block_cd > 0.0 or blocking:
		return
	blocking = true
	_block_timer = BLOCK_TIME
	block_cd = BLOCK_CD

# --- Full Burst ---

func _try_burst() -> void:
	if dead or game == null:
		return
	game.request_burst()

# Đặt bất tử (dùng khi Full Burst: cả đội bất tử 3s).
func set_invulnerable(duration: float) -> void:
	_invuln_timer = maxf(_invuln_timer, duration)

# Kiệt sức sau Full Burst: -20% sát thương 5s.
func apply_weakened(duration: float) -> void:
	_weakened_timer = duration

# --- Nhận sát thương từ boss ---
# Boss (server) gọi qua RPC tới đúng chủ nhân vật; chơi đơn gọi trực tiếp.
# from_pos: vị trí nguồn sát thương (để hất văng ra xa); knockback 0 = không hất.

@rpc("any_peer")
func take_damage(amount: int, from_pos: Vector2, knockback: float, stagger: float = 0.0, slow: float = 0.0) -> void:
	if dead:
		return
	if _invuln_timer > 0.0:
		return # đang bất tử (né lướt / Full Burst)
	var dmg := amount
	if blocking:
		dmg = int(dmg * 0.4) # đỡ giảm 60%
	dmg = maxi(dmg - DEF, 1) # sát thương nhận = sát thương chiêu - DEF (tối thiểu 1)
	hp = maxi(hp - dmg, 0)
	_hit_flash = 0.2
	if knockback > 0.0 and from_pos != Vector2.ZERO:
		_kb_dir = (global_position - from_pos).normalized()
		_kb_speed = knockback
		_kb_timer = 0.15
	if stagger > 0.0:
		_stagger_timer = stagger
	if slow > 0.0:
		_slow_timer = slow
	if hp <= 0:
		_die()

func _die() -> void:
	dead = true
	hp = 0
	blocking = false
	swinging = false
	_dash_timer = 0.0
	_respawn_timer = 3.0
	GameLog.info("P%d đã ngã xuống — hồi sinh sau 3 giây (boss giữ nguyên HP)." % get_multiplayer_authority())

func _respawn() -> void:
	hp = max_hp
	mp = max_mp
	dead = false
	if game != null:
		position = game.spawn_position(get_multiplayer_authority())
	GameLog.info("P%d đã hồi sinh." % get_multiplayer_authority())
