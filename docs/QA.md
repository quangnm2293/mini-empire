# Đế Chế Mini — Biên bản QA

Môi trường: Godot 4.7.2-stable trên VM (không GPU, render phần mềm qua Xvfb cho
phần chụp ảnh; headless cho import/QA logic).

## 1. Import headless
Lệnh: `godot --headless --path ~/workspace/mini-empire --import`
Kết quả: exit 0, không có SCRIPT ERROR / Parse Error / Failed to load script
(0 dòng ERROR trong log; đã lọc bỏ nhiễu thiết bị âm thanh ALSA của VM).

## 2. QA tự động (`--qa-test`, seed xác định)
Lệnh: `godot --headless --path . -- --qa-test` → exit 0. Nguyên văn:

```
QA: game started, villagers=3, wood=200, gold=100, food=150
QA: both town centers exist OK
QA: player starts with 3 villagers OK
QA: starting resources are exact OK
QA: a tree is available OK
QA: villager completed a gather/deposit cycle and wood increased OK
QA: training a villager deducts 50 food OK
QA: trained villager spawned from queue OK
QA: enemy combat dummy exists OK
QA: player swordsman damages enemy in combat OK
QA: enemy wave spawns when its timer fires OK
QA: destroying enemy Town Center wins the game OK
QA PASS
```

Bao phủ: khởi đầu đúng số liệu; vòng thu thập→nộp gỗ tăng thật; huấn luyện Dân
trừ đúng 50 thịt và sinh quân từ hàng chờ; cận chiến gây sát thương; hẹn giờ
đợt tấn công của địch sinh quân; phá Nhà Chính địch qua API sát thương thường
→ trạng thái thắng. (QA dùng hook tăng tốc độ/timer, giá trị gameplay gốc giữ
nguyên. Log còn 1 dòng "resources still in use at exit" khi thoát ngay sau
thắng — nhiễu dọn dẹp lúc quit, không phải lỗi gameplay.)

## 3. Ảnh chụp (`--shot`, Xvfb, không headless)
Chế độ demo: mở đầu chụp căn cứ → cho 3 Dân thu thập thật 22 giây → đặt móng
Doanh Trại và cho Dân xây → chụp kinh tế (giây ~31) → dựng trận đụng độ gần
tháp địch → chụp chiến đấu. Nguyên văn log:

```
SHOT: saved base.png size=(720, 1280) error=0
SHOT: saved economy.png size=(720, 1280) error=0
SHOT: saved battle.png size=(720, 1280) error=0
SHOT: done elapsed=33.6 fps=28 entities=76 resources={ "wood": 250, "gold": 140, "food": 230 }
```

- `shots/base.png`: thanh tài nguyên (Gỗ 200 / Vàng 100 / Thịt 150 / Dân 3/10 /
  00:01), Nhà Chính cờ xanh + sao vàng, 3 Dân áo xanh quanh nhà, cây và bụi
  quả, bảng hướng dẫn dưới. Đúng khung mở đầu.
- `shots/economy.png`: tài nguyên đã tăng thật (250/140/230, 00:31), Doanh
  Trại đang xây (chữ "Đang xây" + thanh tiến độ, công trình mờ), Dân đứng xây
  cạnh móng, mỏ vàng phía dưới, chữ nổi "+10 thịt" sau khi nộp tài nguyên,
  bụi quả và cây xung quanh.
- `shots/battle.png`: đụng độ dưới tháp địch — cụm Lính Kiếm xanh áp sát tháp,
  Cung Thủ hai bên, lính đỏ + tháp cờ đỏ, Doanh Trại/Nhà Chính địch phía trên,
  thanh máu trên đầu nhiều đơn vị đã tụt; dân số hiển thị 7/10 (quân dựng cho
  cảnh chụp được tính vào). Quân cận chiến đứng khá chồng nhau khi dồn vào
  một mục tiêu — giới hạn đã biết của steering đơn giản.

## 4. Vận hành không người chơi (`--sanity-test`, Xvfb)
3 Dân được lệnh thu thập 3 loại tài nguyên rồi để máy tự chạy 45 giây:

```
SANITY: started unattended economy simulation
SANITY: elapsed=45.1 fps_avg=31.4 entities=62 resources={ "wood": 320, "gold": 170, "food": 280 }
SANITY PASS
```

- 0 SCRIPT ERROR trong toàn bộ phiên; tài nguyên tăng đều ở cả 3 loại →
  vòng thu thập/nộp/tìm điểm mới chạy bền.
- FPS trung bình 31,4 là số đo bằng render PHẦN MỀM trên VM không GPU với
  ~62 thực thể; trên thiết bị thật có GPU con số sẽ cao hơn. Mật độ quân bị
  giới hạn bởi trần dân số 30 nên tải luôn có trần.

## Hạn chế trung thực
- Âm thanh chưa nghe thử bằng tai (VM không có card tiếng); file WAV đúng
  định dạng và đã nối player đầy đủ.
- Cảm ứng chưa test trên điện thoại thật; dùng chung đường sự kiện chạm/kéo
  với chuột và đã bật emulate hai chiều.
- Di chuyển là steering + né vòng tròn, không A*: quân có thể chồng nhau khi
  dồn đông vào một mục tiêu, và có thể đi đường vòng chưa tối ưu quanh công
  trình lớn.
- Sprite vẽ bằng PIL dạng phẳng; biểu tượng emoji trên thanh tài nguyên phụ
  thuộc font emoji của thiết bị (VM chụp ảnh thiếu font nên vài icon hiện
  dạng ô).
- Địch không thu thập/xây dựng (đơn giản hóa có chủ đích, xem GDD).
