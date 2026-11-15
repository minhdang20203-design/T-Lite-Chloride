extends Node2D
# Sàn đấu 1600x1000: nền xanh đậm + kẻ ô 64px + viền gỗ.

const W := 1600.0
const H := 1000.0
const TILE := 64.0

func _ready() -> void:
	# 4 bức tường vật lý quanh sàn (layer 4) để nhân vật không đi ra ngoài.
	_add_wall(Vector2(800, -16), Vector2(1632, 32)) # trên
	_add_wall(Vector2(800, 1016), Vector2(1632, 32)) # dưới
	_add_wall(Vector2(-16, 500), Vector2(32, 1000)) # trái
	_add_wall(Vector2(1616, 500), Vector2(32, 1000)) # phải

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
	draw_rect(Rect2(0, 0, W, H), Color(0.16, 0.22, 0.16))
	var grid_col := Color(0.22, 0.3, 0.22)
	var x := 0.0
	while x <= W:
		draw_line(Vector2(x, 0), Vector2(x, H), grid_col, 1.0)
		x += TILE
	var y := 0.0
	while y <= H:
		draw_line(Vector2(0, y), Vector2(W, y), grid_col, 1.0)
		y += TILE
	draw_rect(Rect2(0, 0, W, H), Color(0.6, 0.5, 0.3), false, 4.0)
