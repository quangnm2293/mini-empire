class_name GameBuilding
extends Node2D

const TEXTURES := {
	"tc_0": preload("res://assets/tc_blue.png"),
	"barracks_0": preload("res://assets/barracks_blue.png"),
	"house_0": preload("res://assets/house_blue.png"),
	"tower_0": preload("res://assets/tower_blue.png"),
	"tc_1": preload("res://assets/tc_red.png"),
	"barracks_1": preload("res://assets/barracks_red.png"),
	"house_1": preload("res://assets/house_red.png"),
	"tower_1": preload("res://assets/tower_red.png")
}
const TRAIN_DEFS := {
	"villager": {"food": 50, "wood": 0, "gold": 0, "time": 5.0, "name": "Dân"},
	"swordsman": {"food": 60, "wood": 0, "gold": 20, "time": 8.0, "name": "Lính Kiếm"},
	"archer": {"food": 50, "wood": 40, "gold": 0, "time": 10.0, "name": "Cung Thủ"}
}

var kind: String = "house"
var team: int = 0
var display_name: String = "Nhà"
var max_hp: int = 300
var hp: int = 300
var radius: float = 58.0
var dead: bool = false
var selected: bool = false
var construction_complete: bool = true
var build_progress: float = 1.0
var build_time: float = 10.0
var train_queue: Array = []
var attack_cooldown: float = 0.0
var pop_bonus_given: bool = false

@onready var sprite: Sprite2D = $Sprite

func setup(p_kind: String, p_team: int, p_pos: Vector2, p_complete: bool = true) -> void:
	kind = p_kind
	team = p_team
	global_position = p_pos
	match kind:
		"tc":
			display_name = "Nhà Chính"; max_hp = 1200; radius = 104.0; build_time = 30.0
		"barracks":
			display_name = "Doanh Trại"; max_hp = 700; radius = 84.0; build_time = 20.0
		"house":
			display_name = "Nhà"; max_hp = 300; radius = 58.0; build_time = 10.0
		"tower":
			display_name = "Tháp Canh"; max_hp = 550; radius = 55.0; build_time = 15.0
	hp = max_hp
	construction_complete = p_complete
	build_progress = 1.0 if p_complete else 0.0
	if not p_complete:
		hp = maxi(1, int(max_hp * 0.1))
		pop_bonus_given = false
	else:
		pop_bonus_given = kind == "house"

func _ready() -> void:
	add_to_group("player_buildings" if team == 0 else "enemy_buildings")
	sprite.texture = TEXTURES[kind + "_" + str(team)]
	z_index = 5
	_update_construction_visual()

func _process(delta: float) -> void:
	if dead:
		return
	_process_training(delta)
	if kind == "tower" and construction_complete:
		_process_tower(delta)
	queue_redraw()

func _process_training(delta: float) -> void:
	if train_queue.is_empty() or not construction_complete:
		return
	var item: Dictionary = train_queue[0]
	item["time_left"] = float(item["time_left"]) - delta
	train_queue[0] = item
	if float(item["time_left"]) > 0.0:
		return
	var unit_kind: String = String(item["kind"])
	train_queue.pop_front()
	var main = _main()
	if main != null:
		main.on_training_complete(self, unit_kind)
		main.play_sound("train_ready")

func can_enqueue(unit_kind: String) -> bool:
	if dead or not construction_complete or train_queue.size() >= 5:
		return false
	if kind == "tc":
		return unit_kind == "villager"
	if kind == "barracks":
		return unit_kind == "swordsman" or unit_kind == "archer"
	return false

func enqueue_unit(unit_kind: String) -> bool:
	if not can_enqueue(unit_kind):
		return false
	var def: Dictionary = TRAIN_DEFS[unit_kind]
	train_queue.append({"kind": unit_kind, "time_left": float(def["time"]), "duration": float(def["time"])})
	return true

func queue_count() -> int:
	return train_queue.size()

