extends Node2D
# Sàn đấu nhà thờ 1600x1000 (Godot 4.7, GDScript) — T-Lite Chloride:
# - Sàn đá cẩm thạch caro 32x32 (2 biến thể sáng + 2 biến thể tối)
# - Thảm đỏ giữa sàn kèm viền vàng dọc trục lễ đường
# - Cửa kính màu dọc 2 mép trên/dưới
# - Chi tiết máy móc (bánh răng xám) + nốt nhạc vàng dọc 2 mép trái/phải
# - 4 cột đá vật lý (layer 4, bán kính 28) + 4 tường vật lý bao quanh sàn (layer 4)
# Tự động nạp tile 32x32 từ res://assets/map/<ten-tile>.png nếu đã có file ảnh;
# nếu chưa có file ảnh thì tự động vẽ bằng code trong _draw() để dùng được ngay.

const W := 1600.0
const H := 1000.0
const TILE := 32.0

# 4 cột đá vật lý (tâm) — tránh khu vực đấu boss (800, 420, R=250) và cụm spawn (560..800, 500).
const PILLARS := [
	Vector2(400, 250),
	Vector2(1200, 250),
	Vector2(400, 750),
	Vector2(1200, 750),
]
const PILLAR_R := 28.0

# Tọa độ tham chiếu cố định theo quy định kỹ thuật (không tự sinh node boss/bù nhìn/nhân vật ở đây).
const BOSS_POS := Vector2(800, 420)
const BOSS_CLEAR_RADIUS := 250.0
const DUMMY_POS := Vector2(200, 200)
const PLAYER_SPAWNS := [
	Vector2(560, 500), # P1
	Vector2(640, 500), # P2
	Vector2(720, 500), # P3
	Vector2(800, 500), # P4
]

# Danh sách 14 tile 32x32 đúng theo thiết kế Phần A.
const TILE_PATHS := {
	"marble_light_1": "res://assets/map/marble_light_1.png",
	"marble_light_2": "res://assets/map/marble_light_2.png",
	"marble_dark_1": "res://assets/map/marble_dark_1.png",
	"marble_dark_2": "res://assets/map/marble_dark_2.png",
	"carpet_red_center": "res://assets/map/carpet_red_center.png",
	"carpet_red_border": "res://assets/map/carpet_red_border.png",
	"stained_glass_blue": "res://assets/map/stained_glass_blue.png",
	"stained_glass_red": "res://assets/map/stained_glass_red.png",
	"stained_glass_yellow": "res://assets/map/stained_glass_yellow.png",
	"pillar_body": "res://assets/map/pillar_body.png",
	"pillar_base": "res://assets/map/pillar_base.png",
	"gear_gray": "res://assets/map/gear_gray.png",
	"music_note_gold": "res://assets/map/music_note_gold.png",
	"wall_stone": "res://assets/map/wall_stone.png",
}

var _tiles: Dictionary = {}

func _ready() -> void:
	_load_tiles()
	# 4 bức tường vật lý quanh sàn (layer 4: collision_layer = 8) để nhân vật không đi ra ngoài.
	_add_wall(Vector2(800, -16), Vector2(1632, 32)) # trên
	_add_wall(Vector2(800, 1016), Vector2(1632, 32)) # dưới
	_add_wall(Vector2(-16, 500), Vector2(32, 1000)) # trái
	_add_wall(Vector2(1616, 500), Vector2(32, 1000)) # phải
	# 4 cột đá vật lý (layer 4: collision_layer = 8).
	for pos in PILLARS:
		var body := StaticBody2D.new()
		body.collision_layer = 8 # layer 4: đúng mask của nhân vật
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = PILLAR_R
		shape.shape = circle
		shape.position = pos
		body.add_child(shape)
		add_child(body)
	queue_redraw()

func _load_tiles() -> void:
	_tiles.clear()
	for key in TILE_PATHS.keys():
		var path: String = TILE_PATHS[key]
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				_tiles[key] = tex
	print("[Map] Da nap %d/14 tile anh (thieu thi ve bang code)." % _tiles.size())

func _add_wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 8 # layer 4: đúng mask của nhân vật
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	shape.shape = rs
	shape.position = center
	body.add_child(shape)
	add_child(body)

