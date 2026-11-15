extends StaticBody2D
class_name Boss
# Boss Altoilia (GĐ2): HP 600, 3 phase, 6 chiêu, 4 bộ phận phá được.
# AI chỉ chạy trên server (host); các máy khác nhận trạng thái qua RPC
# (bắt đầu chiêu, choáng) + đồng bộ HP/phase/dead qua MultiplayerSynchronizer.
# Chơi đơn: máy local vừa là server nên AI chạy trực tiếp.
# Số liệu chiêu theo GDD §3/§5. Các số không có trong GDD (thời gian báo
# trước, tốc độ vòng/lốc, thời gian chờ giữa các chiêu, miễn nhiễm choáng)
# là số tạm, liệt kê trong README để chỉnh sau.

const MAX_HP := 600
const PHASE2_HP := 300
const PHASE3_HP := 150
const BODY_RADIUS := 36.0

# Chiêu (id).
const ATK_SPIKES := "spikes" # Gai đất
const ATK_AOE := "aoe" # AoE tròn
const ATK_RINGS := "rings" # Sóng nhạc
const ATK_LASER := "laser" # Tia laser
const ATK_TORNADO := "tornado" # Lốc xoáy
const ATK_CHARGE := "charge" # Tụ lực

# Số tạm — Gai đất.
const SPIKE_LEN := 500.0
const SPIKE_HALF_W := 30.0
const SPIKE_DMG := 15
const SPIKE_KB := 300.0
# Số tạm — AoE tròn.
const AOE_RADIUS := 120.0
const AOE_DMG := 20
# Số tạm — Sóng nhạc: 3 vòng, cách nhau 130px, rộng 40px, lan 220px/s.
const RING_SPEED := 220.0
const RING_SPACING := 130.0
const RING_BAND := 20.0
const RING_MAX_R := 520.0
const RING_DMG := 12
# Số tạm — Tia laser: quét 100 độ trong 1.4s, dài 850px.
const LASER_LEN := 850.0
const LASER_HALF_W := 25.0
const LASER_SWEEP := 1.75 # ~100 độ
const LASER_TELEGRAPH := 0.8
const LASER_TIME := 1.4
const LASER_DMG := 25
const LASER_KB := 400.0
# Số tạm — Lốc xoáy (chỉ phase 3): 55px/s, bán kính 48, 6s, 10 dmg/giây.
const TORNADO_SPEED := 55.0
const TORNADO_R := 48.0
const TORNADO_TIME := 6.0
const TORNADO_DMG := 10
const TORNADO_KB := 150.0
# Tụ lực: 3s, hồi 20% HP (120) nếu không bị ngắt.
const CHARGE_TIME := 3.0
const CHARGE_HEAL := 120
# Số tạm — sau mỗi lần bị choáng, boss kháng choáng 4s (chống spam ngắt).
const STUN_IMMUNE := 4.0
# Số tạm — thời gian chờ giữa các chiêu theo phase.
const IDLE_P1 := 1.6
const IDLE_P2 := 1.3
const IDLE_P3 := 0.9

const PART_DEFS := {
	"flower": {"name": "Cánh hoa", "offset": Vector2(-64, 0), "skill": "tornado", "skill_name": "Lốc xoáy"},
	"music": {"name": "Đàn nhạc", "offset": Vector2(64, 0), "skill": "rings", "skill_name": "Sóng nhạc"},
	"core": {"name": "Lõi máy", "offset": Vector2(0, 64), "skill": "laser", "skill_name": "Tia laser"},
	"crown": {"name": "Vương miện", "offset": Vector2(0, -64), "skill": "charge", "skill_name": "Tụ lực"},
}

var game: Node2D = null # game.gd gắn trước khi add_child
var offline_mode := false
var ai_enabled := true # test headless tắt AI để boss không đánh trong lúc kiểm tra

var hp := MAX_HP:
	set(v):
		hp = v
		_update_bar()
var phase := 1
var dead := false
var stunned := false

var parts := {} # part_id -> BossPart
var _attack := {} # chiêu đang chạy: {id, t, duration, data, detonated, hit, laser_angle}
var _hazards := [] # vòng sóng / lốc xoáy đang hoạt động
var _idle_timer := 2.0 # chờ 2s đầu trận rồi mới đánh
var _stun_timer := 0.0
var _stun_immune_timer := 0.0
var _lock_timer := 0.0 # Full Burst khóa boss
var _hit_flash := 0.0
var _sprite: Sprite2D = null
var attacks_started := 0 # đếm số chiêu đã bắt đầu (dùng cho test AI)

