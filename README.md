# T-Lite Chloride — GĐ2: Prototype gameplay (boss Altoilia + Full Burst)

Game 2D co-op top-down pixel art, lấy cảm hứng cơ chế PvE của Toram Online,
nội dung tự làm mới hoàn toàn. Engine: **Godot 4.7** (GDScript).

## GĐ2 làm được gì (prototype gameplay — boss Altoilia + Full Burst)

- **Cây Kiếm 3 chiêu** (phím 1/2/3, số liệu theo GDD §3): Chém mạnh
  (25 dmg / 10 MP / hồi chiêu 3s), Đập choáng (12 dmg + choáng boss 1.5s /
  8 MP / 8s — để ngắt chiêu Tụ lực), Hồi sức (+20 HP / 15 MP / 12s).
  Hồi chiêu từng chiêu hiện trên HUD. Thiếu MP hoặc đang hồi chiêu thì
  không dùng được.
- **Né lướt** (Shift hoặc Space): lướt 128px theo hướng di chuyển (đứng yên
  thì lướt theo hướng ngắm), bất tử 0.3s, hồi chiêu 1.5s, không tốn MP.
- **Đỡ** (giữ chuột phải, chỉ Kiếm): giảm 60% sát thương nhận trong 0.5s,
  hồi chiêu 2s. Khi đỡ có vòng cung xanh trước mặt.
- **Boss Altoilia** (HP 600, ở giữa sàn): đủ 6 chiêu — Gai đất (15 dmg +
  hất ngã), AoE tròn (20 dmg, nổ sau 1.5s), Sóng nhạc (12 dmg + làm chậm,
  3 vòng lan ra, khe giữa 2 vòng an toàn), Tia laser (25 dmg + hất văng,
  quét ngang sàn), Lốc xoáy (10 dmg/giây, chỉ phase cuối), Tụ lực
  (đứng yên 3s, hồi 20% HP nếu không bị Đập choáng ngắt). Mỗi chiêu đều
  có vùng đỏ báo trước (telegraph).
- **3 phase:** 100–50% (Gai đất + AoE), 50–25% (thêm Sóng nhạc + Tia
  laser), dưới 25% (thêm Lốc xoáy + biến hình + đánh nhanh hơn).
- **Phá bộ phận** (mỗi bộ phận 100 HP): cánh hoa → mất Lốc xoáy; đàn
  nhạc → mất Sóng nhạc; lõi máy → mất Tia laser; vương miện → mất Tụ lực.
- **Full Burst** (phím F): khi thanh Burst trung bình cả đội đạt 100%
  (chơi đơn: thanh của mình 100%) thì bấm được, tối đa 2 lần/trận boss.
  Chuỗi 3 giây: cả đội bất tử, boss bị khóa, mỗi người tung 1 đòn rồi đòn
  kết hợp cuối. Sát thương: solo ~85, 2 người ~130, 4 người ~250.
  Sau Burst: cả đội -20% sát thương 5 giây, boss Choáng 2 giây.
- **Thắng/thua:** boss hết HP → hiện "Đã đánh bại Altoilia!" + nút về
  menu. Người chơi hết HP → hồi sinh sau 3s tại điểm spawn với đầy HP
  (boss giữ nguyên HP) để test tiếp.
- **Map nhà thờ:** sàn đá cẩm thạch, thảm đỏ giữa sàn, cửa kính màu dọc
  2 mép, 4 cột đá làm vật cản, chi tiết bánh răng + nốt nhạc ở rìa.
  Bù nhìn tập đánh dời ra góc sàn (200, 200) để test sát thương.
  **Map mới (Gemini, 15/11):** `scripts/arena.gd` viết lại theo thiết kế
  `THIET_KE_MAP.md`, lưới 32×32, tự nạp 13 tile ảnh từ `assets/map/`
  (đá cẩm thạch, thảm, cửa kính, cột, bánh răng, nốt nhạc); tile viền đá
  quá tối nên không dùng ảnh, vẽ bằng code. Khi chạy game in dòng
  `[Map] Da nap 13/14 tile anh`.
