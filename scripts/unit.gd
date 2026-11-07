class_name GameUnit
extends Node2D

enum State { IDLE, MOVE, GATHER_MOVE, GATHER, RETURN, BUILD_MOVE, BUILD, ATTACK_MOVE, CHASE, ATTACK, DEAD }

const TEXTURES := {
	"villager_0": preload("res://assets/villager_blue.png"),
	"swordsman_0": preload("res://assets/swordsman_blue.png"),
	"archer_0": preload("res://assets/archer_blue.png"),
	"villager_1": preload("res://assets/villager_red.png"),
	"swordsman_1": preload("res://assets/swordsman_red.png"),
	"archer_1": preload("res://assets/archer_red.png")
}

var kind: String = "villager"
var team: int = 0
var display_name: String = "Dân"
var max_hp: int = 50
var hp: int = 50
var damage: int = 3
var speed: float = 140.0
var attack_range: float = 34.0
var sight_range: float = 220.0
var radius: float = 20.0
var state: int = State.IDLE
var dead: bool = false
var selected: bool = false
var is_defender: bool = false

var target_position: Vector2 = Vector2.ZERO
var move_destination: Vector2 = Vector2.ZERO
var resource_node: ResourceNode = null
var resource_type: String = ""
var carry_amount: int = 0
var gather_timer: float = 0.0
var gather_duration: float = 2.5
var build_target: GameBuilding = null
var attack_target: Node = null
var attack_cooldown: float = 0.0
var acquire_timer: float = 0.0
var speed_scale: float = 1.0
var facing: float = 1.0

@onready var sprite: Sprite2D = $Sprite

func setup(p_kind: String, p_team: int, p_pos: Vector2) -> void:
	kind = p_kind
	team = p_team
	global_position = p_pos
	target_position = p_pos
	move_destination = p_pos
	match kind:
		"villager":
			display_name = "Dân"; max_hp = 50; damage = 3; speed = 145.0; attack_range = 32.0
		"swordsman":
			display_name = "Lính Kiếm"; max_hp = 65; damage = 9; speed = 165.0; attack_range = 38.0
		"archer":
			display_name = "Cung Thủ"; max_hp = 40; damage = 7; speed = 155.0; attack_range = 170.0
	hp = max_hp

func _ready() -> void:
	add_to_group("player_units" if team == 0 else "enemy_units")
	sprite.texture = TEXTURES[kind + "_" + str(team)]
	z_index = 10

func _process(delta: float) -> void:
	if dead:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	acquire_timer -= delta
	match state:
		State.IDLE:
			if kind != "villager":
				_auto_acquire()
			elif acquire_timer <= 0.0:
				acquire_timer = 0.35
		State.MOVE:
			if _move_towards(target_position, delta, 6.0):
				state = State.IDLE
		State.ATTACK_MOVE:
			if _attack_move_logic(delta):
				pass
		State.GATHER_MOVE:
			if not _valid_resource():
				_find_replacement_resource()
			elif _move_towards(resource_node.global_position, delta, resource_node.radius + 20.0):
				state = State.GATHER
				gather_timer = gather_duration
		State.GATHER:
			gather_timer -= delta
			if gather_timer <= 0.0:
				_finish_gathering()
		State.RETURN:
			var tc := _nearest_town_center()
			if tc == null:
				state = State.IDLE
			elif _move_towards(tc.global_position, delta, tc.radius + 22.0):
				_deposit()
		State.BUILD_MOVE:
			if not is_instance_valid(build_target) or build_target.dead:
				state = State.IDLE
			elif _move_towards(build_target.global_position, delta, build_target.radius + 26.0):
				state = State.BUILD
		State.BUILD:
			if not is_instance_valid(build_target) or build_target.dead:
				state = State.IDLE
			elif build_target.construction_complete:
				state = State.IDLE
			else:
				build_target.advance_construction(delta)
		State.CHASE:
			_chase_logic(delta)
		State.ATTACK:
			_attack_logic(delta)
	_apply_separation(delta)
	queue_redraw()

func command_move(pos: Vector2) -> void:
	if dead:
		return
	_clear_work()
	target_position = _clamp_world(pos)
	state = State.MOVE

