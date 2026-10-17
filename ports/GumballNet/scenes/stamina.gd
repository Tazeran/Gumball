extends RigidBody3D

@onready var mesh_holder := $MeshHolder
@onready var pickup_area := $Area3D

var base_offset := Vector3.ZERO
var bob_timer := 0.0
var bob_speed := 2.0
var bob_height := 0.2
var collected := false

func _ready():
	base_offset = mesh_holder.position
	pickup_area.body_entered.connect(_on_body_entered)

	print("Initial position:", global_position)
	gravity_scale = 1.0
	sleeping = false

func _process(delta):
	if collected:
		return
	bob_timer += delta * bob_speed
	mesh_holder.position.y = base_offset.y + sin(bob_timer) * bob_height

func _on_body_entered(body):
	print("STAM: ", body.get_path())
	if collected:
		return
	if body.has_method("collect_stamina"):
		print("COLLECT: ", body.name)
		body.collect_stamina()
		collected = true
		$Particles.emitting = false
		$MeshHolder.visible = false
		queue_free()
