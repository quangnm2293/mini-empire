class_name Projectile
extends Node2D

var source: Node = null
var target: Node = null
var target_pos: Vector2 = Vector2.ZERO
var damage: int = 7
var team: int = 0
var speed: float = 540.0
var life: float = 2.0
var projectile_color: Color = Color(1.0, 0.85, 0.25)

func setup(p_source: Node, p_target: Node, p_damage: int, p_team: int, p_color: Color, p_speed: float = 540.0) -> void:
	source = p_source
	target = p_target
	damage = p_damage
	team = p_team
	projectile_color = p_color
	speed = p_speed
	if is_instance_valid(target):
		target_pos = target.global_position

func _ready() -> void:
	z_index = 30

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if is_instance_valid(target) and not bool(target.get("dead")):
		target_pos = target.global_position
	var to_target: Vector2 = target_pos - global_position
	var dist: float = to_target.length()
	if dist <= maxf(12.0, speed * delta):
		_hit()
		return
	global_position += to_target.normalized() * speed * delta
	rotation = to_target.angle()
	queue_redraw()

func _hit() -> void:
	if is_instance_valid(target) and not bool(target.get("dead")):
		if target.has_method("take_damage"):
			target.call("take_damage", damage, source)
	queue_free()

func _draw() -> void:
	draw_line(Vector2(-10, 0), Vector2(9, 0), projectile_color, 4.0)
	draw_circle(Vector2(9, 0), 3.5, Color.WHITE)
