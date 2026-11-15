extends Node
# Autoload "Net" — quản lý kết nối ENet (host / join) cho GĐ1.
# Mô hình: listen-server — host vừa host vừa chơi, tối đa 4 người.
# Host thoát thì phòng đóng (client nhận signal server_disconnected).

const PORT := 8910
const MAX_PLAYERS := 4

var peer: ENetMultiplayerPeer = null
var is_hosting := false

signal host_started
signal host_failed
signal joined
signal join_failed
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal server_left

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# Mở phòng: máy này làm host (peer id = 1).
func host() -> void:
	disconnect_peer()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(PORT, MAX_PLAYERS)
	print("[Net] create_server err=", err)
	GameLog.info("Mo phong (host) cong %d, toi da %d nguoi — err=%d" % [PORT, MAX_PLAYERS, err])
	if err != OK:
		GameLog.error("Mo phong that bai, err=" + str(err))
		host_failed.emit()
		return
	peer = p
	multiplayer.multiplayer_peer = peer
	is_hosting = true
	_connect_signals()
	host_started.emit()

# Vào phòng: kết nối tới IP của host.
func join(ip: String) -> void:
	disconnect_peer()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ip.strip_edges(), PORT)
	print("[Net] create_client err=", err)
	GameLog.info("Vao phong tai IP %s, cong %d — err=%d" % [ip.strip_edges(), PORT, err])
	if err != OK:
		GameLog.error("Tao ket noi toi host that bai, err=" + str(err))
		join_failed.emit()
		return
	peer = p
	multiplayer.multiplayer_peer = peer
	_connect_signals()

# Ngắt kết nối hiện tại (thoát phòng / về menu).
func disconnect_peer() -> void:
	_disconnect_signals()
	if peer != null:
		GameLog.info("Ngat ket noi, ve menu.")
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	is_hosting = false

# Lấy IP LAN của máy này để hiện cho người kia nhập.
func get_lan_ip() -> String:
	for addr in IP.get_local_addresses():
		if "." in addr and not addr.begins_with("127."):
			return addr
	return "127.0.0.1"

func _connect_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _disconnect_signals() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)

func _on_peer_connected(peer_id: int) -> void:
	GameLog.info("P%d da vao phong." % peer_id)
	peer_joined.emit(peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	GameLog.info("P%d da roi phong." % peer_id)
	peer_left.emit(peer_id)

func _on_connected_to_server() -> void:
	GameLog.info("Da ket noi toi host.")
	joined.emit()

func _on_connection_failed() -> void:
	GameLog.error("Khong ket noi duoc toi host (sai IP / host chua mo phong / Firewall chan UDP 8910).")
	disconnect_peer() # dọn peer chết để get_unique_id() không spam lỗi
	join_failed.emit()

# Chỉ client nhận được: host đã thoát -> phòng đóng.
func _on_server_disconnected() -> void:
	GameLog.warn("Host da thoat, phong dong.")
	server_left.emit()
