extends CharacterBody2D
class_name Player
# Nhân vật người chơi GĐ1: WASD di chuyển, chuột ngắm, chuột trái vung kiếm.
# Chỉ peer có authority mới điều khiển nhân vật này; vị trí + góc ngắm +
# trạng thái vung kiếm được đồng bộ qua MultiplayerSynchronizer.
# Số liệu theo GDD §3: HP 100, MP 50, đánh thường 10 sát thương, +4 MP/đòn trúng,
# Burst tích 1 điểm / 50 sát thương (GĐ1 chỉ tích, chưa kích hoạt Full Burst).

const SPEED := 200.0 # ~3.2 ô/giây với ô 64px
const ATK := 10
const ATTACK_COOLDOWN := 0.45
const SWING_TIME := 0.25

var max_hp := 100
var hp := 100
var max_mp := 50
var mp := 50
var burst := 0.0 # 0..100
var aim_angle := 0.0 # đồng bộ
var swinging := false # đồng bộ
var test_move_dir := Vector2.ZERO # chỉ dùng cho test headless
var test_aim_angle = null # chỉ dùng cho test headless: ép góc ngắm thay cho chuột
var offline_mode := false # chơi đơn: tự điều khiển, không cần authority mạng

var _swing_timer := 0.0
var _cooldown := 0.0

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

func _physics_process(delta: float) -> void:
	if not _controls_mine():
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
	velocity = dir * SPEED
	move_and_slide()
	# Đánh: chuột trái, có hồi chiêu.
	_cooldown = maxf(_cooldown - delta, 0.0)
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
		else:
			offset = 0.6 # máy khác chỉ thấy tư thế vung
	$SwordPivot.rotation = aim_angle + offset
	# Chỉ máy của mình mới bật vùng quét kiếm (tránh tính sát thương 2 lần).
	$SwordPivot/SwordArea.monitoring = swinging and _controls_mine()

func _start_swing() -> void:
	swinging = true
	_swing_timer = SWING_TIME
	_cooldown = ATTACK_COOLDOWN

func _on_sword_body_entered(body: Node2D) -> void:
	if not _controls_mine():
		return
	if body is Dummy:
		(body as Dummy).request_damage(ATK)
		mp = mini(mp + 4, max_mp) # hồi MP khi đánh trúng
		burst = minf(burst + ATK / 50.0, 100.0) # 1 điểm Burst / 50 sát thương
