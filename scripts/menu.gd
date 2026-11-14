extends Control
# Menu chính GĐ1: tạo phòng (host) hoặc vào phòng bằng IP của host.

func _ready() -> void:
	$VBox/HostButton.pressed.connect(_on_host_pressed)
	$VBox/JoinButton.pressed.connect(_on_join_pressed)
	$VBox/EnterButton.pressed.connect(_on_enter_pressed)
	$VBox/EnterButton.visible = false
	$VBox/IpLabel.visible = false
	Net.host_started.connect(_on_host_started)
	Net.host_failed.connect(_on_host_failed)
	Net.joined.connect(_on_joined)
	Net.join_failed.connect(_on_join_failed)

func _set_status(text: String) -> void:
	$VBox/StatusLabel.text = text

# Hiện nút "Bắt đầu chơi" sau khi host/join thành công.
func _show_enter() -> void:
	$VBox/EnterButton.visible = true

func _on_host_pressed() -> void:
	_set_status("Đang tạo phòng...")
	Net.host()

func _on_host_started() -> void:
	$VBox/IpLabel.visible = true
	$VBox/IpLabel.text = "IP của bạn: %s  (cổng %d)\nBảo bạn nhập IP này rồi bấm Vào phòng." % [Net.get_lan_ip(), Net.PORT]
	_set_status("Phòng đã mở. Bấm Bắt đầu chơi khi cả đội đã vào.")
	_show_enter()

func _on_host_failed() -> void:
	_set_status("Không tạo được phòng (cổng %d đang bận?)." % Net.PORT)

func _on_join_pressed() -> void:
	var ip: String = $VBox/JoinIpEdit.text.strip_edges()
	if ip.is_empty():
		_set_status("Nhập IP của host trước đã.")
		return
	_set_status("Đang kết nối tới %s..." % ip)
	Net.join(ip)

func _on_joined() -> void:
	_set_status("Đã kết nối tới host. Bấm Bắt đầu chơi.")
	_show_enter()

func _on_join_failed() -> void:
	_set_status("Không kết nối được. Kiểm tra IP, cùng mạng LAN và tường lửa (cổng %d)." % Net.PORT)

func _on_enter_pressed() -> void:
	(get_parent() as Node).start_game()
