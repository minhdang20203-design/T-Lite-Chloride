extends StaticBody2D
class_name Dummy
# Bù nhìn tập đánh GĐ1: HP đồng bộ từ server về mọi máy.
# Sát thương chỉ server mới được áp dụng (gọi qua RPC từ bất kỳ máy nào).
# Hết máu thì chết 2 giây rồi hồi sinh để test tiếp.

const MAX_HP := 500

var hp := MAX_HP:
	set(v):
		hp = v
		_update_bar()

var dead := false # chỉ server quản lý
var offline_mode := false # chơi đơn: áp dụng sát thương trực tiếp, không qua RPC

func _enter_tree() -> void:
	# Đồng bộ HP từ server (authority mặc định là server).
	var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(".:hp")
	sync.replication_config = cfg

func _ready() -> void:
	$Sprite2D.texture = PlaceholderArt.make_dummy_texture()
	$HpBar.max_value = MAX_HP
	$HpBar.value = hp
	_update_bar()

# RPC: bất kỳ peer nào cũng gọi được, nhưng chỉ server áp dụng.
@rpc("any_peer")
func take_damage(amount: int) -> void:
	if not offline_mode and not multiplayer.is_server():
		return
	if dead:
		return
	hp = maxi(hp - amount, 0)
	if hp <= 0:
		dead = true
		GameLog.info("Bu nhin het mau, hoi sinh sau 2 giay.")
		_respawn_later()

# Người chơi gọi hàm này khi đánh trúng (tự gửi RPC lên server).
func request_damage(amount: int) -> void:
	if offline_mode:
		take_damage(amount) # chơi đơn: không có mạng, áp dụng trực tiếp
		return
	rpc_id(1, "take_damage", amount)

func _respawn_later() -> void:
	await get_tree().create_timer(2.0).timeout
	hp = MAX_HP
	dead = false
	GameLog.info("Bu nhin da hoi sinh, HP=%d." % MAX_HP)

func _update_bar() -> void:
	if not is_inside_tree():
		return
	$HpBar.value = hp
	$HpLabel.text = "Bù nhìn %d/%d" % [hp, MAX_HP]
