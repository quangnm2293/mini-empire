class_name ResourceNode
extends Node2D

var kind: String = "tree"
var resource_type: String = "wood"
var amount: int = 120
var max_amount: int = 120
var radius: float = 40.0
var depleted: bool = false
var display_name: String = "Cây"

const TEXTURES := {
	"tree": preload("res://assets/tree.png"),
	"gold": preload("res://assets/gold_mine.png"),
	"berry": preload("res://assets/berry_bush.png")
}

func setup(p_kind: String, p_pos: Vector2) -> void:
	kind = p_kind
	global_position = p_pos
	match kind:
		"tree":
			resource_type = "wood"; amount = 120; radius = 38.0; display_name = "Cây gỗ"
		"gold":
			resource_type = "gold"; amount = 300; radius = 54.0; display_name = "Mỏ vàng"
		"berry":
			resource_type = "food"; amount = 150; radius = 47.0; display_name = "Bụi quả"
	max_amount = amount

func _ready() -> void:
	add_to_group("resources_nodes")
	var sprite := get_node_or_null("Sprite") as Sprite2D
	if sprite:
		sprite.texture = TEXTURES[kind]
	_update_visual()

func take_amount(requested: int) -> int:
	if depleted:
		return 0
	var taken: int = mini(requested, amount)
	amount -= taken
	if amount <= 0:
		depleted = true
		_update_visual()
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.45)
		tw.tween_callback(queue_free)
	else:
		_update_visual()
	return taken

func _update_visual() -> void:
	var ratio: float = 1.0 if max_amount <= 0 else clampf(float(amount) / float(max_amount), 0.25, 1.0)
	scale = Vector2.ONE * (0.55 + 0.45 * ratio)
	if depleted:
		modulate = Color(1, 1, 1, 0.25)

func is_resource_node() -> bool:
	return true
