# Đế Chế Mini — Kiến trúc kỹ thuật

Engine: Godot 4.7.2, GDScript, GL Compatibility, viewport dọc 720×1280,
stretch `canvas_items` / aspect `keep`. Toàn bộ thực thể là Node2D, di chuyển
bằng steering thủ công — không dùng NavigationServer/physics bodies.

## Cấu trúc
```
project.godot / export_presets.cfg (Web, thread_support=false)
scenes/  main.tscn (Main Node2D + World + Camera2D + HUD CanvasLayer)
         unit.tscn · building.tscn · resource_node.tscn · projectile.tscn
scripts/ main.gd · unit.gd · building.gd · resource_node.gd · projectile.gd · hud.gd
assets/  sprite PNG sinh bằng PIL + grass_map.png (nền cỏ 1920×1920)
sounds/  WAV sinh bằng Python (sine/noise)
docs/    GDD.md · KIEN-TRUC.md · QA.md
shots/   base.png · economy.png · battle.png
```

## Vai trò từng script
- `main.gd` (node gốc, group `game`): trạng thái trận (tài nguyên, dân số,
  đồng hồ, thắng/thua), dựng bản đồ/căn cứ/điểm tài nguyên, đầu mối nhập liệu
  duy nhất (`_unhandled_input`), camera, chọn & ra lệnh, đặt móng xây dựng,
  AI địch (đợt tấn công + bổ sung lính gác), âm thanh (pool AudioStreamPlayer),
  hiệu ứng (CPUParticles2D, chữ "+10" nổi qua HUD), QA hooks (`--qa-test`,
  `--shot`, `--sanity-test`).
- `unit.gd` (class GameUnit): máy trạng thái
  `IDLE, MOVE, GATHER_MOVE, GATHER, RETURN, BUILD_MOVE, BUILD, ATTACK_MOVE,
  CHASE, ATTACK, DEAD`; tự tìm mục tiêu, đánh trả khi bị đánh, né/tránh vật
  cản bằng lực đẩy vòng tròn (đơn vị đẩy nhẹ, công trình/điểm tài nguyên là
  vật cản cứng), vẽ vòng chọn + thanh máu + bóng.
- `building.gd` (class GameBuilding): HP, xây dựng theo tiến độ (HP tăng
  10%→100%), hàng huấn luyện tối đa 5 (đếm ngược trong `_process`, gọi
  `main.on_training_complete`), tháp tự tìm mục tiêu tầm 200 và bắn đạn.
- `resource_node.gd` (class ResourceNode): loại tài nguyên, trữ lượng hữu
  hạn, co nhỏ/mờ dần khi cạn, biến mất khi hết.
- `projectile.gd`: đạn bay bám vị trí mục tiêu hiện tại, trúng thì gọi
  `take_damage(damage, source)` trên mục tiêu; tự hủy sau 2 giây.
- `hud.gd` (CanvasLayer, process_mode Always để hoạt động khi tạm dừng):
  tự dựng UI bằng code — thanh tài nguyên, bảng ngữ cảnh dưới (nút ≥64px),
  thông báo nổi, lớp phủ tạm dừng/kết thúc, chữ nổi "+10". Root Control để
  `mouse_filter = IGNORE`, chỉ panel/nút thật mới chặn chạm, nên chạm trên
  bản đồ luôn xuống được `_unhandled_input` của main.

## Mô hình nhập liệu
- Một nơi xử lý duy nhất: `main._unhandled_input`.
- Phân biệt chạm/kéo: ghi vị trí lúc nhấn; di chuyển ≤12px khi thả = chạm
  (ra lệnh/chọn), >12px = kéo camera từ vị trí camera lúc bắt đầu nhấn.
- Hỗ trợ cả `InputEventMouseButton/Motion` và `InputEventScreenTouch/Drag`;
  khóa theo nguồn sự kiện đầu tiên (chuột hoặc chạm) để sự kiện mô phỏng
  (emulate touch/mouse) không nhân đôi lệnh. `project.godot` bật cả
  `emulate_touch_from_mouse` và `emulate_mouse_from_touch`.
- Tọa độ: `_screen_to_world` qua `get_canvas_transform().affine_inverse()`.
- Esc/P: tạm dừng (Esc hủy chế độ đặt móng trước); chuột phải hủy đặt móng.

## Nhóm (groups) & đội
- Team: 0 = người chơi, 1 = địch.
- Groups: `player_units`, `enemy_units`, `player_buildings`,
  `enemy_buildings`, `resources_nodes`; truy vấn kẻ địch gần nhất ở main
  (`find_nearest_enemy`) dùng chung cho lính, tháp và AI.

## Âm thanh & hiệu ứng
WAV tổng hợp bằng Python: click, chặt (chop), nộp tài nguyên (deposit), kiếm,
tên, tháp bắn, đặt móng, huấn luyện xong, kèn báo đợt tấn công, thắng/thua,
nhạc nền pad lặp nhẹ. Phát qua pool 14 AudioStreamPlayer trong main.
Hiệu ứng: burst hạt khi chết/nộp tài nguyên/đánh dấu mục tiêu, chữ "+10" bay,
thanh máu vẽ bằng `_draw`, công trình đang xây mờ + thanh tiến độ "Đang xây".
