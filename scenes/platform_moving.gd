@tool
extends CharacterBody3D

@export var move_speed: float = 1.5
@export var distance_offset: float = 0.0
@export var force_up_alignment: bool = true  # Align to world up, keep path forward
@export var lock_to_position_only: bool = false  # If true, ignores all path rotation

@onready var path: Path3D = $"../Path3D"

var distance: float = 0.0

func _ready():
	var path_length = path.curve.get_baked_length()
	distance = fposmod(distance_offset, path_length)

func _physics_process(delta):
	if path == null:
		return

	var path_length = path.curve.get_baked_length()
	distance += move_speed * delta
	distance = fposmod(distance, path_length)

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