- HUD thêm: ô hồi chiêu 3 kỹ năng, thanh HP boss + tên phase + trạng thái
  bộ phận đã phá, nhắc "Bấm F — FULL BURST SẴN SÀNG!" khi Burst đầy.
- Log (game.log) ghi: boss đổi phase, bộ phận bị phá, Tụ lực bị ngắt /
  hồi máu xong, kích hoạt Full Burst, thắng/thua, hồi sinh.

## GĐ1 làm được gì (nền online)

- Menu: **Tạo phòng (Host)** hoặc **Vào phòng (Join)** bằng IP của host.
  Host xem IP của mình ngay trên menu để gửi cho bạn.
- Tối đa **4 người/phòng**, mô hình listen-server (host vừa host vừa chơi).
- Người chơi: di chuyển WASD, ngắm bằng chuột, đánh thường (chuột trái).
  Thanh HP / MP / Burst hiển thị trên màn hình.
- **Bù nhìn tập đánh**: HP đồng bộ cả phòng — 2 người cùng đánh thì máu giảm
  giống nhau trên cả 2 màn hình. Hết máu thì hồi sinh sau 2 giây để test tiếp.
- **Chat nhanh** trong phòng: bấm Enter để gõ, Enter lần nữa để gửi.
- **Chơi đơn (Solo)** (thêm 15/11): bấm nút "Chơi đơn (Solo)" trên menu để vào
  màn chơi ngay, không cần mạng — di chuyển, đánh bù nhìn, HUD đầy đủ.
  Chat chỉ dùng khi chơi mạng.
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
4. Cửa sổ game 1280x720. Muốn chơi đơn thì bấm nút **Chơi đơn (Solo)** trên
   menu — vào màn chơi ngay, không cần host hay nhập IP.

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
  game.gd                 Màn chơi: sàn, spawner, HUD, chat, thoát phòng,
                          boss, Full Burst, thắng/thua
  player.gd               Nhân vật: di chuyển, ngắm, vung kiếm, HP/MP/Burst,
                          Kiếm 3 chiêu, né, đỡ, chết/hồi sinh
  dummy.gd                Bù nhìn: HP đồng bộ, RPC nhận sát thương
  boss.gd                 Boss Altoilia: AI, 6 chiêu, telegraph, phase
  boss_part.gd            Bộ phận boss: HP riêng, phá được
  arena.gd                Vẽ sàn đấu nhà thờ (cẩm thạch, kính màu, cột đá)
  placeholder_art.gd      Texture pixel tự vẽ bằng code
scenes/
  main_menu.tscn  game.tscn  player.tscn  dummy.tscn