func _enter_tree() -> void:
	# Đồng bộ HP/phase/dead từ server (authority mặc định là server).
	var sync := MultiplayerSynchronizer.new()
	add_child(sync)
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(".:hp")
	cfg.add_property(".:phase")
	cfg.add_property(".:dead")
	sync.replication_config = cfg

func _ready() -> void:
	collision_layer = 2 # layer 2: kiếm đánh được (giống bù nhìn)
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = PlaceholderArt.make_boss_texture()
	_sprite.scale = Vector2(2, 2)
	add_child(_sprite)
	var bar := ProgressBar.new()
	bar.name = "HpBar"
	bar.offset_left = -45.0
	bar.offset_top = -62.0
	bar.offset_right = 45.0
	bar.offset_bottom = -52.0
	bar.max_value = MAX_HP
	bar.value = hp
	bar.show_percentage = false
	add_child(bar)
	var label := Label.new()
	label.name = "HpLabel"
	label.offset_left = -64.0
	label.offset_top = -80.0
	label.offset_right = 64.0
	label.offset_bottom = -64.0
	label.horizontal_alignment = 1
	label.add_theme_font_size_override("font_size", 13)
	label.text = "Altoilia"
	add_child(label)
	# 4 bộ phận phá được, đặt quanh thân (không chồng lên thân).
	for p_id in PART_DEFS:
		var def: Dictionary = PART_DEFS[p_id]
		var part := BossPart.new()
		part.name = "Part_" + p_id
		part.setup(p_id, def["name"], self, offline_mode)
		part.position = def["offset"]
		part.collision_layer = 2
		part.collision_mask = 0
		add_child(part)
		parts[p_id] = part
	_update_bar()

func _physics_process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash -= delta
	if _stun_timer > 0.0:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			stunned = false
			_stun_immune_timer = STUN_IMMUNE
	if _stun_immune_timer > 0.0:
		_stun_immune_timer -= delta
	if _lock_timer > 0.0:
		_lock_timer -= delta
	# Chiêu đang chạy + hazard: mọi máy đều chạy để vẽ telegraph giống nhau.
	_update_attack(delta)
	_update_hazards(delta)
	# AI chọn chiêu: chỉ server, chỉ khi rảnh (không chiêu, không choáng,
	# không bị khóa, còn người sống).
	if dead or stunned or _lock_timer > 0.0 or not _attack.is_empty():
		queue_redraw()
		return
	if not _is_server_side():
		queue_redraw()
		return
	if not ai_enabled:
		queue_redraw()
		return
	if game == null or game.get_alive_players().is_empty():
		queue_redraw()
		return
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_idle_timer = _idle_time_for_phase()
		_pick_attack()
	queue_redraw()

func _process(delta: float) -> void:
	if _sprite == null:
		return
	var mod := Color(1, 1, 1)
	if dead:
		mod = Color(0.35, 0.35, 0.4)
	elif _hit_flash > 0.0:
		mod = Color(2.5, 2.5, 2.5) # chớp trắng khi trúng đòn
	elif _attack.get("id", "") == "charge":
		mod = Color(1.4, 1.2, 0.6) # tụ lực: sáng vàng
	elif phase == 3:
		mod = Color(0.85, 0.65, 1.0) # phase 3: tím
	_sprite.modulate = mod

# --- Vẽ telegraph (vùng đỏ) + hazard + hiệu ứng choáng/tụ lực ---

