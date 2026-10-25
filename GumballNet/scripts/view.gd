extends Node3D

@onready var camera = $Camera

@export_group("Zoom")
@export var zoom_levels := [6.0, 10.0, 16.0]  # Close, Medium, Far
@export var zoom_transition_speed := 8.0

@export_group("Rotation")
@export var rotation_speed := 120.0
@export var auto_align_strength := 3.5  # Follow behind player movement

var target: Node3D
var player_id := 1
var sub_viewport: SubViewportContainer

var camera_rotation: Vector3
var zoom_index := 1  # start at medium
var current_zoom := 10.0
var desired_zoom := 10.0

# Input actions
var input_left := ""
var input_right := ""
var input_up := ""
var input_down := ""
var input_zoom_toggle := ""

var snap_camera := false  # Tracks if snap is requested


func assign_player(player):
	target = player
	player_id = player.input_profile_id
	sub_viewport = player.sub_viewport

	input_left = "camera_left_p%d" % player_id
	input_right = "camera_right_p%d" % player_id
	input_up = "camera_up_p%d" % player_id
	input_down = "camera_down_p%d" % player_id
	input_zoom_toggle = "camera_toggle_zoom_p%d" % player_id

func _ready():
	camera_rotation = rotation_degrees
	camera.current = true
	desired_zoom = zoom_levels[zoom_index]
	current_zoom = desired_zoom

func _physics_process(delta):
	if not target:
		return

	handle_input(delta)

	# Smooth follow and orbit
	position = position.lerp(target.position, delta * 4)
	rotation_degrees = rotation_degrees.lerp(camera_rotation, delta * 6)
	camera.position = camera.position.lerp(Vector3(0, 0, current_zoom), delta * zoom_transition_speed)

func handle_input(delta):
	if target and target.network_session and bool(target.network_session.call("IsControllerInputBlocked", target.local_controller_device)):
		return
	var input_vec = Vector2(
		Input.get_action_strength(input_right) - Input.get_action_strength(input_left),
		Input.get_action_strength(input_down) - Input.get_action_strength(input_up)
	)

	var is_orbiting = input_vec.length() > 0.1
	var snap_pressed = Input.is_action_just_pressed("camera_snap_p%d" % player_id)

	if is_orbiting:
		# Manual orbit via stick
		camera_rotation.y += input_vec.x * rotation_speed * delta
		camera_rotation.x += input_vec.y * rotation_speed * delta
		camera_rotation.x = clamp(camera_rotation.x, -80, -10)
		snap_camera = false  # cancel snap if orbiting

	elif target and target.has_method("get_velocity"):
		var velocity = target.get_velocity()

		if snap_pressed:
			# Immediately start snapping camera behind player
			snap_camera = true

		if velocity.length() > 0.1:
			var desired_yaw = rad_to_deg(atan2(-velocity.x, -velocity.z))

			if snap_camera:
				# Fast alignment when snapping
				camera_rotation.y = lerp_angle(camera_rotation.y, desired_yaw, delta * 10.0)

				# Close enough? Stop snapping
				if abs(wrapf(camera_rotation.y - desired_yaw, -180.0, 180.0)) < 3.0:
					snap_camera = false
			else:
				# Slow soft-follow alignment
				camera_rotation.y = lerp_angle(camera_rotation.y, desired_yaw, delta * 1.5)

	# Optional: fixed zoom
	current_zoom = lerp(current_zoom, zoom_levels[zoom_index], delta * zoom_transition_speed)
