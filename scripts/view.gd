extends Node3D

@export_group("Links")
@export var target: Node
@export var player_id := 1 # Player ID for input filtering
@export var sub_viewport: SubViewport  # 👈 manually assign this in editor

@export_group("Zoom")
@export var zoom_minimum := 16.0
@export var zoom_maximum := 4.0
@export var zoom_speed := 10.0

@export_group("Rotation")
@export var rotation_speed := 120.0


var camera_rotation: Vector3
var zoom := 10.0

@onready var camera = $Camera

func _ready():
	camera_rotation = rotation_degrees
	# Assign this camera to the specified SubViewport
	if sub_viewport:
		sub_viewport.add_child(self)  # Move the entire View node under SubViewport
		camera.current = true
	else:
		push_warning("No SubViewport assigned to View with player_id " + str(player_id))


func _physics_process(delta):
	# Follow target
	position = position.lerp(target.position, delta * 4)
	rotation_degrees = rotation_degrees.lerp(camera_rotation, delta * 6)
	camera.position = camera.position.lerp(Vector3(0, 0, zoom), 8 * delta)

	handle_input(delta)

func handle_input(delta):
	# Use player-specific action names
	var left = "camera_left_p" + str(player_id)
	var right = "camera_right_p" + str(player_id)
	var up = "camera_up_p" + str(player_id)
	var down = "camera_down_p" + str(player_id)
	var zoom_in = "zoom_in_p" + str(player_id)
	var zoom_out = "zoom_out_p" + str(player_id)

	var input := Vector3.ZERO
	input.y = Input.get_action_strength(right) - Input.get_action_strength(left)
	input.x = Input.get_action_strength(down) - Input.get_action_strength(up)

	camera_rotation += input.limit_length(1.0) * rotation_speed * delta
	camera_rotation.x = clamp(camera_rotation.x, -80, -10)

	zoom += (Input.get_action_strength(zoom_in) - Input.get_action_strength(zoom_out)) * zoom_speed * delta
	zoom = clamp(zoom, zoom_maximum, zoom_minimum)