func _draw() -> void:
	# Vòng đỏ telegraph của chiêu đang chạy.
	if not _attack.is_empty():
		var attack_id: String = _attack["id"]
		var t: float = _attack["t"]
		var data: Dictionary = _attack["data"]
		if attack_id == "spikes":
			var angle: float = data.get("angle", 0.0)
			var length: float = data.get("length", SPIKE_LEN)
			var half_w: float = data.get("half_w", SPIKE_HALF_W)
			var dir := Vector2.from_angle(angle)
			var perp := dir.orthogonal()
			var a := dir * 40.0
			var b := dir * length
			var col := Color(1, 0.2, 0.2, 0.55) if t < _telegraph_time("spikes") else Color(1, 0.2, 0.2, 0.85)
			draw_colored_polygon(PackedVector2Array([a + perp * half_w, b + perp * half_w, b - perp * half_w, a - perp * half_w]), col)
			if t >= _telegraph_time("spikes"):
				# Gai mọc: các tam giác dọc theo đường.
				var d := 60.0
				while d < length:
					var p := dir * d
					draw_colored_polygon(PackedVector2Array([p + perp * 12.0, p + dir * 18.0, p - perp * 12.0]), Color(0.9, 0.9, 0.95))
					d += 55.0
		elif attack_id == "aoe":
			var center: Vector2 = data.get("center", global_position)
			var radius: float = data.get("radius", AOE_RADIUS)
			var local := center - global_position
			var tele := _telegraph_time("aoe")
			if t < tele:
				# Vòng đỏ nhạt dần đậm lên khi sắp nổ.
				var a := 0.25 + 0.45 * (t / tele)
				draw_circle(local, radius, Color(1, 0.15, 0.15, a))
				draw_arc(local, radius, 0, TAU, 48, Color(1, 0.1, 0.1, 0.9), 3.0)
			else:
				draw_circle(local, radius, Color(1, 0.5, 0.1, 0.7))
				draw_arc(local, radius, 0, TAU, 48, Color(1, 0.6, 0.1, 1.0), 5.0)
		elif attack_id == "laser":
			var angle0: float = data.get("angle0", 0.0)
			var sweep: float = data.get("sweep", LASER_SWEEP)
			if t < LASER_TELEGRAPH:
				var dir0 := Vector2.from_angle(angle0)
				draw_line(Vector2.ZERO, dir0 * LASER_LEN, Color(1, 0.2, 0.2, 0.5), 6.0)
				draw_line(Vector2.ZERO, Vector2.from_angle(angle0 + sweep) * LASER_LEN, Color(1, 0.2, 0.2, 0.25), 3.0)
			else:
				var angle: float = _attack.get("laser_angle", angle0)
				var dir := Vector2.from_angle(angle)
				draw_line(Vector2.ZERO, dir * LASER_LEN, Color(1, 0.15, 0.15, 0.35), 34.0)
				draw_line(Vector2.ZERO, dir * LASER_LEN, Color(1, 0.95, 0.4, 0.95), 10.0)
		elif attack_id == "charge":
			# Vòng vàng đầy dần quanh boss trong 3s tụ lực.
			var frac := clampf(t / CHARGE_TIME, 0.0, 1.0)
			draw_arc(Vector2.ZERO, 55.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 40, Color(1, 0.8, 0.2, 0.95), 6.0)
			draw_circle(Vector2.ZERO, 46.0, Color(1, 0.8, 0.2, 0.12 + 0.2 * frac))
	# Hazard đang hoạt động: vòng sóng + lốc xoáy.
	for h in _hazards:
		if h["kind"] == "ring":
			var radius: float = h["radius"]
			if radius > 0.0:
				draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.7, 0.3, 1.0, 0.55), 40.0)
				draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(0.9, 0.6, 1.0, 0.9), 2.0)
		elif h["kind"] == "tornado":
			var pos: Vector2 = h["pos"]
			draw_circle(pos, TORNADO_R, Color(0.75, 0.8, 0.85, 0.35))
			draw_arc(pos, TORNADO_R * 0.7, 0, TAU, 32, Color(0.6, 0.65, 0.7, 0.9), 3.0)
			draw_arc(pos, TORNADO_R * 0.4, 0, TAU, 24, Color(0.6, 0.65, 0.7, 0.9), 3.0)
	# Choáng: 3 sao vàng trên đầu.
	if stunned:
		for i in range(3):
			var a := float(i) * TAU / 3.0
			var p := Vector2(cos(a) * 22.0, -58.0 + sin(a) * 5.0)
			draw_circle(p, 4.0, Color(1, 0.85, 0.2))

# --- Nhận sát thương (giống bù nhìn: chỉ server áp dụng) ---

func request_damage(amount: int, effect: String = "") -> void:
	if dead:
		return
	if offline_mode or multiplayer.is_server():
		take_damage(amount, effect) # mình là server (hoặc chơi đơn): áp dụng luôn
		return
	rpc_id(1, "take_damage", amount, effect)

