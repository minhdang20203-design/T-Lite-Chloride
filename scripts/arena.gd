extends Node2D
# Sàn đấu nhà thờ 1600x1000 (GĐ2): sàn đá cẩm thạch, thảm đỏ giữa sàn,
# cửa kính màu dọc 2 mép trên/dưới, 4 cột đá làm vật cản, chi tiết máy móc
# + nốt nhạc ở rìa sàn. Vẽ hoàn toàn bằng code, không asset ngoài.
# Tường vật lý: game.gd tạo 4 tường quanh sàn (layer 4); ở đây thêm
# 4 cột đá vật lý (layer 4) để nhân vật không đi xuyên qua.

const W := 1600.0
const H := 1000.0
const TILE := 64.0

# 4 cột đá (tâm) — tránh khu vực đấu boss ở giữa và điểm spawn.
const PILLARS := [
	Vector2(400, 250),
	Vector2(1200, 250),
	Vector2(400, 750),
	Vector2(1200, 750),
]
const PILLAR_R := 28.0

func _ready() -> void:
	# 4 bức tường vật lý quanh sàn (layer 4) để nhân vật không đi ra ngoài.
	_add_wall(Vector2(800, -16), Vector2(1632, 32)) # trên
	_add_wall(Vector2(800, 1016), Vector2(1632, 32)) # dưới
	_add_wall(Vector2(-16, 500), Vector2(32, 1000)) # trái
	_add_wall(Vector2(1616, 500), Vector2(32, 1000)) # phải
	# 4 cột đá vật lý.
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
	# Sàn đá cẩm thạch: ô kẻ caro nhạt.
	var x := 0.0
	var xi := 0
	while x < W:
		var y := 0.0
		var yi := 0
		while y < H:
			var light := (xi + yi) % 2 == 0
			var col := Color(0.74, 0.74, 0.78) if light else Color(0.66, 0.66, 0.72)
			draw_rect(Rect2(x, y, TILE, TILE), col)
			y += TILE
			yi += 1
		x += TILE
		xi += 1
	# Thảm đỏ giữa sàn (boss đứng trên thảm).
	draw_rect(Rect2(740, 0, 120, H), Color(0.55, 0.15, 0.2))
	draw_rect(Rect2(748, 0, 104, H), Color(0.62, 0.18, 0.24))
	draw_line(Vector2(748, 0), Vector2(748, H), Color(0.85, 0.7, 0.25), 2.0)
	draw_line(Vector2(852, 0), Vector2(852, H), Color(0.85, 0.7, 0.25), 2.0)
	# Cửa kính màu dọc mép trên/dưới: 6 ô mỗi bên, màu khác nhau.
	var glass_colors := [
		Color(0.25, 0.45, 0.9), Color(0.85, 0.25, 0.3), Color(0.25, 0.7, 0.35),
		Color(0.9, 0.75, 0.2), Color(0.6, 0.35, 0.85), Color(0.2, 0.75, 0.75),
	]
	for i in range(6):
		var gx := 120.0 + float(i) * 240.0
		var col: Color = glass_colors[i]
		# Ô trên.
		draw_rect(Rect2(gx, 10, 90, 56), Color(0.25, 0.22, 0.2))
		draw_rect(Rect2(gx + 4, 14, 82, 48), col)
		draw_line(Vector2(gx + 45, 14), Vector2(gx + 45, 62), Color(0.25, 0.22, 0.2), 2.0)
		draw_line(Vector2(gx + 4, 38), Vector2(gx + 86, 38), Color(0.25, 0.22, 0.2), 2.0)
		# Ô dưới.
		draw_rect(Rect2(gx, H - 66, 90, 56), Color(0.25, 0.22, 0.2))
		draw_rect(Rect2(gx + 4, H - 62, 82, 48), col)
		draw_line(Vector2(gx + 45, H - 62), Vector2(gx + 45, H - 14), Color(0.25, 0.22, 0.2), 2.0)
		draw_line(Vector2(gx + 4, H - 38), Vector2(gx + 86, H - 38), Color(0.25, 0.22, 0.2), 2.0)
	# Chi tiết máy móc (bánh răng xám) + nốt nhạc (vàng) dọc 2 mép trái/phải.
	for i in range(4):
		var gy := 180.0 + float(i) * 220.0
		_draw_gear(Vector2(36, gy), 22.0)
		_draw_gear(Vector2(W - 36, gy + 110.0), 22.0)
		_draw_note(Vector2(70, gy + 110.0))
		_draw_note(Vector2(W - 70, gy))
	# 4 cột đá.
	for pos in PILLARS:
		draw_circle(pos, PILLAR_R, Color(0.55, 0.53, 0.5))
		draw_arc(pos, PILLAR_R, 0, TAU, 32, Color(0.35, 0.33, 0.3), 3.0)
		draw_circle(pos, PILLAR_R * 0.55, Color(0.65, 0.63, 0.6))
	# Viền đá quanh sàn.
	draw_rect(Rect2(0, 0, W, H), Color(0.45, 0.42, 0.38), false, 6.0)

func _draw_gear(center: Vector2, r: float) -> void:
	draw_circle(center, r, Color(0.45, 0.47, 0.5))
	for i in range(6):
		var a := float(i) * TAU / 6.0
		var p1 := center + Vector2(cos(a), sin(a)) * r
		var p2 := center + Vector2(cos(a), sin(a)) * (r + 8.0)
		draw_line(p1, p2, Color(0.45, 0.47, 0.5), 6.0)
	draw_circle(center, r * 0.4, Color(0.3, 0.31, 0.33))

func _draw_note(pos: Vector2) -> void:
	# Nốt nhạc đơn giản: đầu tròn + cán.
	draw_circle(pos, 6.0, Color(0.95, 0.8, 0.25))
	draw_line(pos + Vector2(5, -2), pos + Vector2(5, -22), Color(0.95, 0.8, 0.25), 2.0)
	draw_line(pos + Vector2(5, -22), pos + Vector2(14, -18), Color(0.95, 0.8, 0.25), 2.0)