```

## Số liệu GĐ2 (theo GDD §3/§5/§6; số tạm liệt kê riêng ở dưới)

- Nhân vật: HP 100, MP 50, tốc chạy 200 px/s (~3.2 ô/s), DEF 0.
- Đánh thường: 10 sát thương/đòn, hồi 4 MP khi trúng, hồi chiêu 0.45s.
- Kiếm 1 "Chém mạnh": 25 dmg / 10 MP / hồi chiêu 3s.
- Kiếm 2 "Đập choáng": 12 dmg + choáng boss 1.5s / 8 MP / hồi chiêu 8s.
- Kiếm 3 "Hồi sức": +20 HP / 15 MP / hồi chiêu 12s.
- Né: lướt 128px, bất tử 0.3s, hồi chiêu 1.5s, không tốn MP.
- Đỡ: giảm 60% sát thương trong 0.5s, hồi chiêu 2s.
- Burst: +1 điểm / 50 sát thương gây ra, +1 điểm / 30 HP hồi (thang 0–100).
- Full Burst: tổng sát thương = 50 + 30n + 5n² (n = số người sống lúc
  kích hoạt): 1 người 85, 2 người 130, 4 người 250. Tối đa 2 lần/trận.
  Sau Burst: cả đội -20% sát thương 5s, boss Choáng 2s.
- Boss Altoilia: HP 600. Gai đất 15, AoE tròn 20, Sóng nhạc 12, Tia
  laser 25, Lốc xoáy 10/giây, Tụ lực hồi 120 HP (20%).
- Bù nhìn: HP 500.

### Số tạm (không có trong GDD, tự chọn để test, chỉnh sau)

- Bộ phận boss: 100 HP mỗi cái.
- Thời gian báo trước (telegraph): Gai đất 0.8s, AoE tròn 1.5s
  (phase 3: 0.7s / 1.2s), Tia laser 0.8s.
- Thời gian chờ giữa các chiêu của boss: 1.6s (phase 1), 1.3s (phase 2),
  0.9s (phase 3); chờ 2s đầu trận rồi boss mới đánh.
- Sóng nhạc: 3 vòng, cách nhau 130px, rộng 40px, lan 220px/s, xa nhất 520px.
- Tia laser: dài 850px, quét 100 độ trong 1.4s.
- Lốc xoáy: 55px/s, bán kính 48px, tồn tại 6s.
- Tụ lực: chỉ dùng khi boss dưới 90% HP và vương miện còn nguyên.
- Sau mỗi lần bị choáng, boss kháng choáng 4s (chống spam ngắt).
- Chiêu boss không bị cột đá chặn (telegraph xuyên qua cột — đơn giản hóa
  cho bản prototype).
- Đỡ: bấm chuột phải là kích hoạt cửa sổ đỡ 0.5s (không cần giữ đủ 0.5s).
- Người chơi chết thì hồi sinh 1 mình sau 3s (chưa có thua cả đội).

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
- **Sửa lỗi 15/11 (vào màn chơi khi chưa nối được host):** đã kiểm chứng lại
  trong VM sau khi sửa — host chạy 0 lỗi, nhân vật host spawn đủ, bù nhìn
  500 → 490; client nối thất bại thì dọn peer chết ngay, thoát sạch, không
  còn spam lỗi `get_unique_id`. Đồng bộ 2 máy vẫn phải kiểm chứng trên
  Windows.
- **Chơi đơn 15/11:** kiểm chứng headless trong VM — nhân vật solo spawn đủ
  (1 người), di chuyển sang phải 240px sau 1,2 giây, đánh bù nhìn 500 → 490,
  chạy 0 lỗi. Hồi quy lỗi 15/11 (vào màn chơi lúc join chưa xong): tự về
  menu, 0 lần spam lỗi. Host chạy lại sau khi thêm solo: không đổi
  (local-damage PASS, 0 lỗi).
- **Sửa lỗi đánh không ra sát thương 15/11:** bù nhìn trong `dummy.tscn`
  thiếu hẳn CollisionShape2D (hình va chạm chỉ khai báo mà không gắn vào
  node) nên vùng kiếm không bao giờ chạm được nó; nhân vật cũng thiếu hình
  va chạm thân và sàn đấu chưa có tường vật lý. Đã gắn đủ hình va chạm
  (bù nhìn 28×28, nhân vật r=10) + 4 tường sàn layer 4. Kiểm chứng
  headless: vung kiếm ở cự ly 40px thì bù nhìn 500 → 490, ở 100px thì
  không trúng; solo/host chạy lại không đổi.
- **GĐ2 (15/11):** kiểm chứng headless trong VM, 0 lỗi:
  - `--test-skills`: Kiếm 1 gây 25 dmg (bù nhìn 500→475, MP 50→44),
    Kiếm 2 gây 12 dmg (475→463, MP 50→46), Kiếm 3 hồi 20 HP (50→70,
    MP 50→35); đang hồi chiêu / thiếu MP thì không dùng được; né lướt
    145px + bất tử; đỡ giảm 60% (nhận 20 → mất 8 HP, 100→92).
  - `--test-boss`: đánh thường trúng boss qua kiếm (600→590); đổi phase
    ở 300 HP (phase 2) và 150 HP (phase 3), hồi máu không lùi phase;
    phá cánh hoa → mất Lốc xoáy, phá 3 bộ phận còn lại → mất Sóng nhạc /
    Tia laser / Tụ lực; Tụ lực bị Đập choáng ngắt (không hồi máu);
    Full Burst solo gây 84 dmg (388→304), dùng 1 lần, Burst về 0;
    chết → hồi sinh sau 3s đầy HP (100), boss giữ HP; thắng → banner
    "Đã đánh bại Altoilia!" hiện.
  - `--test-boss-atk`: 6 chiêu gây đúng số lên người chơi — Gai đất
    100→85, AoE 100→80, Sóng nhạc 100→64 (3 vòng × 12), Tia laser
    100→75, Lốc xoáy 100→90 (1 tick 10 dmg), Tụ lực hồi 300→420.
  - `--test-ai`: boss tự chạy AI, 4 chiêu trong 12s, người chơi 100→35.
  - Hồi quy cũ: `--test-swing` PASS (40px trúng, 100px không trúng),
    `--test-solo` PASS, `--test-fail` PASS (về menu, 0 spam lỗi),
    `--test-host` như cũ (local-damage PASS, dummy-hp-sync PASS).
  - GameLog ghi đủ: đổi phase, phá bộ phận, Tụ lực bị ngắt/hồi máu,
    Full Burst, chết/hồi sinh, thắng.
  - **Map mới (Gemini, 15/11):** import 0 lỗi, arena.gd check-only
    sạch, chạy solo in `[Map] Da nap 13/14 tile anh`; hồi quy skills
    7/7, boss 10/10, boss-atk 6/6, swing/solo/fail/host như cũ.
    **Lưu ý:** 13 file tile PNG là binary nên không đẩy được lên repo
    qua công cụ hiện tại — bản đầy đủ (kèm tile) nằm trong file zip giao
    cho Minhdak; repo chỉ có code, thiếu tile thì map tự vẽ bằng code.
- **Chưa kiểm chứng được trong VM:** đồng bộ 2 máy (vị trí, máu bù nhìn,
  boss, chat, Full Burst đội ngũ) — VM chặn `UDP send` nên client ENet
  không kết nối được (lỗi `Sending failed!` + `PermissionError` khi thử
  socket UDP bằng Python). Phần này **bắt buộc kiểm chứng trên Windows
  2 máy** theo mục "Kiểm chứng 2 máy" ở trên. Chưa chạy được trên
  Windows ở đây nên không khẳng định gì về Windows. Boss AI / chiêu /
  Full Burst trên mạng cũng chưa kiểm chứng 2 máy (chỉ kiểm chứng solo
  trong VM); cấu trúc đã làm theo hướng server-authoritative (AI + sát
  thương boss chỉ chạy trên host, chiêu báo qua RPC, HP đồng bộ).

## Sửa lỗi 15/11/2026 — vào màn chơi khi chưa nối được host

Lỗi gặp trên Windows: bấm Host rồi bấm Vào phòng (Join) mà chưa nối được host,
nút **Bắt đầu chơi** vẫn hiện (do lần host trước để lại) → bấm vào thì vào màn
chơi rỗng, không có nhân vật, không di chuyển được, console spam lỗi
"The multiplayer instance isn't currently active" (game.gd gọi
`multiplayer.get_unique_id()` mỗi khung hình trong khi peer đã chết).

Đã sửa:

- Menu ẩn nút **Bắt đầu chơi** mỗi khi bắt đầu lượt Host/Join mới hoặc khi
  thất bại — chỉ hiện lại khi host/join thành công thật.
- Nối host thất bại thì dọn peer chết ngay (`network.gd`), và nếu đang ở màn
  chơi thì tự về menu.
- `game.gd` chỉ gọi `get_unique_id()` khi peer đang nối thật.

**Thử trên 1 máy:** mở game 2 cửa sổ (1 cửa sổ bấm Host, cửa sổ kia nhập
`127.0.0.1` rồi Join) — không cần 2 máy vẫn kiểm tra được đồng bộ.

## GĐ tiếp theo (GĐ3)

Đủ 4 nhánh vũ khí (Kiếm/Cung/Phép/Tay không) + nhánh Hỗ trợ, đồ rớt,
nâng cấp/tinh luyện, lưu game JSON. Sau đó GĐ4: thêm map, quái, nhiều
boss, chế đồ, nhiệm vụ; mở Thương + Song kiếm.