@rpc("any_peer")
func take_damage(amount: int, effect: String = "") -> void:
	if dead:
		return
	if not offline_mode and not multiplayer.is_server():
		return
	hp = maxi(hp - amount, 0)
	_hit_flash = 0.15
	if effect == "stun":
		try_stun(1.5)
	_check_phase()
	if hp <= 0:
		_die()

func _check_phase() -> void:
	if dead:
		return
	var new_phase := 1
	if hp <= PHASE3_HP:
		new_phase = 3
	elif hp <= PHASE2_HP:
		new_phase = 2
	if new_phase > phase: # phase chỉ tăng, hồi máu không lùi phase
		phase = new_phase
		if phase == 3:
			_sprite.scale = Vector2(2.6, 2.6)
			GameLog.info("Altoilia biến hình — Phase 3! Đánh nhanh hơn, thêm Lốc xoáy.")
		else:
			GameLog.info("Altoilia chuyển Phase 2! Thêm Sóng nhạc và Tia laser.")

func _die() -> void:
	dead = true
	_attack = {}
	_hazards.clear()
	_sprite.modulate = Color(0.35, 0.35, 0.4)
	for part in parts.values():
		(part as Node).visible = false
	GameLog.info("Altoilia đã bị đánh bại!")
	if game != null:
		game.on_boss_died()

# --- Choáng / khóa (Full Burst) ---

func try_stun(duration: float) -> void:
	if dead:
		return
	if _stun_immune_timer > 0.0:
		GameLog.info("Altoilia đang kháng choáng (miễn nhiễm %.1fs)." % _stun_immune_timer)
		return
	if _lock_timer > 0.0:
		return # đang bị Full Burst khóa thì không cần choáng thêm
	if _attack.get("id", "") == "charge":
		GameLog.info("Tụ lực của Altoilia bị ngắt!")
	_attack = {}
	if offline_mode:
		_stun_started(duration)
	else:
		rpc("_stun_started", duration)

@rpc("authority", "call_local")
func _stun_started(duration: float) -> void:
	stunned = true
	_stun_timer = duration
	_attack = {} # mọi máy đều hủy chiêu đang chạy

# Full Burst khóa boss 3s: đứng yên, không đánh lại (không tính miễn nhiễm).
func lock(duration: float) -> void:
	if dead:
		return
	if _attack.get("id", "") == "charge":
		GameLog.info("Tụ lực của Altoilia bị Full Burst ngắt!")
	_attack = {}
	_lock_timer = duration

# --- Phá bộ phận ---

func on_part_broken(p_id: String) -> void:
	var def: Dictionary = PART_DEFS.get(p_id, {})
	var pname: String = def.get("name", p_id)
	var skill_name: String = def.get("skill_name", "")
	GameLog.info("Đã phá %s — Altoilia mất chiêu %s." % [pname, skill_name])

func is_part_broken(p_id: String) -> bool:
	var part = parts.get(p_id)
	return part != null and (part as BossPart).broken

func get_part(p_id: String) -> BossPart:
	return parts.get(p_id) as BossPart

# --- AI chọn chiêu ---

func _idle_time_for_phase() -> float:
	if phase == 3:
		return IDLE_P3
	if phase == 2:
		return IDLE_P2
	return IDLE_P1

func _telegraph_time(attack_id: String) -> float:
	if attack_id == "spikes":
		return 0.7 if phase == 3 else 0.8
	if attack_id == "aoe":
		return 1.2 if phase == 3 else 1.5
	return 0.8

func _attack_duration(attack_id: String) -> float:
	match attack_id:
		"spikes":
			return _telegraph_time("spikes") + 0.3
		"aoe":
			return _telegraph_time("aoe") + 0.3
		"laser":
			return LASER_TELEGRAPH + LASER_TIME
		"rings":
			return (RING_MAX_R + 2.0 * RING_SPACING) / RING_SPEED + 0.2
		"tornado":
			return 1.0
		"charge":
			return CHARGE_TIME
	return 1.0

func available_attacks() -> Array:
	var pool: Array = []
	if phase == 1:
		pool = [ATK_SPIKES, ATK_AOE]
	elif phase == 2:
		pool = [ATK_SPIKES, ATK_AOE, ATK_RINGS, ATK_LASER]
	else:
		pool = [ATK_SPIKES, ATK_AOE, ATK_RINGS, ATK_LASER, ATK_TORNADO]
	# Tụ lực chỉ dùng khi boss đã mất máu và vương miện còn nguyên.
	if hp < MAX_HP * 0.9 and not is_part_broken("crown"):
		pool.append(ATK_CHARGE)
	# Bộ phận nào bị phá thì mất chiêu tương ứng.
	for p_id in PART_DEFS:
		if is_part_broken(p_id):
			pool.erase((PART_DEFS[p_id] as Dictionary)["skill"])
	if pool.is_empty():
		pool = [ATK_SPIKES, ATK_AOE]
	return pool

