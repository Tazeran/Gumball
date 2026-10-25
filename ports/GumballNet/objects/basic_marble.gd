extends RigidBody3D

@export var kill_y_threshold: float = -10.0
var spawner  # Assigned externally
var network_id := 0

func _ready():
	add_to_group("network_marbles")

func _physics_process(delta):
	if global_transform.origin.y < kill_y_threshold:
		queue_free()

		if spawner and spawner.has_method("_on_marble_deleted"):
			spawner._on_marble_deleted()
