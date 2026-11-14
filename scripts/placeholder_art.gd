class_name PlaceholderArt
extends RefCounted
# Art placeholder tự vẽ bằng code (pixel 16x16) — KHÔNG dùng asset ngoài.
# GĐ2 sẽ thay dần bằng art riêng.

# Nhân vật top-down: áo màu chính, mặt sáng, 2 mắt, viền đen.
static func make_player_texture(color: Color) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark: Color = color.darkened(0.4)
	var light: Color = color.lightened(0.4)
	for x in range(16):
		img.set_pixel(x, 0, Color.BLACK)
		img.set_pixel(x, 15, Color.BLACK)
	for y in range(16):
		img.set_pixel(0, y, Color.BLACK)
		img.set_pixel(15, y, Color.BLACK)
	for y in range(1, 6): # tóc / đầu
		for x in range(3, 13):
			img.set_pixel(x, y, dark)
	for y in range(6, 8): # mặt
		for x in range(3, 13):
			img.set_pixel(x, y, light)
	img.set_pixel(6, 7, Color.BLACK) # mắt trái
	img.set_pixel(9, 7, Color.BLACK) # mắt phải
	for y in range(8, 13): # áo
		for x in range(2, 14):
			img.set_pixel(x, y, color)
	for y in range(13, 15): # chân
		for x in range(4, 7):
			img.set_pixel(x, y, dark)
		for x in range(9, 12):
			img.set_pixel(x, y, dark)
	return ImageTexture.create_from_image(img)

# Kiếm: lưỡi xám + chuôi nâu, vẽ ngang (mũi hướng +X).
static func make_sword_texture() -> ImageTexture:
	var img := Image.create(16, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(5, 15): # lưỡi kiếm
		for y in range(2, 4):
			img.set_pixel(x, y, Color(0.85, 0.87, 0.9))
	img.set_pixel(15, 2, Color(0.95, 0.97, 1.0)) # mũi kiếm
	for x in range(3, 5): # cán chắn
		for y in range(1, 5):
			img.set_pixel(x, y, Color(0.85, 0.7, 0.2))
	for x in range(0, 3): # chuôi
		for y in range(2, 4):
			img.set_pixel(x, y, Color(0.4, 0.25, 0.1))
	return ImageTexture.create_from_image(img)

# Bù nhìn tập đánh: cọc gỗ + đầu rơm + thanh ngang.
static func make_dummy_texture() -> ImageTexture:
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color(0.45, 0.3, 0.15)
	var straw := Color(0.9, 0.75, 0.35)
	for y in range(8, 23): # cọc dọc
		for x in range(11, 13):
			img.set_pixel(x, y, wood)
	for x in range(4, 20): # thanh ngang
		for y in range(11, 13):
			img.set_pixel(x, y, wood)
	for y in range(2, 10): # đầu rơm (tròn)
		for x in range(7, 17):
			if (x - 11) * (x - 11) + (y - 5) * (y - 5) <= 16:
				img.set_pixel(x, y, straw)
	img.set_pixel(9, 5, Color.BLACK) # mắt X trái
	img.set_pixel(13, 5, Color.BLACK) # mắt X phải
	return ImageTexture.create_from_image(img)