func _draw() -> void:
	# 1 & 2. Sàn đá cẩm thạch caro 32x32 (2 biến thể sáng + 2 biến thể tối).
	var x := 0.0
	var xi := 0
	while x < W:
		var tw := minf(TILE, W - x)
		var y := 0.0
		var yi := 0
		while y < H:
			var th := minf(TILE, H - y)
			_draw_marble_tile(Rect2(x, y, tw, th), xi, yi)
			y += TILE
			yi += 1
		x += TILE
		xi += 1

	# 3. Thảm đỏ giữa sàn (boss đứng trên thảm tại (800, 420), P4 tại (800, 500)).
	_draw_carpet()

	# 8. Viền tường đá 32x32 quanh rìa sàn.
	_draw_stone_border()

	# 4. Cửa kính màu dọc mép trên/dưới: 6 ô mỗi bên.
	var glass_colors := [
		Color(0.25, 0.45, 0.90), # xanh dương
		Color(0.85, 0.25, 0.30), # đỏ
		Color(0.25, 0.70, 0.35), # xanh lá
		Color(0.90, 0.75, 0.20), # vàng
		Color(0.60, 0.35, 0.85), # tím
		Color(0.20, 0.75, 0.75), # lam ngọc
	]
	var glass_tile_keys := [
		"stained_glass_blue",
		"stained_glass_red",
		"stained_glass_yellow",
		"stained_glass_yellow",
		"stained_glass_red",
		"stained_glass_blue",
	]
	for i in range(6):
		var gx := 120.0 + float(i) * 240.0
		var col: Color = glass_colors[i]
		var tkey: String = glass_tile_keys[i]
		# Ô trên (y = 10..66).
		_draw_stained_glass(Rect2(gx, 10.0, 90.0, 56.0), col, tkey)
		# Ô dưới (y = H - 66..H - 10).
		_draw_stained_glass(Rect2(gx, H - 66.0, 90.0, 56.0), col, tkey)

	# 6 & 7. Chi tiết máy móc (bánh răng xám) + nốt nhạc vàng dọc 2 mép trái/phải.
	for i in range(4):
		var gy := 180.0 + float(i) * 220.0
		_draw_gear(Vector2(36.0, gy), 22.0)
		_draw_gear(Vector2(W - 36.0, gy + 110.0), 22.0)
		_draw_note(Vector2(70.0, gy + 110.0))
		_draw_note(Vector2(W - 70.0, gy))

	# 5. 4 cột đá (chân cột + thân cột).
	for pos in PILLARS:
		_draw_pillar(pos)

	# Khung viền đá bao ngoài cùng toàn sàn.
	draw_rect(Rect2(0.0, 0.0, W, H), Color(0.45, 0.42, 0.38), false, 6.0)

func _draw_marble_tile(rect: Rect2, xi: int, yi: int) -> void:
	var light := (xi + yi) % 2 == 0
	var variant_b := ((xi * 3 + yi * 5) % 4) >= 2
	var is_edge_strip := rect.position.x < 96.0 or rect.position.x >= (W - 96.0)
	var key := ""
	if light:
		key = "marble_light_2" if variant_b else "marble_light_1"
	else:
		key = "marble_dark_2" if (variant_b or is_edge_strip) else "marble_dark_1"

	if _tiles.has(key):
		draw_texture_rect(_tiles[key], rect, false)
		return

	var base_col: Color
	if light:
		base_col = Color(0.77, 0.80, 0.83) if variant_b else Color(0.74, 0.74, 0.78)
	else:
		base_col = Color(0.62, 0.65, 0.72) if (variant_b or is_edge_strip) else Color(0.66, 0.66, 0.72)

	draw_rect(rect, base_col)
	# Viền mạch gạch 1px và vân đá cẩm thạch trắng-xanh.
	draw_rect(rect, Color(0.52, 0.55, 0.62, 0.35), false, 1.0)
	if rect.size.x >= 16.0 and rect.size.y >= 16.0:
		var vein_col := Color(0.84, 0.87, 0.90, 0.55) if light else Color(0.52, 0.55, 0.62, 0.45)
		if not variant_b:
			draw_line(
				rect.position + Vector2(4.0, 6.0),
				rect.position + Vector2(rect.size.x - 6.0, rect.size.y - 8.0),
				vein_col,
				1.0
			)
		else:
			draw_line(
				rect.position + Vector2(6.0, rect.size.y - 5.0),
				rect.position + Vector2(rect.size.x - 5.0, 7.0),
				vein_col,
				1.0
			)

