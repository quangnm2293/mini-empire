# Đế Chế Mini — Game Design Document

## Khái niệm
Mini-RTS lấy cảm hứng từ Age of Empires II, rút gọn cho điện thoại: một bản đồ
1920×1920, người chơi (xanh dương) xây căn cứ ở góc dưới-trái, địch (đỏ) ở góc
trên-phải. Thu thập tài nguyên → xây dựng → huấn luyện quân → phá Nhà Chính địch
trước khi các đợt tấn công của địch phá Nhà Chính của mình.

## Vòng lặp chính
1. Sai Dân thu thập Gỗ / Vàng / Thịt (đi → thu thập 2,5 giây → mang 10 đơn vị →
   về Nhà Chính nộp → tự lặp lại; điểm tài nguyên cạn thì Dân tự tìm điểm khác
   cùng loại).
2. Dùng tài nguyên xây Doanh Trại / Nhà / Tháp Canh (Dân đi xây, HP công trình
   tăng dần theo tiến độ).
3. Huấn luyện Lính Kiếm / Cung Thủ, tổ chức phòng thủ và phản công.
4. Mỗi ~75 giây địch mở một đợt tấn công lớn dần về căn cứ người chơi.
5. Thắng: phá Nhà Chính địch. Thua: mất Nhà Chính của mình.

## Kinh tế (bắt đầu: 200 Gỗ, 100 Vàng, 150 Thịt)
| Tài nguyên | Nguồn | Ghi chú |
|---|---|---|
| Gỗ | Cây (120/cây) | Hữu hạn, cạn thì biến mất |
| Vàng | Mỏ vàng (300/mỏ) | Hữu hạn |
| Thịt | Bụi quả (150/bụi) | Hữu hạn |

Dân số: mở đầu tối đa 10, mỗi Nhà hoàn thành +5, trần cứng 30.

## Đơn vị
| Đơn vị | Giá | Thời gian huấn luyện | HP | Sát thương | Tầm đánh |
|---|---|---|---|---|---|
| Dân | 50 Thịt | 5s (tại Nhà Chính) | 50 | 3 | Cận chiến |
| Lính Kiếm | 60 Thịt + 20 Vàng | 8s (Doanh Trại) | 65 | 9 | Cận chiến |
| Cung Thủ | 50 Thịt + 40 Gỗ | 10s (Doanh Trại) | 40 | 7 | 170 (bắn tên) |

## Công trình
| Công trình | Giá xây | HP | Chức năng |
|---|---|---|---|
| Nhà Chính | Có sẵn | 1200 | Huấn luyện Dân; nơi nộp tài nguyên; mục tiêu thắng/thua |
| Doanh Trại | 150 Gỗ | 700 | Huấn luyện Lính Kiếm + Cung Thủ |
| Nhà | 40 Gỗ | 300 | +5 giới hạn dân số |
| Tháp Canh | 100 Gỗ + 50 Vàng | 550 | Tự bắn địch trong tầm 200, sát thương 8 |

Hàng huấn luyện: tối đa 5 đơn vị/công trình, trừ tiền ngay khi xếp hàng,
chặn khi đạt giới hạn dân số (tính cả số đang huấn luyện).

## Địch & AI
- Căn cứ địch: Nhà Chính, Doanh Trại, 2 Tháp Canh, lính gác (luôn duy trì
  2 lính gác tại căn cứ).
- Đợt tấn công: đợt đầu ở giây ~60, sau đó mỗi ~75 giây; đợt N có 2+N quân
  (trộn Lính Kiếm/Cung Thủ), hành quân tấn công thẳng tới Nhà Chính người
  chơi, gặp địch trên đường thì đánh.
- Quân tự tìm mục tiêu trong tầm nhìn 220, bị đánh thì đánh trả; tháp tự bắn.

## Điều khiển (chạm trước, chuột tương đương)
- Kéo trên mặt đất (quá 12px): di chuyển camera (giới hạn trong bản đồ).
- Chạm Dân/Lính/Công trình của mình: chọn (hiện vòng chọn + bảng dưới).
- Đã chọn đơn vị: chạm điểm tài nguyên = thu thập (Dân), chạm địch = tấn
  công, chạm đất trống = di chuyển; hiện hiệu ứng đánh dấu mục tiêu.
- Đã chọn Dân: bảng dưới có nút xây Doanh Trại / Nhà / Tháp Canh kèm giá;
  chạm nút → chế độ đặt móng → chạm vị trí hợp lệ để đặt; Esc/chuột phải hủy.
- Đã chọn Nhà Chính/Doanh Trại: nút huấn luyện kèm giá, mờ khi thiếu tiền,
  đầy hàng chờ hoặc chạm trần dân số.
- Thanh trên: Gỗ/Vàng/Thịt, dân số, đồng hồ, nút tạm dừng (Esc/P cũng được).
- Thông báo nổi: thiếu tài nguyên, trần dân số, địch tấn công, xây xong.

## Thắng / Thua
- Phá Nhà Chính địch → màn THẮNG (thời gian, số đơn vị đã huấn luyện).
- Mất Nhà Chính → màn THUA. Cả hai có nút "Chơi lại".

## Đơn giản hóa so với AoE II thật (chủ động)
- Không sương mù chiến tranh (fog of war), không đời/thăng cấp công nghệ.
- Địch KHÔNG thu thập tài nguyên và KHÔNG xây dựng — chỉ có căn cứ dựng sẵn,
  lính gác và các đợt tấn công theo kịch bản thời gian.
- Một bản đồ duy nhất, không bản đồ ngẫu nhiên; không hải quân/kỵ binh/xe bắn đá.
- Di chuyển bằng lái tay (steering) + né vòng tròn, không có tìm đường A*.
- Chọn từng đơn vị một (không kéo khung chọn nhiều quân), không đội hình.