func command_attack_move(pos: Vector2, focus: Node = null) -> void:
	if dead:
		return
	_clear_work()
	move_destination = _clamp_world(pos)
	target_position = move_destination
	attack_target = focus
	state = State.ATTACK_MOVE

func command_attack(target: Node) -> void:
	if dead or not is_instance_valid(target):
		return
	_clear_work()
	attack_target = target
	state = State.CHASE

func command_gather(node: ResourceNode) -> void:
	if dead or kind != "villager" or node == null:
		return
	_clear_work()
	resource_node = node
	resource_type = node.resource_type
	carry_amount = 0
	state = State.GATHER_MOVE

func command_build(building: GameBuilding) -> void:
	if dead or kind != "villager" or building == null:
		return
	_clear_work()
	build_target = building
	state = State.BUILD_MOVE

func take_damage(amount: int, attacker: Node = null) -> void:
	if dead:
		return
	hp -= amount
	queue_redraw()
	if hp <= 0:
		_die(attacker)
		return
	# Units fight back when attacked, except a builder who is actively raising a building.
	if is_instance_valid(attacker) and attacker != self and state != State.BUILD and state != State.BUILD_MOVE:
		if kind != "villager" or state == State.IDLE or state == State.MOVE:
			attack_target = attacker
			state = State.CHASE

func _die(_attacker: Node) -> void:
	dead = true
	state = State.DEAD
	hp = 0
	var main = _main()
	if main != null:
		main.on_entity_died(self)
		main.spawn_burst(global_position, Color(0.35, 0.65, 1.0) if team == 0 else Color(1.0, 0.35, 0.25))
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.parallel().tween_property(self, "position:y", position.y + 10.0, 0.45)
	tw.tween_callback(queue_free)

func _clear_work() -> void:
	resource_node = null
	build_target = null
	attack_target = null
	carry_amount = 0

func _valid_resource() -> bool:
	return is_instance_valid(resource_node) and not resource_node.depleted and resource_node.amount > 0

func _finish_gathering() -> void:
	if not _valid_resource():
		_find_replacement_resource()
		return
	var main = _main()
	if main != null:
		main.play_sound("chop")
	carry_amount = resource_node.take_amount(10)
	if carry_amount > 0:
		state = State.RETURN
	else:
		_find_replacement_resource()

func _deposit() -> void:
	if carry_amount <= 0:
		state = State.IDLE
		return
	var main = _main()
	if main != null:
		main.add_resource(resource_type, carry_amount, global_position)
	carry_amount = 0
	if _valid_resource():
		state = State.GATHER_MOVE
	else:
		_find_replacement_resource()

func _find_replacement_resource() -> void:
	var main = _main()
	if main != null and resource_type != "":
		var replacement = main.find_resource(resource_type, global_position)
		if replacement != null:
			resource_node = replacement
			state = State.GATHER_MOVE
			return
	resource_node = null
	state = State.IDLE

func _nearest_town_center() -> GameBuilding:
	var main = _main()
	if main == null:
		return null
	return main.find_town_center(team, global_position)

func _attack_move_logic(delta: float) -> bool:
	if is_instance_valid(attack_target) and not bool(attack_target.get("dead")):
		state = State.CHASE
		_chase_logic(delta)
		return true
	attack_target = null
	if acquire_timer <= 0.0:
		acquire_timer = 0.22
		var found := _nearest_enemy_in_range(sight_range)
		if found != null:
			attack_target = found
			state = State.CHASE
			return true
	if _move_towards(move_destination, delta, 8.0):
		state = State.IDLE
	return true

func _auto_acquire() -> void:
	if acquire_timer > 0.0:
		return
	acquire_timer = 0.25
	var found := _nearest_enemy_in_range(sight_range)
	if found != null:
		attack_target = found
		state = State.CHASE

func _chase_logic(delta: float) -> void:
	if not is_instance_valid(attack_target) or bool(attack_target.get("dead")):
		attack_target = null
		state = State.ATTACK_MOVE if _has_attack_destination() else State.IDLE
		return
	var target_pos: Vector2 = attack_target.global_position
	var target_radius: float = float(attack_target.get("radius"))
	var desired: float = attack_range + target_radius * 0.55
	if global_position.distance_to(target_pos) <= desired:
		state = State.ATTACK
		_attack_logic(delta)
	else:
		_move_towards(target_pos, delta, desired - 4.0)