func queue_summary() -> String:
	if train_queue.is_empty():
		return ""
	var item: Dictionary = train_queue[0]
	var def: Dictionary = TRAIN_DEFS[String(item["kind"])]
	var pct: int = int(round(100.0 * (1.0 - float(item["time_left"]) / float(item["duration"]))))
	return "Đang huấn luyện %s: %d%% • Hàng chờ: %d/5" % [String(def["name"]), pct, train_queue.size()]

func qa_finish_training() -> void:
	if not train_queue.is_empty():
		var item: Dictionary = train_queue[0]
		item["time_left"] = 0.001
		train_queue[0] = item

func advance_construction(delta: float) -> void:
	if construction_complete or dead:
		return
	build_progress = clampf(build_progress + delta / build_time, 0.0, 1.0)
	var target_hp: int = maxi(1, int(max_hp * (0.1 + 0.9 * build_progress)))
	if hp < target_hp:
		hp = target_hp
	if build_progress >= 1.0:
		construction_complete = true
		hp = max_hp if hp > int(max_hp * 0.9) else hp
		if kind == "house":
			pop_bonus_given = true
		var main = _main()
		if main != null:
			main.on_building_complete(self)
			main.play_sound("placed")
	_update_construction_visual()

func set_build_progress(value: float) -> void:
	build_progress = clampf(value, 0.0, 1.0)
	construction_complete = build_progress >= 1.0
	_update_construction_visual()

func _update_construction_visual() -> void:
	if not construction_complete:
		modulate = Color(1, 1, 1, 0.45 + 0.45 * build_progress)
	else:
		modulate = Color.WHITE

func _process_tower(delta: float) -> void:
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if attack_cooldown > 0.0:
		return
	var main = _main()
	if main == null:
		return
	var target = main.find_nearest_enemy(self, global_position + Vector2(0, -62), team, 200.0)
	if target != null:
		attack_cooldown = 0.9
		main.spawn_projectile(self, target, 8, team, Color(0.45, 0.95, 1.0), 500.0, global_position + Vector2(0, -62))
		main.play_sound("tower")

func take_damage(amount: int, attacker: Node = null) -> void:
	if dead:
		return
	hp -= amount
	queue_redraw()
	if hp <= 0:
		_die(attacker)

func _die(_attacker: Node) -> void:
	dead = true
	hp = 0
	train_queue.clear()
	var main = _main()
	if main != null:
		main.spawn_burst(global_position, Color(1.0, 0.55, 0.15))
		main.on_entity_died(self)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(self, "scale", scale * 0.92, 0.6)
	tw.tween_callback(queue_free)

func get_train_def(unit_kind: String) -> Dictionary:
	return TRAIN_DEFS.get(unit_kind, {})

func _main():
	return get_tree().get_first_node_in_group("game")

func _draw() -> void:
	draw_set_transform(Vector2(0, radius * 0.78), 0, Vector2(1, 0.32))
	draw_circle(Vector2.ZERO, radius * 0.95, Color(0, 0, 0, 0.16))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if selected:
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 56, Color(1.0, 0.9, 0.15), 3.0)
	if not construction_complete:
		var w: float = radius * 1.5
		draw_rect(Rect2(Vector2(-w * 0.5, -radius - 28), Vector2(w, 10)), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(Vector2(-w * 0.5, -radius - 28), Vector2(w * build_progress, 10)), Color(1.0, 0.75, 0.2))
		draw_string(ThemeDB.fallback_font, Vector2(-42, -radius - 36), "Đang xây", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	elif hp < max_hp and not dead:
		var w2: float = radius * 1.55
		var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
		draw_rect(Rect2(Vector2(-w2 * 0.5, -radius - 24), Vector2(w2, 9)), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(Vector2(-w2 * 0.5, -radius - 24), Vector2(w2 * ratio, 9)), Color(0.3, 0.95, 0.35) if team == 0 else Color(1.0, 0.3, 0.25))
