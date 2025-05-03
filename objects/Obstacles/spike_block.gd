extends CharacterBody3D

@export var point_a: Vector3
@export var point_b: Vector3
@export var move_speed := 1.5
@export var wait_time := 0.3

var wait_timer := 0.0
var going_to_b := true
@onready var damage_area: Area3D = $Area3D


func _ready():
	damage_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(1, global_transform.origin)

func _physics_process(delta):
	if wait_timer > 0.0:
		wait_timer -= delta
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var target = point_a
	if going_to_b:
		target = point_b
	var direction = target - global_position

	if direction.length() < 0.05:
		going_to_b = !going_to_b
		wait_timer = wait_time
		velocity = Vector3.ZERO
		move_and_slide()
		return

	velocity = direction.normalized() * move_speed
	move_and_slide()
