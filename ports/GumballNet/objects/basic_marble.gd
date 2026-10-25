extends RigidBody3D

@export var kill_y_threshold: float = -10.0
var spawner  # Assigned externally
var network_id := 0
var is_network_proxy := false
var network_target_position := Vector3.ZERO
var network_target_rotation := Quaternion.IDENTITY
var network_velocity := Vector3.ZERO
var network_state_received := false

func _ready():
	add_to_group("network_marbles")

func _physics_process(delta):
	if is_network_proxy:
		if network_state_received:
			network_target_position += network_velocity * delta
			var position_weight := 1.0 - exp(-14.0 * delta)
			global_position = global_position.lerp(network_target_position, position_weight)
			quaternion = quaternion.slerp(network_target_rotation, 1.0 - exp(-12.0 * delta))
		return
	if global_transform.origin.y < kill_y_threshold:
		queue_free()

		if spawner and spawner.has_method("_on_marble_deleted"):
			spawner._on_marble_deleted()

func setup_network_proxy() -> void:
	is_network_proxy = true
	freeze = true
	gravity_scale = 0.0

func apply_network_state(target_position: Vector3, target_rotation: Quaternion, target_velocity: Vector3) -> void:
	network_target_position = target_position
	network_target_rotation = target_rotation.normalized()
	network_velocity = target_velocity
	if not network_state_received:
		global_position = target_position
		quaternion = network_target_rotation
	network_state_received = true