func _pick_attack() -> void:
	var pool := available_attacks()
	var attack_id: String = pool[randi() % pool.size()]
	_start_attack(attack_id)

func _start_attack(attack_id: String) -> void:
	var data := {}
	var target := _random_alive_player()
	var boss_pos := global_position
	match attack_id:
		"spikes":
			var angle := 0.0
			if target != null:
				angle = (target.global_position - boss_pos).angle()
			data = {"angle": angle, "length": SPIKE_LEN, "half_w": SPIKE_HALF_W}
		"aoe":
			var center := boss_pos + Vector2(0, 150)
			if target != null:
				center = target.global_position
			data = {"center": center, "radius": AOE_RADIUS}
		"laser":
			var a0 := 0.0
			if target != null:
				a0 = (target.global_position - boss_pos).angle() - LASER_SWEEP / 2.0
			data = {"angle0": a0, "sweep": LASER_SWEEP}
		"tornado":
			var dir := Vector2.RIGHT
			if target != null:
				dir = (target.global_position - boss_pos).normalized()
			data = {"dir": dir}
		"rings", "charge":
			data = {}
	if offline_mode:
		_attack_started(attack_id, data)
	else:
		rpc("_attack_started", attack_id, data)

@rpc("authority", "call_local")
func _attack_started(attack_id: String, data: Dictionary) -> void:
	attacks_started += 1
	_attack = {"id": attack_id, "t": 0.0, "duration": _attack_duration(attack_id), "data": data, "detonated": false, "hit": []}
	if attack_id == "rings":
		for i in range(3):
			_hazards.append({"kind": "ring", "radius": -float(i) * RING_SPACING, "hit": []})
	elif attack_id == "tornado":
		var dir: Vector2 = data.get("dir", Vector2.RIGHT)
		_hazards.append({"kind": "tornado", "pos": Vector2.ZERO, "dir": dir, "t": 0.0, "tick": {}})

func _update_attack(delta: float) -> void:
	if _attack.is_empty():
		return
	_attack["t"] = float(_attack["t"]) + delta
	var t: float = _attack["t"]
	var attack_id: String = _attack["id"]
	var data: Dictionary = _attack["data"]
	match attack_id:
		"spikes":
			if t >= _telegraph_time("spikes") and not _attack["detonated"]:
				_attack["detonated"] = true
				_detonate_spikes(data)
		"aoe":
			if t >= _telegraph_time("aoe") and not _attack["detonated"]:
				_attack["detonated"] = true
				_detonate_aoe(data)
		"laser":
			if t >= LASER_TELEGRAPH:
				_update_laser(data, t - LASER_TELEGRAPH)
		"charge":
			if t >= CHARGE_TIME:
				_finish_charge()
				_attack = {}
				return
	if t >= float(_attack["duration"]):
		_attack = {}

func _update_hazards(delta: float) -> void:
	var keep := []
	for h in _hazards:
		if h["kind"] == "ring":
			h["radius"] = float(h["radius"]) + RING_SPEED * delta
			if _is_server_side():
				var radius: float = h["radius"]
				if radius > 0.0:
					for p in _alive_players():
						var pid: int = p.get_multiplayer_authority()
						var hit: Array = h["hit"]
						if pid in hit:
							continue
						var dist: float = p.global_position.distance_to(global_position)
						if absf(dist - radius) < RING_BAND + 10.0:
							hit.append(pid)
							_damage_player(p, RING_DMG, 0.0, 0.0, 1.0)
			if float(h["radius"]) <= RING_MAX_R:
				keep.append(h)
		elif h["kind"] == "tornado":
			h["t"] = float(h["t"]) + delta
			var dir: Vector2 = h["dir"]
			h["pos"] = (h["pos"] as Vector2) + dir * TORNADO_SPEED * delta
			if _is_server_side():
				var tpos: Vector2 = global_position + (h["pos"] as Vector2)
				var tick: Dictionary = h["tick"]
				for p in _alive_players():
					if p.global_position.distance_to(tpos) < TORNADO_R + 10.0:
						var pid: int = p.get_multiplayer_authority()
						var last: float = tick.get(pid, -10.0)
						if float(h["t"]) - last >= 1.0:
							tick[pid] = float(h["t"])
							_damage_player(p, TORNADO_DMG, TORNADO_KB)
			if float(h["t"]) < TORNADO_TIME:
				keep.append(h)
	_hazards = keep