func _attack_logic(delta: float) -> void:
	if not is_instance_valid(attack_target) or bool(attack_target.get("dead")):
		attack_target = null
		state = State.IDLE
		return
	var target_pos: Vector2 = attack_target.global_position
	var target_radius: float = float(attack_target.get("radius"))
	var desired: float = attack_range + target_radius * 0.55
	if global_position.distance_to(target_pos) > desired + 8.0:
		state = State.CHASE
		return
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.85 if kind == "archer" else 0.75
	var main = _main()
	if kind == "archer":
		if main != null:
			main.spawn_projectile(self, attack_target, damage, team, Color(1.0, 0.9, 0.35), 560.0)
			main.play_sound("arrow")
	else:
		attack_target.call("take_damage", damage, self)
		if main != null:
			main.play_sound("sword")

func _has_attack_destination() -> bool:
	return move_destination.distance_to(global_position) > 14.0

func _nearest_enemy_in_range(max_dist: float) -> Node:
	var main = _main()
	if main == null:
		return null
	return main.find_nearest_enemy(self, global_position, team, max_dist)

func _move_towards(destination: Vector2, delta: float, stop_distance: float) -> bool:
	var to_dest: Vector2 = destination - global_position
	var dist: float = to_dest.length()
	if dist <= stop_distance:
		return true
	var step: float = minf(dist - stop_distance * 0.35, speed * speed_scale * delta)
	if step <= 0.0:
		return false
	var direction: Vector2 = to_dest.normalized()
	global_position += direction * step
	if absf(direction.x) > 0.05:
		facing = signf(direction.x)
		sprite.scale.x = absf(sprite.scale.x) * facing
	global_position = _clamp_world(global_position)
	return global_position.distance_to(destination) <= stop_distance + 2.0

func _apply_separation(delta: float) -> void:
	if state == State.DEAD:
		return
	var push: Vector2 = Vector2.ZERO
	var parent := get_parent()
	if parent != null:
		for child in parent.get_children():
			if child == self or not is_instance_valid(child):
				continue
			if not (child is GameUnit or child is GameBuilding or child is ResourceNode):
				continue
			if child is GameUnit or child is GameBuilding:
				if bool(child.get("dead")):
					continue
			var other_radius: float = float(child.get("radius"))
			var d: Vector2 = global_position - child.global_position
			var dist: float = d.length()
			var min_dist: float = radius + other_radius + 3.0
			# Buildings and resource nodes are firm obstacles; units gently separate.
			if child is GameUnit:
				min_dist = radius + other_radius + 1.0
			if dist > 0.01 and dist < min_dist:
				push += d.normalized() * (min_dist - dist) * (3.2 if child is GameUnit else 5.0)
			elif dist <= 0.01 and child is GameUnit:
				push += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 12.0
	if push.length() > 0.01:
		global_position = _clamp_world(global_position + push * delta)
		# Hard-push out of buildings/resources if steering got us inside.
		if parent != null:
			for child in parent.get_children():
				if child == self or not (child is GameBuilding or child is ResourceNode):
					continue
				var other_radius: float = float(child.get("radius"))
				var d2: Vector2 = global_position - child.global_position
				var min2: float = radius + other_radius + 1.0
				if d2.length() > 0.01 and d2.length() < min2:
					global_position = child.global_position + d2.normalized() * min2

func _clamp_world(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, 28.0, 1892.0), clampf(pos.y, 28.0, 1892.0))

func _main():
	return get_tree().get_first_node_in_group("game")

func _draw() -> void:
	# soft shadow
	draw_ellipse_shadow()
	if selected:
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.15), 3.0)
	if hp < max_hp and not dead:
		var w: float = 54.0
		var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
		draw_rect(Rect2(Vector2(-w * 0.5, -48), Vector2(w, 7)), Color(0, 0, 0, 0.65))
		draw_rect(Rect2(Vector2(-w * 0.5, -48), Vector2(w * ratio, 7)), Color(0.3, 0.95, 0.35) if team == 0 else Color(1.0, 0.3, 0.25))

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 18), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, radius * 0.9, Color(0, 0, 0, 0.18))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