func _draw_carpet() -> void:
	# Nền thảm đỏ giữ đúng tọa độ gốc: rìa ngoài 740..860 (rộng 120), lòng trong 748..852 (rộng 104).
	draw_rect(Rect2(740.0, 0.0, 120.0, H), Color(0.55, 0.15, 0.20))
	draw_rect(Rect2(748.0, 0.0, 104.0, H), Color(0.62, 0.18, 0.24))

	var y := 0.0
	while y < H:
		var th := minf(TILE, H - y)
		if _tiles.has("carpet_red_border"):
			draw_texture_rect(_tiles["carpet_red_border"], Rect2(736.0, y, TILE, th), false)
			draw_texture_rect(_tiles["carpet_red_border"], Rect2(832.0, y, TILE, th), false)
		if _tiles.has("carpet_red_center"):
			draw_texture_rect(_tiles["carpet_red_center"], Rect2(768.0, y, TILE, th), false)
			draw_texture_rect(_tiles["carpet_red_center"], Rect2(800.0, y, TILE, th), false)
		elif th >= 24.0:
			# Hoa văn hình thoi dệt chìm dọc tâm thảm (x = 800) mỗi ô 32px.
			var cy := y + TILE * 0.5
			var diamond := PackedVector2Array([
				Vector2(800.0, cy - 8.0),
				Vector2(812.0, cy),
				Vector2(800.0, cy + 8.0),
				Vector2(788.0, cy),
			])
			draw_colored_polygon(diamond, Color(0.47, 0.12, 0.17))
			draw_circle(Vector2(800.0, cy), 2.0, Color(0.85, 0.70, 0.25))
		y += TILE

	# Hai đường viền vàng dọc thảm tại x = 748 và x = 852.
	draw_line(Vector2(748.0, 0.0), Vector2(748.0, H), Color(0.85, 0.70, 0.25), 2.0)
	draw_line(Vector2(852.0, 0.0), Vector2(852.0, H), Color(0.85, 0.70, 0.25), 2.0)

func _draw_stone_border() -> void:
	if _tiles.has("wall_stone"):
		var tex: Texture2D = _tiles["wall_stone"]
		var x := 0.0
		while x < W:
			var tw := minf(TILE, W - x)
			draw_texture_rect(tex, Rect2(x, 0.0, tw, 8.0), false)
			draw_texture_rect(tex, Rect2(x, H - 8.0, tw, 8.0), false)
			x += TILE
		var y := 0.0
		while y < H:
			var th := minf(TILE, H - y)
			draw_texture_rect(tex, Rect2(0.0, y, 8.0, th), false)
			draw_texture_rect(tex, Rect2(W - 8.0, y, 8.0, th), false)
			y += TILE
	else:
		# Các khe đá khắc dọc viền sàn theo nhịp 32px.
		var border_col := Color(0.45, 0.42, 0.38, 0.55)
		var x := 0.0
		while x < W:
			draw_line(Vector2(x, 0.0), Vector2(x, 8.0), border_col, 1.0)
			draw_line(Vector2(x, H - 8.0), Vector2(x, H), border_col, 1.0)
			x += TILE
		var y := 0.0
		while y < H:
			draw_line(Vector2(0.0, y), Vector2(8.0, y), border_col, 1.0)
			draw_line(Vector2(W - 8.0, y), Vector2(W, y), border_col, 1.0)
			y += TILE

