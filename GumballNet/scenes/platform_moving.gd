extends CharacterBody3D

@export var move_speed: float = 1.5
@export var distance_offset: float = 1
@export var force_up_alignment: bool = true
@export var lock_to_position_only: bool = false
@export var pause_time: float = 0.5  # Pause at ends if path is open

@onready var path: Path3D = $"../Path3D"

var distance: float = 0.0
var going_forward: bool = true
var wait_timer: float = 0.0

func _ready():
	var path_length = path.curve.get_baked_length()
	distance = distance_offset * path_length

func _physics_process(delta):
	if path == null:
		return

	var path_length = path.curve.get_baked_length()

	if wait_timer > 0.0:
		wait_timer -= delta
		return

	if path.curve.closed:
		distance += move_speed * delta
		distance = fposmod(distance, path_length)
	else:
		var direction = 1.0 if going_forward else -1.0
		distance += move_speed * delta * direction

		if distance >= path_length:
			distance = path_length
			going_forward = false
			wait_timer = pause_time
		elif distance <= 0.0:
			distance = 0.0
			going_forward = true
			wait_timer = pause_time

	var local_transform = path.curve.sample_baked_with_rotation(distance)
	var global_transform_result = path.global_transform * local_transform

	if lock_to_position_only:
		global_position = global_transform_result.origin
		return

	if force_up_alignment:
		var position = global_transform_result.origin
		var forward = global_transform_result.basis.x.normalized()
		var up = Vector3.UP
		var right = up.cross(forward).normalized()
		var adjusted_basis = Basis(right, up, forward).orthonormalized()
		global_transform_result.basis = adjusted_basis
		global_transform_result.origin = position

	global_transform = global_transform_result
