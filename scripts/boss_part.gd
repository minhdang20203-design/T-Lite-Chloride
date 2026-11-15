extends StaticBody2D
class_name BossPart
# Một bộ phận của boss Altoilia (GĐ2): có HP riêng, phá được thì boss mất
# chiêu liên quan. Đặt quanh thân boss, không chồng lên thân boss để kiếm
# đánh trúng riêng từng bộ phận.
# flower (cánh hoa) -> mất Lốc xoáy; music (đàn nhạc) -> mất Sóng nhạc;
# core (lõi máy) -> mất Tia laser; crown (vương miện) -> mất Tụ lực.
# Sát thương chỉ server mới áp dụng (gọi qua RPC từ bất kỳ máy nào),
# giống bù nhìn. HP 100 là số tạm (chưa có trong GDD).

const MAX_HP := 100

var part_id := "" # flower / music / core / crown
var display_name := ""
var boss: Boss = null
var offline_mode := false

var hp := MAX_HP:
	set(v):
		hp = v
		_update_bar()
var broken := false

func setup(p_id: String, p_name: String, p_boss: Boss, p_offline: bool) -> void:
	part_id = p_id
	display_name = p_name
	boss = p_boss
	offline_mode = p_offline

func _enter_tree() -> void:
	# Đồng bộ HP + trạng thái phá từ server về mọi máy.
	var sync := MultiplayerSynchronizer.new()
	add_child(sync)
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(".:hp")
	cfg.add_property(".:broken")
	sync.replication_config = cfg

func _ready() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = PlaceholderArt.make_part_texture(part_id)
	sprite.scale = Vector2(2, 2)
	add_child(sprite)
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	var bar := ProgressBar.new()
	bar.name = "HpBar"
	bar.offset_left = -20.0
	bar.offset_top = -30.0
	bar.offset_right = 20.0
	bar.offset_bottom = -24.0
	bar.max_value = MAX_HP
	bar.value = hp
	bar.show_percentage = false
	add_child(bar)
	var label := Label.new()
	label.name = "HpLabel"
	label.offset_left = -40.0
	label.offset_top = -46.0
	label.offset_right = 40.0
	label.offset_bottom = -32.0
	label.horizontal_alignment = 1
	label.add_theme_font_size_override("font_size", 11)
	label.text = display_name
	add_child(label)
	_update_bar()

# Người chơi gọi hàm này khi đánh trúng (tự gửi RPC lên server,
# hoặc áp dụng trực tiếp khi chơi đơn).
func request_damage(amount: int, effect: String = "") -> void:
	if broken:
		return
	if offline_mode or multiplayer.is_server():
		take_damage(amount, effect) # mình là server (hoặc chơi đơn): áp dụng luôn
		return
	rpc_id(1, "take_damage", amount, effect)

# RPC: bất kỳ peer nào cũng gọi được, nhưng chỉ server áp dụng.
@rpc("any_peer")
func take_damage(amount: int, effect: String = "") -> void:
	if broken:
		return
	if not offline_mode and not multiplayer.is_server():
		return
	hp = maxi(hp - amount, 0)
	# Chiêu Đập choáng trúng bộ phận vẫn làm choáng boss.
	if effect == "stun" and boss != null:
		boss.try_stun(1.5)
	if hp <= 0:
		broken = true
		$Sprite2D.modulate = Color(0.3, 0.3, 0.3, 0.4)
		$CollisionShape2D.set_deferred("disabled", true)
		$HpBar.visible = false
		GameLog.info("Da pha %s — Altoilia mat chieu lien quan." % display_name)
		if boss != null:
			boss.on_part_broken(part_id)

func _update_bar() -> void:
	if not is_inside_tree():
		return
	var bar := get_node_or_null("HpBar") as ProgressBar
	if bar != null:
		bar.value = hp
