extends CharacterBody3D

@export var move_speed := 1.5
@export var wait_time := 0.3
#@export_node_path("Path3D") var path_node_path
@onready var path: Path3D = $"../Path3D"

@onready var damage_area: Area3D = $Area3D
#@onready var path: Path3D = get_node(path_node_path)

var distance := 0.0
var going_forward := true
var wait_timer := 0.0

func _ready():
	damage_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(1, global_transform.origin)

func _physics_process(delta):
	if wait_timer > 0.0:
		wait_timer -= delta
		return

	var direction = 1.0 if going_forward else -1.0
	distance += move_speed * delta * direction
	var path_length = path.curve.get_baked_length()

	if distance >= path_length:
		distance = path_length
		going_forward = false
		wait_timer = wait_time
	elif distance <= 0.0:
		distance = 0.0
		going_forward = true
		wait_timer = wait_time

	var local_pos = path.curve.sample_baked(distance)
	global_position = path.global_transform * local_pos
