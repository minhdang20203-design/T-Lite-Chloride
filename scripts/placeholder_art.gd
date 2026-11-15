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

# Boss Altoilia 32x32: nhân hình hoa trắng-xanh + chi tiết máy + nốt nhạc.
# Tóc trắng, áo xanh, vương miện vàng, cánh hoa hồng ở vai, lõi máy xám ở ngực.
static func make_boss_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var white := Color(0.95, 0.97, 1.0)
	var blue := Color(0.3, 0.55, 0.9)
	var dark_blue := Color(0.15, 0.3, 0.6)
	var pink := Color(0.95, 0.6, 0.75)
	var gold := Color(0.95, 0.8, 0.25)
	var gray := Color(0.55, 0.58, 0.62)
	# Cánh hoa 2 bên vai.
	for y in range(10, 16):
		for x in range(2, 7):
			if (x - 4) * (x - 4) + (y - 12) * (y - 12) <= 9:
				img.set_pixel(x, y, pink)
		for x in range(25, 30):
			if (x - 27) * (x - 27) + (y - 12) * (y - 12) <= 9:
				img.set_pixel(x, y, pink)
	# Tóc trắng (đầu).
	for y in range(4, 12):
		for x in range(11, 21):
			img.set_pixel(x, y, white)
	# Vương miện vàng trên đầu.
	for x in range(12, 20):
		img.set_pixel(x, 3, gold)
	img.set_pixel(13, 2, gold)
	img.set_pixel(16, 1, gold)
	img.set_pixel(18, 2, gold)
	# Mặt.
	for y in range(12, 15):
		for x in range(12, 20):
			img.set_pixel(x, y, Color(1.0, 0.85, 0.7))
	img.set_pixel(14, 13, Color.BLACK) # mắt trái
	img.set_pixel(17, 13, Color.BLACK) # mắt phải
	# Áo xanh (thân).
	for y in range(15, 27):
		for x in range(10, 22):
			img.set_pixel(x, y, blue)
	# Lõi máy xám ở ngực + nốt nhạc vàng.
	for y in range(18, 22):
		for x in range(14, 18):
			img.set_pixel(x, y, gray)
	img.set_pixel(15, 19, Color.BLACK)
	img.set_pixel(16, 19, Color.BLACK)
	img.set_pixel(24, 20, gold)
	img.set_pixel(24, 21, gold)
	img.set_pixel(25, 19, gold)
	# Chân váy.
	for y in range(27, 31):
		for x in range(11, 21):
			img.set_pixel(x, y, dark_blue)
	return ImageTexture.create_from_image(img)

# Bộ phận boss 16x16 theo loại: flower (cánh hoa hồng), music (đàn nhạc vàng),
# core (lõi máy xám), crown (vương miện vàng).
static func make_part_texture(kind: String) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if kind == "flower":
		var pink := Color(0.95, 0.6, 0.75)
		for y in range(16):
			for x in range(16):
				var dx := x - 8
				var dy := y - 8
				if dx * dx + dy * dy <= 36:
					img.set_pixel(x, y, pink)
		img.set_pixel(8, 8, Color(0.95, 0.85, 0.2))
		img.set_pixel(7, 8, Color(0.95, 0.85, 0.2))
		img.set_pixel(8, 7, Color(0.95, 0.85, 0.2))
		img.set_pixel(9, 8, Color(0.95, 0.85, 0.2))
		img.set_pixel(8, 9, Color(0.95, 0.85, 0.2))
	elif kind == "music":
		var gold := Color(0.95, 0.8, 0.25)
		var dark := Color(0.5, 0.35, 0.1)
		for y in range(3, 13): # thân đàn
			for x in range(4, 12):
				img.set_pixel(x, y, gold)
		for x in range(4, 12): # dây đàn
			img.set_pixel(x, 6, dark)
			img.set_pixel(x, 9, dark)
		img.set_pixel(12, 2, dark) # cần đàn
		img.set_pixel(13, 2, dark)
		img.set_pixel(12, 3, dark)
	elif kind == "core":
		var gray := Color(0.55, 0.58, 0.62)
		var dark := Color(0.25, 0.27, 0.3)
		for y in range(16):
			for x in range(16):
				var dx := x - 8
				var dy := y - 8
				if dx * dx + dy * dy <= 42:
					img.set_pixel(x, y, gray)
		# Răng bánh răng.
		for x in range(6, 10):
			img.set_pixel(x, 0, dark)
			img.set_pixel(x, 15, dark)
		for y in range(6, 10):
			img.set_pixel(0, y, dark)
			img.set_pixel(15, y, dark)
		img.set_pixel(8, 8, dark) # trục
		img.set_pixel(7, 8, Color(0.9, 0.2, 0.2)) # lõi đỏ
		img.set_pixel(8, 7, Color(0.9, 0.2, 0.2))
	else: # crown
		var gold := Color(0.95, 0.8, 0.25)
		for y in range(6, 13):
			for x in range(2, 14):
				img.set_pixel(x, y, gold)
		img.set_pixel(3, 4, gold)
		img.set_pixel(4, 5, gold)
		img.set_pixel(8, 3, gold)
		img.set_pixel(11, 5, gold)
		img.set_pixel(12, 4, gold)
		img.set_pixel(8, 9, Color(0.9, 0.2, 0.3)) # ngọc đỏ
	return ImageTexture.create_from_image(img)
