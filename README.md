# T-Lite Chloride — GĐ1: Nền online co-op

Game 2D co-op top-down pixel art, lấy cảm hứng cơ chế PvE của Toram Online,
nội dung tự làm mới hoàn toàn. Engine: **Godot 4.7** (GDScript).

## GĐ1 làm được gì (nền online, chưa có boss/cây kỹ năng)

- Menu: **Tạo phòng (Host)** hoặc **Vào phòng (Join)** bằng IP của host.
  Host xem IP của mình ngay trên menu để gửi cho bạn.
- Tối đa **4 người/phòng**, mô hình listen-server (host vừa host vừa chơi).
- Người chơi: di chuyển WASD, ngắm bằng chuột, đánh thường (chuột trái).
  Thanh HP / MP / Burst hiển thị trên màn hình.
- **Bù nhìn tập đánh**: HP đồng bộ cả phòng — 2 người cùng đánh thì máu giảm
  giống nhau trên cả 2 màn hình. Hết máu thì hồi sinh sau 2 giây để test tiếp.
- **Chat nhanh** trong phòng: bấm Enter để gõ, Enter lần nữa để gửi.
- Art placeholder tự vẽ bằng code (`scripts/placeholder_art.gd`), không dùng
  asset của Toram hay game nào khác.

## Hành vi khi host thoát

Host thoát (đóng game hoặc bấm "Thoát phòng") thì **phòng giải tán**:
máy còn lại hiện lại menu chính. Đây là hành vi đã chốt cho bản đầu.

## Cách chạy (Windows)

1. Cài **Godot 4.7** (bản Standard, không cần .NET) tại
   https://godotengine.org/download — giải nén là chạy, không cần cài đặt.
2. Mở Godot → **Import** → chọn thư mục project này → **Open**.
3. Bấm **F5** (hoặc nút Play) để chạy game.
4. Cửa sổ game 1280x720. Chơi 1 mình vẫn vào phòng được (host rồi bắt đầu chơi).

## Kiểm chứng 2 máy (mốc kiểm chứng GĐ1)

1. **Máy A (host):** vào game → bấm **Tạo phòng (Host)** → màn hình hiện
   "IP của bạn: 192.168.x.x". Bấm **Bắt đầu chơi**.
2. **Máy B (client):** vào game → nhập IP của máy A vào ô → bấm
   **Vào phòng (Join)** → thấy "Đã kết nối" → bấm **Bắt đầu chơi**.
3. Cả 2 máy thấy nhau di chuyển trên sàn đấu (nhân vật màu khác nhau,
   tên P1/P2 trên đầu).
4. Cả 2 cùng đánh **Bù nhìn tập đánh**: thanh máu của bù nhìn giảm giống
   nhau trên cả 2 màn hình.
5. Bấm Enter, gõ tin nhắn, Enter lần nữa: cả phòng thấy tin nhắn.
6. Máy A thoát game: máy B tự về lại menu chính (phòng đóng).

Lưu ý: 2 máy phải **cùng mạng LAN** (cùng Wi-Fi). Windows Firewall có thể hỏi
quyền mạng cho Godot — chọn **Allow** (mạng Private). Cổng dùng: **8910/UDP**.

## File log — khi gặp lỗi thì gửi file này

Game ghi lại mọi sự kiện mạng + lỗi ra file:

- **`game.log`** (log của game): `%APPDATA%\Godot\app_userdata\T-Lite Chloride\logs\game.log`
  Ghi: mở phòng / vào phòng, ai vào ai ra, host thoát, đánh bù nhìn,
  hồi sinh, chat, lỗi kết nối (kèm gợi ý: sai IP / host chưa mở phòng /
  Firewall chặn UDP 8910).
- **`godot.log`** (log của engine, Godot tự ghi): cùng thư mục trên.
  Ghi lỗi của engine (vd lỗi script, lỗi load file).

Khi chạy thử gặp lỗi: đóng game, mở thư mục trên, gửi cả 2 file
`game.log` + `godot.log` (hoặc chụp đoạn cuối của chúng) cho Muse để sửa.
Mỗi lần mở game sẽ ghi tiếp vào cuối file cũ, kèm dòng tiêu đề phiên mới
có ngày giờ, nên nhớ ghi lại khoảng thời gian xảy ra lỗi.

## Cấu trúc project

```
main.tscn                 Root: chuyển menu <-> màn chơi (+ test headless)
project.godot             Cài đặt 2D, pixel art (texture filter nearest),
                          phím WASD/chuột/chat, autoload Net
scripts/
  network.gd              Autoload Net: ENet host/join, tối đa 4 người
  logger.gd               GameLog: ghi log ra user://logs/game.log
  main.gd                 Chuyển cảnh + test headless 2 máy (loopback)
  menu.gd                 Menu Host/Join
  game.gd                 Màn chơi: sàn, spawner, HUD, chat, thoát phòng
  player.gd               Nhân vật: di chuyển, ngắm, vung kiếm, HP/MP/Burst
  dummy.gd                Bù nhìn: HP đồng bộ, RPC nhận sát thương
  arena.gd                Vẽ sàn đấu kẻ ô
  placeholder_art.gd      Texture pixel tự vẽ bằng code
scenes/
  main_menu.tscn  game.tscn  player.tscn  dummy.tscn
```

## Số liệu GĐ1 (theo GDD §3, placeholder)

- Nhân vật: HP 100, MP 50, tốc chạy 200 px/s (~3.2 ô/s).
- Đánh thường: 10 sát thương/đòn, hồi 4 MP khi trúng, hồi chiêu 0.45s.
- Burst: +1 điểm / 50 sát thương gây ra (thang 0–100).
  GĐ1 chỉ tích Burst, **chưa kích hoạt Full Burst** (sang GĐ2).
- Bù nhìn: HP 500.

## Trạng thái kiểm chứng (14/11/2026)

- Godot **4.7.2** headless (Linux VM): import project sạch 0 lỗi;
  `--check-only` pass cho 5/8 script (arena, dummy, network,
  placeholder_art, player); 3 script dùng autoload `Net` (game, main,
  menu) báo "Identifier not found: Net" khi kiểm tra rời rạc — đây là
  giới hạn của `--check-only`, không phải lỗi thật (chạy thật trong
  project thì autoload `Net` có sẵn, host test đã chứng minh).
- Host test headless: ENet server bind thành công, spawn nhân vật host,
  bù nhìn HP 500 → 490 sau `take_damage(10)`, chạy 30 giây với
  **0 lỗi / 0 cảnh báo**.
- **Chưa kiểm chứng được trong VM:** đồng bộ 2 máy (vị trí, máu bù nhìn,
  chat) — VM chặn `UDP send` nên client ENet không kết nối được
  (lỗi `Sending failed!` + `PermissionError` khi thử socket UDP bằng
  Python). Phần này **bắt buộc kiểm chứng trên Windows 2 máy** theo
  mục "Kiểm chứng 2 máy" ở trên. Chưa chạy được trên Windows ở đây nên
  không khẳng định gì về Windows.

## GĐ tiếp theo (GĐ2)

Cây Kiếm 3 chiêu (Chém mạnh / Đập choáng / Hồi sức), né (dash), đỡ,
boss đầu Altoilia đủ moveset, kích hoạt Full Burst đội ngũ.