func _draw_stained_glass(rect: Rect2, col: Color, tile_key: String) -> void:
	if _tiles.has(tile_key):
		draw_texture_rect(_tiles[tile_key], rect, false)
		return

	var frame_col := Color(0.25, 0.22, 0.20)
	draw_rect(rect, frame_col)
	var inner := Rect2(rect.position.x + 4.0, rect.position.y + 4.0, rect.size.x - 8.0, rect.size.y - 8.0)
	draw_rect(inner, col)
	# Mảng kính bắt sáng góc trong giúp ô kính màu có chiều sâu pixel art.
	draw_rect(Rect2(inner.position.x + 4.0, inner.position.y + 4.0, inner.size.x * 0.4, inner.size.y * 0.4), col.lightened(0.22))
	# Đố cửa chữ thập + đố phụ chia ô.
	var mid_x := rect.position.x + rect.size.x * 0.5
	var mid_y := rect.position.y + rect.size.y * 0.5
	draw_line(Vector2(mid_x, inner.position.y), Vector2(mid_x, inner.position.y + inner.size.y), frame_col, 2.0)
	draw_line(Vector2(inner.position.x, mid_y), Vector2(inner.position.x + inner.size.x, mid_y), frame_col, 2.0)

func _draw_pillar(pos: Vector2) -> void:
	# Bóng đổ nhẹ dưới chân cột.
	draw_circle(pos + Vector2(3.0, 4.0), PILLAR_R + 2.0, Color(0.15, 0.15, 0.18, 0.35))

	if _tiles.has("pillar_base"):
		draw_texture_rect(
			_tiles["pillar_base"],
			Rect2(pos.x - PILLAR_R, pos.y - PILLAR_R, PILLAR_R * 2.0, PILLAR_R * 2.0),
			false
		)
	else:
		draw_circle(pos, PILLAR_R, Color(0.55, 0.53, 0.50))
		draw_arc(pos, PILLAR_R, 0.0, TAU, 32, Color(0.35, 0.33, 0.30), 3.0)

	if _tiles.has("pillar_body"):
		var body_r := PILLAR_R * 0.75
		draw_texture_rect(
			_tiles["pillar_body"],
			Rect2(pos.x - body_r, pos.y - body_r, body_r * 2.0, body_r * 2.0),
			false
		)
	else:
		# Rãnh cột cổ điển (8 khía) + đỉnh cột sáng.
		for i in range(8):
			var a := float(i) * TAU / 8.0
			var p1 := pos + Vector2(cos(a), sin(a)) * (PILLAR_R * 0.55)
			var p2 := pos + Vector2(cos(a), sin(a)) * (PILLAR_R - 2.0)
			draw_line(p1, p2, Color(0.35, 0.33, 0.30), 1.5)
		draw_circle(pos, PILLAR_R * 0.55, Color(0.65, 0.63, 0.60))
		draw_arc(pos, PILLAR_R * 0.55, 0.0, TAU, 24, Color(0.45, 0.42, 0.38), 1.5)

func _draw_gear(center: Vector2, r: float) -> void:
	if _tiles.has("gear_gray"):
		var d := (r + 8.0) * 2.0
		draw_texture_rect(_tiles["gear_gray"], Rect2(center.x - d * 0.5, center.y - d * 0.5, d, d), false)
		return

	var gear_col := Color(0.45, 0.47, 0.50)
	var dark_col := Color(0.30, 0.31, 0.33)
	for i in range(6):
		var a := float(i) * TAU / 6.0
		var p1 := center + Vector2(cos(a), sin(a)) * r
		var p2 := center + Vector2(cos(a), sin(a)) * (r + 8.0)
		draw_line(p1, p2, gear_col, 6.0)
	draw_circle(center, r, gear_col)
	draw_arc(center, r * 0.72, 0.0, TAU, 24, dark_col, 1.5)
	draw_circle(center, r * 0.40, dark_col)

func _draw_note(pos: Vector2) -> void:
	if _tiles.has("music_note_gold"):
		draw_texture_rect(_tiles["music_note_gold"], Rect2(pos.x - 16.0, pos.y - 24.0, TILE, TILE), false)
		return

	var note_col := Color(0.95, 0.80, 0.25)
	var shadow_col := Color(0.35, 0.28, 0.10, 0.45)
	# Bóng đổ nhẹ giúp nốt nhạc vàng nổi trên nền đá.
	draw_circle(pos + Vector2(1.5, 1.5), 6.0, shadow_col)
	draw_circle(pos, 6.0, note_col)
	draw_line(pos + Vector2(5.0, -2.0), pos + Vector2(5.0, -22.0), note_col, 2.0)
	draw_line(pos + Vector2(5.0, -22.0), pos + Vector2(14.0, -18.0), note_col, 2.0)
