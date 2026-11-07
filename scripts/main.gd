extends Node2D

const UnitScene: PackedScene = preload("res://scenes/unit.tscn")
const BuildingScene: PackedScene = preload("res://scenes/building.tscn")
const ResourceScene: PackedScene = preload("res://scenes/resource_node.tscn")
const ProjectileScene: PackedScene = preload("res://scenes/projectile.tscn")
const GroundTexture: Texture2D = preload("res://assets/grass_map.png")

const MAP_SIZE := Vector2(1920, 1920)
const VIEW_SIZE := Vector2(720, 1280)
const BUILD_COSTS := {
	"barracks": {"wood": 150, "gold": 0, "food": 0},
	"house": {"wood": 40, "gold": 0, "food": 0},
	"tower": {"wood": 100, "gold": 50, "food": 0}
}
const BUILD_NAMES := {"barracks": "Doanh Trại", "house": "Nhà", "tower": "Tháp Canh"}
const RESOURCE_NAMES := {"wood": "gỗ", "gold": "vàng", "food": "thịt"}
const SOUND_PATHS := {
	"click": "res://sounds/click.wav", "chop": "res://sounds/chop.wav", "deposit": "res://sounds/deposit.wav",
	"sword": "res://sounds/sword.wav", "arrow": "res://sounds/arrow.wav", "tower": "res://sounds/tower.wav",
	"placed": "res://sounds/placed.wav", "train_ready": "res://sounds/train_ready.wav", "horn": "res://sounds/horn.wav",
	"win": "res://sounds/win.wav", "lose": "res://sounds/lose.wav"
}

var resources: Dictionary = {"wood": 200, "gold": 100, "food": 150}
var elapsed: float = 0.0
var game_state: String = "playing"
var paused_game: bool = false
var selected: Node = null
var placement_kind: String = ""
var player_tc: GameBuilding = null
var enemy_tc: GameBuilding = null
var enemy_barracks: GameBuilding = null
var trained_count: int = 0

var wave_number: int = 0
var wave_timer: float = 60.0
var defender_timer: float = 0.0
var hud_refresh_timer: float = 0.0

var pointer_active: bool = false
var pointer_source: String = ""
var press_screen_pos: Vector2 = Vector2.ZERO
var camera_start_center: Vector2 = Vector2.ZERO
var dragging_camera: bool = false

var qa_mode: bool = false
var qa_failed: bool = false
var qa_fail_reason: String = ""
var shot_mode: bool = false
var sanity_mode: bool = false
var sanity_done: bool = false
var sanity_fps_total: float = 0.0
var sanity_fps_samples: int = 0
var sanity_sample_timer: float = 0.0

var sounds: Dictionary = {}
var audio_players: Array[AudioStreamPlayer] = []
var rng := RandomNumberGenerator.new()

@onready var world: Node2D = $World
@onready var camera: Camera2D = $Camera2D
@onready var hud: GameHUD = $HUD

func _ready() -> void:
	rng.seed = 20261107
	_init_audio()
	_setup_world()
	hud.action_pressed.connect(_on_hud_action)
	hud.pause_pressed.connect(func() -> void: set_paused(true))
	hud.resume_pressed.connect(func() -> void: set_paused(false))
	hud.restart_pressed.connect(restart_game)
	hud.clear_selection()
	_refresh_hud()
	camera.make_current()
	camera.global_position = _clamp_camera(camera.global_position)
	queue_redraw()
	var args := OS.get_cmdline_user_args()
	qa_mode = args.has("--qa-test")
	shot_mode = args.has("--shot")
	sanity_mode = args.has("--sanity-test")
	if qa_mode:
		call_deferred("run_qa_tests")
	elif shot_mode:
		call_deferred("run_shot_mode")
	elif sanity_mode:
		call_deferred("setup_sanity_mode")

func _draw() -> void:
	draw_texture(GroundTexture, Vector2.ZERO)

func _setup_world() -> void:
	player_tc = spawn_building("tc", 0, Vector2(330, 1570), true)
	spawn_unit("villager", 0, Vector2(485, 1495))
	spawn_unit("villager", 0, Vector2(490, 1645))
	spawn_unit("villager", 0, Vector2(205, 1465))

	enemy_tc = spawn_building("tc", 1, Vector2(1580, 340), true)
	enemy_barracks = spawn_building("barracks", 1, Vector2(1385, 395), true)
	spawn_building("tower", 1, Vector2(1370, 570), true)
	spawn_building("tower", 1, Vector2(1715, 570), true)
	var g1 := spawn_unit("swordsman", 1, Vector2(1465, 545)); g1.is_defender = true
	var g2 := spawn_unit("archer", 1, Vector2(1625, 555)); g2.is_defender = true
	spawn_unit("swordsman", 1, Vector2(1535, 665))

	_spawn_resources()
	camera.global_position = Vector2(360, 1280)

