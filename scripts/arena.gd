extends Node2D
# Sàn đấu 1600x1000: nền xanh đậm + kẻ ô 64px + viền gỗ.

const W := 1600.0
const H := 1000.0
const TILE := 64.0

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
