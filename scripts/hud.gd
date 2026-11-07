class_name GameHUD
extends CanvasLayer

signal action_pressed(action_id: String)
signal pause_pressed
signal resume_pressed
signal restart_pressed

var wood_label: Label
var gold_label: Label
var food_label: Label
var pop_label: Label
var time_label: Label
var selected_title: Label
var selected_info: Label
var actions_box: HBoxContainer
var alert_label: Label
var pause_overlay: Control
var end_overlay: Control
var end_title: Label
var end_info: Label
var float_layer: Control
var alert_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := PanelContainer.new()
	top.name = "TopBar"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 64
	top.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(top)
	var top_box := HBoxContainer.new()
	top_box.add_theme_constant_override("separation", 14)
	top.add_child(top_box)
	wood_label = _make_label("🪵 Gỗ: 200", 23)
	gold_label = _make_label("🪙 Vàng: 100", 23)
	food_label = _make_label("🍖 Thịt: 150", 23)
	pop_label = _make_label("👥 Dân: 3/10", 23)
	time_label = _make_label("00:00", 23)
	for lab in [wood_label, gold_label, food_label, pop_label]:
		top_box.add_child(lab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(spacer)
	top_box.add_child(time_label)
	var pause_btn := Button.new()
	pause_btn.text = "⏸"
	pause_btn.custom_minimum_size = Vector2(58, 48)
	pause_btn.add_theme_font_size_override("font_size", 26)
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	top_box.add_child(pause_btn)

	alert_label = _make_label("", 28)
	alert_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	alert_label.position = Vector2(-260, 78)
	alert_label.size = Vector2(520, 44)
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.modulate.a = 0.0
	alert_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	root.add_child(alert_label)

	float_layer = Control.new()
	float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(float_layer)

	var bottom := PanelContainer.new()
	bottom.name = "BottomPanel"
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -164
	bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bottom)
	var bottom_box := VBoxContainer.new()
	bottom_box.add_theme_constant_override("separation", 7)
	bottom.add_child(bottom_box)
	selected_title = _make_label("Đế Chế Mini", 25)
	selected_info = _make_label("Chạm vào dân, lính hoặc công trình để chọn. Kéo trên mặt đất để di chuyển bản đồ.", 19)
	bottom_box.add_child(selected_title)
	bottom_box.add_child(selected_info)
	actions_box = HBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 10)
	bottom_box.add_child(actions_box)

	pause_overlay = _make_overlay("TẠM DỪNG", "Trận đấu đang dừng.", true)
	end_overlay = _make_overlay("THẮNG!", "", false)
	pause_overlay.visible = false
	end_overlay.visible = false
	root.add_child(pause_overlay)
	root.add_child(end_overlay)

func _make_label(text: String, font_size: int) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", font_size)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lab

func _make_overlay(title: String, info: String, is_pause: bool) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.03, 0.08, 0.72)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 260)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	var title_label := _make_label(title, 42)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)
	var info_label := _make_label(info, 22)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info_label)
	if is_pause:
		pause_overlay = overlay
		end_title = title_label
		end_info = info_label
		var resume := Button.new()
		resume.text = "Tiếp tục"
		resume.custom_minimum_size = Vector2(260, 64)
		resume.add_theme_font_size_override("font_size", 25)
		resume.pressed.connect(func() -> void: resume_pressed.emit())
		box.add_child(resume)
		var restart := Button.new()
		restart.text = "Chơi lại"
		restart.custom_minimum_size = Vector2(260, 64)
		restart.add_theme_font_size_override("font_size", 25)
		restart.pressed.connect(func() -> void: restart_pressed.emit())
		box.add_child(restart)
	else:
		end_title = title_label
		end_info = info_label
		var again := Button.new()
		again.text = "Chơi lại"
		again.custom_minimum_size = Vector2(260, 64)
		again.add_theme_font_size_override("font_size", 25)
		again.pressed.connect(func() -> void: restart_pressed.emit())
		box.add_child(again)
	return overlay

func refresh_resources(wood: int, gold: int, food: int, pop: int, cap: int, elapsed: float) -> void:
	if wood_label == null:
		return
	wood_label.text = "🪵 Gỗ: %d" % wood
	gold_label.text = "🪙 Vàng: %d" % gold
	food_label.text = "🍖 Thịt: %d" % food
	pop_label.text = "👥 Dân: %d/%d" % [pop, cap]
	var secs: int = int(elapsed)
	time_label.text = "%02d:%02d" % [secs / 60, secs % 60]

func set_selection(title: String, info: String, actions: Array = []) -> void:
	selected_title.text = title
	selected_info.text = info
	for child in actions_box.get_children():
		child.queue_free()
	for action in actions:
		var data: Dictionary = action
		var btn := Button.new()
		btn.text = String(data.get("label", "Hành động"))
		btn.disabled = bool(data.get("disabled", false))
		btn.custom_minimum_size = Vector2(205, 66)
		btn.add_theme_font_size_override("font_size", 20)
		var id: String = String(data.get("id", ""))
		btn.pressed.connect(func() -> void: action_pressed.emit(id))
		actions_box.add_child(btn)

func clear_selection() -> void:
	set_selection("Đế Chế Mini", "Chạm vào dân, lính hoặc công trình để chọn. Kéo trên mặt đất để di chuyển bản đồ.", [])

func show_alert(text: String) -> void:
	alert_label.text = text
	alert_label.modulate = Color(1, 1, 1, 1)
	if alert_tween != null and alert_tween.is_valid():
		alert_tween.kill()
	alert_tween = create_tween()
	alert_tween.tween_interval(1.25)
	alert_tween.tween_property(alert_label, "modulate:a", 0.0, 0.55)

func set_paused(paused: bool) -> void:
	pause_overlay.visible = paused

func show_end(win: bool, info: String) -> void:
	end_title.text = "THẮNG! 🎉" if win else "THUA!"
	end_info.text = info
	end_overlay.visible = true

func show_floating_text(screen_pos: Vector2, text: String, color: Color = Color(1.0, 0.9, 0.3)) -> void:
	var lab := _make_label(text, 25)
	lab.position = screen_pos + Vector2(-24, -26)
	lab.add_theme_color_override("font_color", color)
	float_layer.add_child(lab)
	var tw := create_tween()
	tw.parallel().tween_property(lab, "position:y", lab.position.y - 46.0, 0.9)
	tw.parallel().tween_property(lab, "modulate:a", 0.0, 0.9)
	tw.tween_callback(lab.queue_free)