func _spawn_resources() -> void:
	var fixed_trees: Array[Vector2] = [
		Vector2(130, 1370), Vector2(215, 1305), Vector2(545, 1315), Vector2(615, 1435),
		Vector2(115, 1695), Vector2(215, 1795), Vector2(625, 1765), Vector2(730, 1435),
		Vector2(905, 760), Vector2(1015, 880), Vector2(835, 1010), Vector2(1180, 1240),
		Vector2(1240, 250), Vector2(1080, 420), Vector2(1760, 850), Vector2(850, 1640)
	]
	for pos in fixed_trees:
		spawn_resource("tree", pos)
	# Deterministic scattered forest, avoiding both bases.
	var attempts: int = 0
	var placed: int = 0
	while placed < 24 and attempts < 240:
		attempts += 1
		var pos := Vector2(rng.randf_range(90, 1830), rng.randf_range(90, 1830))
		if pos.distance_to(Vector2(330, 1570)) < 250.0 or pos.distance_to(Vector2(1580, 340)) < 260.0:
			continue
		var too_close := false
		for child in world.get_children():
			if child is ResourceNode and child.global_position.distance_to(pos) < 92.0:
				too_close = true
				break
		if not too_close:
			spawn_resource("tree", pos)
			placed += 1
	for pos in [Vector2(765, 1645), Vector2(845, 1720), Vector2(705, 1775), Vector2(1045, 1085), Vector2(1160, 975), Vector2(1245, 505)]:
		spawn_resource("gold", pos)
	for pos in [Vector2(560, 1475), Vector2(655, 1535), Vector2(470, 1810), Vector2(880, 1185), Vector2(1365, 725)]:
		spawn_resource("berry", pos)

func _process(delta: float) -> void:
	if game_state == "playing" and not paused_game:
		elapsed += delta
		wave_timer -= delta
		defender_timer += delta
		if wave_timer <= 0.0:
			spawn_enemy_wave()
			wave_timer = 75.0
		if defender_timer >= 15.0:
			defender_timer = 0.0
			_maintain_enemy_defenders()
		if sanity_mode:
			sanity_sample_timer += delta
			if sanity_sample_timer >= 1.0:
				sanity_sample_timer = 0.0
				sanity_fps_total += Engine.get_frames_per_second()
				sanity_fps_samples += 1
			if elapsed >= 45.0 and not sanity_done:
				sanity_done = true
				var avg_fps: float = sanity_fps_total / maxf(1.0, float(sanity_fps_samples))
				print("SANITY: elapsed=%.1f fps_avg=%.1f entities=%d resources=%s" % [elapsed, avg_fps, world.get_child_count(), str(resources)])
				print("SANITY PASS")
				get_tree().quit(0)
	hud_refresh_timer -= delta
	if hud_refresh_timer <= 0.0:
		hud_refresh_timer = 0.15
		_refresh_hud()
		if is_instance_valid(selected):
			refresh_selection_panel()

# ------------------------------------------------------------------ spawning
func spawn_unit(kind: String, team: int, pos: Vector2) -> GameUnit:
	var unit := UnitScene.instantiate() as GameUnit
	unit.setup(kind, team, _clamp_world(pos))
	world.add_child(unit)
	return unit

func spawn_building(kind: String, team: int, pos: Vector2, complete: bool = true) -> GameBuilding:
	var building := BuildingScene.instantiate() as GameBuilding
	building.setup(kind, team, _clamp_world(pos), complete)
	world.add_child(building)
	return building

func spawn_resource(kind: String, pos: Vector2) -> ResourceNode:
	var node := ResourceScene.instantiate() as ResourceNode
	node.setup(kind, pos)
	world.add_child(node)
	return node

func spawn_projectile(source: Node, target: Node, damage_value: int, team: int, color: Color, speed: float, from_pos: Vector2 = Vector2.INF) -> void:
	if not is_instance_valid(target):
		return
	var projectile := ProjectileScene.instantiate() as Projectile
	projectile.setup(source, target, damage_value, team, color, speed)
	world.add_child(projectile)
	projectile.global_position = source.global_position if from_pos == Vector2.INF else from_pos