# --- Nổ chiêu (chỉ server gây sát thương) ---

func _detonate_spikes(data: Dictionary) -> void:
	if not _is_server_side():
		return
	var angle: float = data.get("angle", 0.0)
	var length: float = data.get("length", SPIKE_LEN)
	var half_w: float = data.get("half_w", SPIKE_HALF_W)
	var dir := Vector2.from_angle(angle)
	var a := global_position
	var b := global_position + dir * length
	for p in _alive_players():
		var closest := _closest_point_on_segment(p.global_position, a, b)
		if closest.distance_to(p.global_position) < half_w + 10.0:
			_damage_player(p, SPIKE_DMG, SPIKE_KB, 0.4, 0.0)

func _detonate_aoe(data: Dictionary) -> void:
	if not _is_server_side():
		return
	var center: Vector2 = data.get("center", global_position)
	var radius: float = data.get("radius", AOE_RADIUS)
	for p in _alive_players():
		if p.global_position.distance_to(center) < radius + 10.0:
			_damage_player(p, AOE_DMG, 0.0)

func _update_laser(data: Dictionary, active_t: float) -> void:
	var angle0: float = data.get("angle0", 0.0)
	var sweep: float = data.get("sweep", LASER_SWEEP)
	var progress := clampf(active_t / LASER_TIME, 0.0, 1.0)
	var angle := angle0 + sweep * progress
	_attack["laser_angle"] = angle
	if not _is_server_side():
		return
	var a := global_position
	var b := global_position + Vector2.from_angle(angle) * LASER_LEN
	var hit: Array = _attack.get("hit", [])
	for p in _alive_players():
		var pid: int = p.get_multiplayer_authority()
		if pid in hit:
			continue
		var closest := _closest_point_on_segment(p.global_position, a, b)
		if closest.distance_to(p.global_position) < LASER_HALF_W + 10.0:
			hit.append(pid)
			_damage_player(p, LASER_DMG, LASER_KB)
	_attack["hit"] = hit

func _finish_charge() -> void:
	if not _is_server_side():
		return
	if dead:
		return
	hp = mini(hp + CHARGE_HEAL, MAX_HP)
	GameLog.info("Altoilia tụ lực xong, hồi %d HP (hiện %d/%d)." % [CHARGE_HEAL, hp, MAX_HP])
	_check_phase()

# --- Gây sát thương lên người chơi (server -> RPC tới chủ nhân vật) ---

func _damage_player(p: Player, amount: int, kb: float, stagger: float = 0.0, slow: float = 0.0) -> void:
	if p == null or p.dead:
		return
	if offline_mode:
		p.take_damage(amount, global_position, kb, stagger, slow)
	elif multiplayer.is_server():
		var pid := p.get_multiplayer_authority()
		if pid == multiplayer.get_unique_id():
			p.take_damage(amount, global_position, kb, stagger, slow)
		else:
			p.rpc_id(pid, "take_damage", amount, global_position, kb, stagger, slow)

# --- Tiện ích ---

func _is_server_side() -> bool:
	return offline_mode or multiplayer.is_server()

func _alive_players() -> Array:
	if game == null:
		return []
	return game.get_alive_players()

func _random_alive_player() -> Player:
	var alive := _alive_players()
	if alive.is_empty():
		return null
	return alive[randi() % alive.size()]

func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.0:
		return a
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return a + ab * t

func _update_bar() -> void:
	if not is_inside_tree():
		return
	var bar := get_node_or_null("HpBar") as ProgressBar
	if bar != null:
		bar.value = hp

# --- Debug cho test headless ---

func debug_start_attack(attack_id: String) -> void:
	# Ép boss dùng 1 chiêu ngay (chỉ dùng cho test, không dùng trong game).
	if dead:
		return
	_attack = {}
	_start_attack(attack_id)

func debug_set_hp(value: int) -> void:
	hp = clampi(value, 0, MAX_HP)
	_check_phase()
	if hp <= 0:
		_die()
