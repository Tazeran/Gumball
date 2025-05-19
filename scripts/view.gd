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

func assign_player(player):
	target = player
	player_id = player.player_id
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
	# Orbit input (right stick)
	var input_vec = Vector2(
		Input.get_action_strength(input_right) - Input.get_action_strength(input_left),
		Input.get_action_strength(input_down) - Input.get_action_strength(input_up)
	)

	var is_orbiting = input_vec.length() > 0.1

	if is_orbiting:
		camera_rotation.y += input_vec.x * rotation_speed * delta
		camera_rotation.x += input_vec.y * rotation_speed * delta
		camera_rotation.x = clamp(camera_rotation.x, -80, -10)
	elif target and target.has_method("get_velocity"):
		var velocity = target.get_velocity()
		if velocity.length() > 0.1:
			var desired_yaw = atan2(-velocity.x, -velocity.z)
			camera_rotation.y = lerp_angle(camera_rotation.y, rad_to_deg(desired_yaw), delta * auto_align_strength)

	# Zoom toggle (right stick press)
	if Input.is_action_just_pressed(input_zoom_toggle):
		zoom_index = (zoom_index + 1) % zoom_levels.size()
		desired_zoom = zoom_levels[zoom_index]

	current_zoom = lerp(current_zoom, desired_zoom, delta * zoom_transition_speed)