func spawn_burst(pos: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 14
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 35.0
	p.initial_velocity_max = 115.0
	p.gravity = Vector2(0, 170)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	p.z_index = 40
	world.add_child(p)
	p.emitting = true
	var timer := get_tree().create_timer(0.85)
	timer.timeout.connect(p.queue_free)

# ------------------------------------------------------------------ economy
func add_resource(resource_type: String, amount: int, world_pos: Vector2) -> void:
	resources[resource_type] = int(resources.get(resource_type, 0)) + amount
	play_sound("deposit")
	spawn_burst(world_pos, Color(1.0, 0.85, 0.25))
	hud.show_floating_text(_world_to_screen(world_pos), "+%d %s" % [amount, RESOURCE_NAMES.get(resource_type, resource_type)], Color(1.0, 0.92, 0.35))
	_refresh_hud()

func can_afford(cost: Dictionary) -> bool:
	for key in cost.keys():
		if int(resources.get(key, 0)) < int(cost[key]):
			return false
	return true

func spend_cost(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for key in cost.keys():
		resources[key] = int(resources[key]) - int(cost[key])
	_refresh_hud()
	return true

func missing_resource_name(cost: Dictionary) -> String:
	for key in ["wood", "gold", "food"]:
		if int(cost.get(key, 0)) > int(resources.get(key, 0)):
			return RESOURCE_NAMES[key]
	return ""

func population_count() -> int:
	var count: int = 0
	for unit in get_tree().get_nodes_in_group("player_units"):
		if is_instance_valid(unit) and not bool(unit.get("dead")):
			count += 1
	return count

func projected_population() -> int:
	var count: int = population_count()
	for building in get_tree().get_nodes_in_group("player_buildings"):
		if is_instance_valid(building) and not bool(building.get("dead")):
			count += (building as GameBuilding).queue_count()
	return count

func population_cap() -> int:
	var cap: int = 10
	for building in get_tree().get_nodes_in_group("player_buildings"):
		var b := building as GameBuilding
		if is_instance_valid(b) and not b.dead and b.kind == "house" and b.construction_complete:
			cap += 5
	return mini(30, cap)

func try_train(building: GameBuilding, unit_kind: String) -> bool:
	if game_state != "playing" or building == null or building.team != 0:
		return false
	if not building.can_enqueue(unit_kind):
		if building.queue_count() >= 5:
			show_alert("Hàng huấn luyện đã đầy")
		return false
	if projected_population() >= population_cap():
		show_alert("Đã đạt giới hạn dân số")
		return false
	var cost: Dictionary = resource_cost_from_def(building.get_train_def(unit_kind))
	if not can_afford(cost):
		show_alert("Không đủ %s!" % missing_resource_name(cost))
		return false
	spend_cost(cost)
	if not building.enqueue_unit(unit_kind):
		# Refund in the unlikely event a race changed the queue.
		for key in cost.keys():
			resources[key] = int(resources[key]) + int(cost[key])
		return false
	refresh_selection_panel()
	return true

func on_training_complete(building: GameBuilding, unit_kind: String) -> void:
	var pos := _spawn_position_around(building)
	var unit := spawn_unit(unit_kind, building.team, pos)
	if building.team == 0:
		trained_count += 1
		unit.command_move(pos + Vector2(0, 42))
	_refresh_hud()

func _spawn_position_around(building: GameBuilding) -> Vector2:
	for i in range(20):
		var angle: float = TAU * float(i) / 20.0
		var pos: Vector2 = building.global_position + Vector2(cos(angle), sin(angle)) * (building.radius + 42.0)
		if pos.x > 35.0 and pos.x < 1885.0 and pos.y > 35.0 and pos.y < 1885.0:
			return pos
	return building.global_position + Vector2(building.radius + 42.0, 0)

func on_building_complete(building: GameBuilding) -> void:
	if building.team == 0:
		show_alert("%s đã xây xong" % building.display_name)
	_refresh_hud()
	if selected == building:
		refresh_selection_panel()

func on_entity_died(entity: Node) -> void:
	if selected == entity:
		selected = null
		hud.clear_selection()
	if entity is GameBuilding:
		var building := entity as GameBuilding
		if building.kind == "tc":
			if building.team == 1:
				_set_game_over(true)
			else:
				_set_game_over(false)
	_refresh_hud()

func _set_game_over(win: bool) -> void:
	if game_state != "playing":
		return
	game_state = "win" if win else "lose"
	play_sound("win" if win else "lose")
	var info: String = "Thời gian: %s\nĐơn vị đã huấn luyện: %d\nTài nguyên còn lại — Gỗ: %d • Vàng: %d • Thịt: %d" % [_format_time(elapsed), trained_count, int(resources.wood), int(resources.gold), int(resources.food)]
	hud.show_end(win, info)

# ------------------------------------------------------------------ queries
func find_town_center(team: int, _from_pos: Vector2) -> GameBuilding:
	var group_name := "player_buildings" if team == 0 else "enemy_buildings"
	var best: GameBuilding = null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group(group_name):
		var b := node as GameBuilding
		if b != null and not b.dead and b.kind == "tc":
			var d: float = _from_pos.distance_to(b.global_position)
			if d < best_dist:
				best_dist = d
				best = b
	return best

func find_resource(resource_type: String, from_pos: Vector2) -> ResourceNode:
	var best: ResourceNode = null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("resources_nodes"):
		var r := node as ResourceNode
		if r != null and not r.depleted and r.amount > 0 and r.resource_type == resource_type:
			var d: float = from_pos.distance_to(r.global_position)
			if d < best_dist:
				best_dist = d
				best = r
	return best

func find_nearest_enemy(source: Node, from_pos: Vector2, team: int, max_dist: float) -> Node:
	var groups: Array = ["enemy_units", "enemy_buildings"] if team == 0 else ["player_units", "player_buildings"]
	var best: Node = null
	var best_score: float = INF
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if node == source or not is_instance_valid(node):
				continue
			if bool(node.get("dead")):
				continue
			var score: float = from_pos.distance_to(node.global_position) - float(node.get("radius")) * 0.5
			if score <= max_dist and score < best_score:
				best_score = score
				best = node
	return best

# ------------------------------------------------------------------ enemy AI
func spawn_enemy_wave() -> int:
	if game_state != "playing" or enemy_tc == null or enemy_tc.dead:
		return 0
	wave_number += 1
	var count: int = 2 + wave_number
	var origin_building: GameBuilding = enemy_barracks if enemy_barracks != null and not enemy_barracks.dead else enemy_tc
	show_alert("Quân địch đang tấn công!")
	play_sound("horn")
	for i in range(count):
		var kind: String = "swordsman" if i % 3 != 2 else "archer"
		var offset := Vector2(float(i % 3 - 1) * 74.0, float(i / 3) * 70.0 + 95.0)
		var unit := spawn_unit(kind, 1, origin_building.global_position + offset)
		if player_tc != null and not player_tc.dead:
			unit.command_attack_move(player_tc.global_position, player_tc)
	return count

func _maintain_enemy_defenders() -> void:
	if game_state != "playing":
		return
	var defenders: int = 0
	for node in get_tree().get_nodes_in_group("enemy_units"):
		var u := node as GameUnit
		if u != null and not u.dead and u.is_defender:
			defenders += 1
	if defenders < 2 and enemy_tc != null and not enemy_tc.dead:
		var kind: String = "swordsman" if defenders == 0 else "archer"
		var unit := spawn_unit(kind, 1, enemy_tc.global_position + Vector2(-145 if defenders == 0 else 150, 205))
		unit.is_defender = true

# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_P:
			if placement_kind != "" and key_event.keycode == KEY_ESCAPE:
				_cancel_placement()
			elif game_state == "playing":
				set_paused(not paused_game)
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if game_state != "playing" or paused_game:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed and placement_kind != "":
			_cancel_placement()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_pointer("mouse", mb.position)
		else:
			_end_pointer("mouse", mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if pointer_active and pointer_source == "mouse" and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_update_pointer_drag(mm.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin_pointer("touch", st.position)
		else:
			_end_pointer("touch", st.position)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if pointer_active and pointer_source == "touch":
			_update_pointer_drag(sd.position)

func _begin_pointer(source: String, screen_pos: Vector2) -> void:
	if pointer_active:
		return
	pointer_active = true
	pointer_source = source
	press_screen_pos = screen_pos
	camera_start_center = camera.global_position
	dragging_camera = false

func _update_pointer_drag(screen_pos: Vector2) -> void:
	var delta: Vector2 = screen_pos - press_screen_pos
	if not dragging_camera and delta.length() > 12.0:
		dragging_camera = true
	if dragging_camera:
		camera.global_position = _clamp_camera(camera_start_center - delta)

func _end_pointer(source: String, screen_pos: Vector2) -> void:
	if not pointer_active or pointer_source != source:
		return
	var was_drag: bool = dragging_camera or screen_pos.distance_to(press_screen_pos) > 12.0
	pointer_active = false
	pointer_source = ""
	dragging_camera = false
	if not was_drag:
		_handle_tap(_screen_to_world(screen_pos))

func _handle_tap(world_pos: Vector2) -> void:
	if placement_kind != "":
		_try_place_building(world_pos)
		return
	var own_unit := _hit_unit(world_pos, 0)
	if own_unit != null:
		select_entity(own_unit)
		play_sound("click")
		return
	var own_building := _hit_building(world_pos, 0)
	if own_building != null:
		select_entity(own_building)
		play_sound("click")
		return
	if selected is GameUnit and not bool(selected.get("dead")):
		var unit := selected as GameUnit
		var node := _hit_resource(world_pos)
		if node != null:
			if unit.kind == "villager":
				unit.command_gather(node)
			else:
				unit.command_move(node.global_position)
			spawn_burst(world_pos, Color(1.0, 0.9, 0.25))
			return
		var enemy := _hit_enemy(world_pos, 0)
		if enemy != null:
			unit.command_attack(enemy)
			spawn_burst(world_pos, Color(1.0, 0.3, 0.2))
			return
		unit.command_move(world_pos)
		spawn_burst(world_pos, Color(1.0, 0.9, 0.25))

func _hit_unit(world_pos: Vector2, team: int) -> GameUnit:
	var best: GameUnit = null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("player_units" if team == 0 else "enemy_units"):
		var u := node as GameUnit
		if u != null and not u.dead:
			var d: float = world_pos.distance_to(u.global_position)
			if d <= u.radius + 20.0 and d < best_dist:
				best_dist = d
				best = u
	return best

func _hit_building(world_pos: Vector2, team: int) -> GameBuilding:
	var best: GameBuilding = null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("player_buildings" if team == 0 else "enemy_buildings"):
		var b := node as GameBuilding
		if b != null and not b.dead:
			var d: float = world_pos.distance_to(b.global_position)
			if d <= b.radius + 10.0 and d < best_dist:
				best_dist = d
				best = b
	return best

func _hit_resource(world_pos: Vector2) -> ResourceNode:
	var best: ResourceNode = null
	var best_dist: float = INF
	for node in get_tree().get_nodes_in_group("resources_nodes"):
		var r := node as ResourceNode
		if r != null and not r.depleted:
			var d: float = world_pos.distance_to(r.global_position)
			if d <= r.radius + 18.0 and d < best_dist:
				best_dist = d
				best = r
	return best

func _hit_enemy(world_pos: Vector2, my_team: int) -> Node:
	var unit := _hit_unit(world_pos, 1 - my_team)
	if unit != null:
		return unit
	return _hit_building(world_pos, 1 - my_team)

# ------------------------------------------------------------------ selection / building
func select_entity(entity: Node) -> void:
	if selected != null and is_instance_valid(selected):
		selected.set("selected", false)
		selected.call("queue_redraw")
	selected = entity
	if selected != null:
		selected.set("selected", true)
		selected.call("queue_redraw")
	refresh_selection_panel()

func clear_selection() -> void:
	select_entity(null)
	hud.clear_selection()

func refresh_selection_panel() -> void:
	if selected == null or not is_instance_valid(selected) or bool(selected.get("dead")):
		return
	if selected is GameUnit:
		var u := selected as GameUnit
		var info: String = "HP: %d/%d • Trạng thái: %s" % [u.hp, u.max_hp, _unit_state_text(u)]
		if u.kind == "villager" and u.carry_amount > 0:
			info += " • Đang mang: %d" % u.carry_amount
		var actions: Array = []
		if u.kind == "villager":
			for kind in ["barracks", "house", "tower"]:
				var cost: Dictionary = BUILD_COSTS[kind]
				actions.append({"id": "build_" + kind, "label": "Xây %s\n%s" % [BUILD_NAMES[kind], _cost_text(cost)], "disabled": not can_afford(cost)})
		hud.set_selection(u.display_name, info, actions)
	elif selected is GameBuilding:
		var b := selected as GameBuilding
		var info2: String = "HP: %d/%d" % [b.hp, b.max_hp]
		if not b.construction_complete:
			info2 += " • Đang xây: %d%%" % int(round(b.build_progress * 100.0))
		elif b.queue_summary() != "":
			info2 += " • " + b.queue_summary()
		if b.kind == "house" and b.construction_complete:
			info2 += " • Giới hạn dân số +5"
		var actions2: Array = []
		if b.kind == "tc":
			actions2.append(_train_action("villager", b))
		elif b.kind == "barracks":
			actions2.append(_train_action("swordsman", b))
			actions2.append(_train_action("archer", b))
		hud.set_selection(b.display_name, info2, actions2)

func _train_action(unit_kind: String, building: GameBuilding) -> Dictionary:
	var def: Dictionary = building.get_train_def(unit_kind)
	var disabled: bool = building.queue_count() >= 5 or projected_population() >= population_cap() or not can_afford(resource_cost_from_def(def))
	return {"id": "train_" + unit_kind, "label": "Huấn luyện %s\n%s" % [String(def.get("name", unit_kind)), _cost_text(def)], "disabled": disabled}

func _on_hud_action(action_id: String) -> void:
	play_sound("click")
	if action_id.begins_with("train_"):
		if selected is GameBuilding:
			try_train(selected as GameBuilding, action_id.trim_prefix("train_"))
	elif action_id.begins_with("build_"):
		_start_placement(action_id.trim_prefix("build_"))
	refresh_selection_panel()

func _start_placement(kind: String) -> void:
	if not (selected is GameUnit):
		return
	var cost: Dictionary = BUILD_COSTS[kind]
	if not can_afford(cost):
		show_alert("Không đủ %s!" % missing_resource_name(cost))
		return
	placement_kind = kind
	hud.set_selection("Đặt " + BUILD_NAMES[kind], "Chạm vào một vị trí trống trên bản đồ để đặt móng. Esc hoặc chạm chuột phải để hủy.", [])

func _cancel_placement() -> void:
	placement_kind = ""
	show_alert("Đã hủy xây dựng")
	refresh_selection_panel()

func _try_place_building(world_pos: Vector2) -> void:
	if not (selected is GameUnit):
		placement_kind = ""
		return
	var builder := selected as GameUnit
	var kind: String = placement_kind
	var cost: Dictionary = BUILD_COSTS[kind]
	var proto_radius: float = 84.0 if kind == "barracks" else (58.0 if kind == "house" else 55.0)
	if world_pos.x < proto_radius + 10.0 or world_pos.x > 1920.0 - proto_radius - 10.0 or world_pos.y < proto_radius + 10.0 or world_pos.y > 1920.0 - proto_radius - 10.0:
		show_alert("Vị trí không hợp lệ")
		return
	for child in world.get_children():
		if child is GameBuilding or child is ResourceNode:
			if world_pos.distance_to(child.global_position) < proto_radius + float(child.get("radius")) + 14.0:
				show_alert("Vị trí không hợp lệ")
				return
	if not can_afford(cost):
		show_alert("Không đủ %s!" % missing_resource_name(cost))
		placement_kind = ""
		refresh_selection_panel()
		return
	spend_cost(cost)
	var building := spawn_building(kind, 0, world_pos, false)
	placement_kind = ""
	builder.command_build(building)
	play_sound("placed")
	select_entity(building)

func _unit_state_text(unit: GameUnit) -> String:
	match unit.state:
		GameUnit.State.IDLE: return "Đang chờ"
		GameUnit.State.MOVE: return "Đang di chuyển"
		GameUnit.State.GATHER_MOVE: return "Đi thu thập"
		GameUnit.State.GATHER: return "Đang thu thập"
		GameUnit.State.RETURN: return "Mang tài nguyên về"
		GameUnit.State.BUILD_MOVE: return "Đi xây dựng"
		GameUnit.State.BUILD: return "Đang xây dựng"
		GameUnit.State.ATTACK_MOVE: return "Hành quân tấn công"
		GameUnit.State.CHASE: return "Đang truy đuổi"
		GameUnit.State.ATTACK: return "Đang chiến đấu"
		_: return "—"

# ------------------------------------------------------------------ pause / alerts / helpers
func set_paused(value: bool) -> void:
	if game_state != "playing":
		return
	paused_game = value
	get_tree().paused = value
	hud.set_paused(value)

func restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func show_alert(text: String) -> void:
	hud.show_alert(text)

func play_sound(sound_name: String) -> void:
	if not sounds.has(sound_name):
		return
	for player in audio_players:
		if not player.playing:
			player.stream = sounds[sound_name]
			player.play()
			return

func _init_audio() -> void:
	for key in SOUND_PATHS.keys():
		sounds[key] = load(SOUND_PATHS[key])
	for i in range(14):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		audio_players.append(player)
	var ambient_stream := load("res://sounds/ambient.wav") as AudioStreamWAV
	if ambient_stream != null:
		ambient_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambient_stream.loop_begin = 0
		ambient_stream.loop_end = int(ambient_stream.get_length() * ambient_stream.mix_rate)
		var ambient := AudioStreamPlayer.new()
		ambient.stream = ambient_stream
		ambient.volume_db = -25.0
		add_child(ambient)
		ambient.play()

func _refresh_hud() -> void:
	hud.refresh_resources(int(resources.wood), int(resources.gold), int(resources.food), population_count(), population_cap(), elapsed)

func _format_time(seconds: float) -> String:
	var secs: int = int(seconds)
	return "%02d:%02d" % [secs / 60, secs % 60]

func resource_cost_from_def(def: Dictionary) -> Dictionary:
	return {"wood": int(def.get("wood", 0)), "gold": int(def.get("gold", 0)), "food": int(def.get("food", 0))}

func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	if int(cost.get("wood", 0)) > 0: parts.append("%d gỗ" % int(cost.wood))
	if int(cost.get("gold", 0)) > 0: parts.append("%d vàng" % int(cost.gold))
	if int(cost.get("food", 0)) > 0: parts.append("%d thịt" % int(cost.food))
	return "Miễn phí" if parts.is_empty() else ", ".join(parts)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

func _world_to_screen(world_pos: Vector2) -> Vector2:
	return (world_pos - camera.global_position) + VIEW_SIZE * 0.5

func _clamp_camera(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, VIEW_SIZE.x * 0.5, MAP_SIZE.x - VIEW_SIZE.x * 0.5), clampf(pos.y, VIEW_SIZE.y * 0.5, MAP_SIZE.y - VIEW_SIZE.y * 0.5))

func _clamp_world(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, 25.0, MAP_SIZE.x - 25.0), clampf(pos.y, 25.0, MAP_SIZE.y - 25.0))

# ------------------------------------------------------------------ QA hooks
func qa_assert(condition: bool, label: String) -> void:
	if condition:
		print("QA: ", label, " OK")
	else:
		qa_failed = true
		if qa_fail_reason == "":
			qa_fail_reason = label
		print("QA: FAIL - ", label)

func run_qa_tests() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("QA: game started, villagers=", get_tree().get_nodes_in_group("player_units").size(), ", wood=", resources.wood, ", gold=", resources.gold, ", food=", resources.food)
	qa_assert(player_tc != null and enemy_tc != null, "both town centers exist")
	qa_assert(population_count() == 3, "player starts with 3 villagers")
	qa_assert(int(resources.wood) == 200 and int(resources.gold) == 100 and int(resources.food) == 150, "starting resources are exact")

	# Economy loop: send villager 1 to nearest tree with test speed/gather hooks.
	var villager: GameUnit = null
	for node in get_tree().get_nodes_in_group("player_units"):
		var u := node as GameUnit
		if u != null and u.kind == "villager":
			villager = u
			break
	var tree := find_resource("wood", villager.global_position)
	qa_assert(tree != null, "a tree is available")
	var wood_before: int = int(resources.wood)
	villager.gather_duration = 0.05
	villager.speed_scale = 9.0
	villager.command_gather(tree)
	var wait_steps: int = 0
	while int(resources.wood) <= wood_before and wait_steps < 50:
		await get_tree().create_timer(0.1).timeout
		wait_steps += 1
	qa_assert(int(resources.wood) > wood_before, "villager completed a gather/deposit cycle and wood increased")

	# Training queue at the Town Center.
	var food_before: int = int(resources.food)
	var pop_before: int = population_count()
	var train_ok: bool = try_train(player_tc, "villager")
	qa_assert(train_ok and int(resources.food) == food_before - 50, "training a villager deducts 50 food")
	player_tc.qa_finish_training()
	await get_tree().create_timer(0.3).timeout
	qa_assert(population_count() == pop_before + 1, "trained villager spawned from queue")

	# Combat: put a fresh swordsman beside an enemy archer guard.
	var dummy: GameUnit = null
	for node in get_tree().get_nodes_in_group("enemy_units"):
		var eu := node as GameUnit
		if eu != null and eu.kind == "archer" and not eu.dead:
			dummy = eu
			break
	qa_assert(dummy != null, "enemy combat dummy exists")
	var dummy_hp: int = dummy.hp
	var sword := spawn_unit("swordsman", 0, dummy.global_position + Vector2(-46, 0))
	sword.attack_cooldown = 0.0
	sword.command_attack(dummy)
	wait_steps = 0
	while dummy.hp >= dummy_hp and wait_steps < 40 and not dummy.dead:
		await get_tree().create_timer(0.1).timeout
		wait_steps += 1
	qa_assert(dummy.dead or dummy.hp < dummy_hp, "player swordsman damages enemy in combat")

	# Enemy wave timer hook.
	var enemy_before: int = 0
	for node in get_tree().get_nodes_in_group("enemy_units"):
		if is_instance_valid(node) and not bool(node.get("dead")):
			enemy_before += 1
	wave_timer = 0.02
	await get_tree().create_timer(0.35).timeout
	var enemy_after: int = 0
	for node in get_tree().get_nodes_in_group("enemy_units"):
		if is_instance_valid(node) and not bool(node.get("dead")):
			enemy_after += 1
	qa_assert(enemy_after > enemy_before and wave_number >= 1, "enemy wave spawns when its timer fires")

	# Win through the normal damage API.
	enemy_tc.take_damage(999999, sword)
	await get_tree().process_frame
	qa_assert(game_state == "win", "destroying enemy Town Center wins the game")

	if qa_failed:
		print("QA FAIL ", qa_fail_reason)
		get_tree().quit(1)
	else:
		print("QA PASS")
		get_tree().quit(0)

func setup_sanity_mode() -> void:
	await get_tree().process_frame
	var villagers: Array = []
	for node in get_tree().get_nodes_in_group("player_units"):
		var u := node as GameUnit
		if u != null and u.kind == "villager":
			villagers.append(u)
	if villagers.size() >= 3:
		villagers[0].command_gather(find_resource("wood", villagers[0].global_position))
		villagers[1].command_gather(find_resource("gold", villagers[1].global_position))
		villagers[2].command_gather(find_resource("food", villagers[2].global_position))
	print("SANITY: started unattended economy simulation")

# ------------------------------------------------------------------ shot mode
func run_shot_mode() -> void:
	await get_tree().create_timer(1.0).timeout
	camera.global_position = Vector2(360, 1280)
	await save_screenshot("base.png")

	var villagers: Array[GameUnit] = []
	for node in get_tree().get_nodes_in_group("player_units"):
		var u := node as GameUnit
		if u != null and u.kind == "villager":
			villagers.append(u)
	if villagers.size() >= 3:
		villagers[0].command_gather(find_resource("gold", villagers[0].global_position))
		villagers[1].command_gather(find_resource("food", villagers[1].global_position))
		villagers[2].command_gather(find_resource("wood", villagers[2].global_position))
	# Let the economy genuinely run unattended before staging the construction shot.
	await get_tree().create_timer(22.0).timeout
	var foundation := spawn_building("barracks", 0, Vector2(610, 1390), false)
	if villagers.size() >= 3:
		villagers[2].command_build(foundation)
	await get_tree().create_timer(8.0).timeout
	camera.global_position = _clamp_camera(Vector2(650, 1450))
	await save_screenshot("economy.png")

	# Stage a clash just south of the enemy towers.
	var player_force: Array[GameUnit] = []
	var enemy_force: Array[GameUnit] = []
	for data in [["swordsman", Vector2(1245, 700)], ["swordsman", Vector2(1310, 755)], ["swordsman", Vector2(1375, 700)], ["archer", Vector2(1280, 805)], ["archer", Vector2(1405, 800)]]:
		player_force.append(spawn_unit(String(data[0]), 0, data[1]))
	for data in [["swordsman", Vector2(1510, 635)], ["swordsman", Vector2(1580, 690)], ["swordsman", Vector2(1650, 635)], ["archer", Vector2(1545, 745)], ["archer", Vector2(1665, 730)]]:
		enemy_force.append(spawn_unit(String(data[0]), 1, data[1]))
	for unit in player_force:
		unit.command_attack_move(Vector2(1570, 690))
	for unit in enemy_force:
		unit.command_attack_move(Vector2(1330, 710))
	if player_force.size() > 0 and enemy_force.size() > 0:
		player_force[0].take_damage(16, enemy_force[0])
		enemy_force[0].take_damage(18, player_force[0])
	camera.global_position = _clamp_camera(Vector2(1450, 930))
	await get_tree().create_timer(2.5).timeout
	await save_screenshot("battle.png")
	print("SHOT: done elapsed=%.1f fps=%d entities=%d resources=%s" % [elapsed, Engine.get_frames_per_second(), world.get_child_count(), str(resources)])
	get_tree().quit(0)

func save_screenshot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://shots/" + filename)
	var err := image.save_png(path)
	print("SHOT: saved ", filename, " size=", image.get_size(), " error=", err)
