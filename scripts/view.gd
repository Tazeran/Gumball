extends Node3D

@export_group("Links")
@export_group("Zoom")
@export var zoom_minimum := 16.0 #Make these and others vars in central location like game master or just code?
@export var zoom_maximum := 4.0
@export var zoom_speed := 10.0

@export_group("Rotation")
@export var rotation_speed := 120.0

var target: Node3D #set in game master or elsewhere
var player_id := 1 #set in game master or elsewhere
var sub_viewport: SubViewportContainer #set in game master or elsewhere

var camera_rotation: Vector3
var zoom := 10.0

@onready var camera = $Camera

# Use player-specific action names
var left
var right
var up
var down
var zoom_in
var zoom_out

func assignPlayer(player):
	target = player
	player_id = player.player_id
	sub_viewport = player.sub_viewport
	left = "camera_left_p" + str(player_id)
	right = "camera_right_p" + str(player_id)
	up = "camera_up_p" + str(player_id)
	down = "camera_down_p" + str(player_id)
	zoom_in = "zoom_in_p" + str(player_id)
	zoom_out = "zoom_out_p" + str(player_id)

func _ready():
	camera_rotation = rotation_degrees
	camera.current = true
	# Assign this camera to the specified SubViewport
	#if sub_viewport:
		#sub_viewport.add_child(self)  # Move the entire View node under SubViewport
		
	#else:
		#push_warning("No SubViewport assigned to View with player_id " + str(player_id))


func _physics_process(delta):
	# Follow target
	if(!target):
		return
	position = position.lerp(target.position, delta * 4)
	rotation_degrees = rotation_degrees.lerp(camera_rotation, delta * 6)
	camera.position = camera.position.lerp(Vector3(0, 0, zoom), 8 * delta)

	handle_input(delta)

func handle_input(delta):
	var input := Vector3.ZERO
	input.y = Input.get_action_strength(right) - Input.get_action_strength(left)
	input.x = Input.get_action_strength(down) - Input.get_action_strength(up)

	camera_rotation += input.limit_length(1.0) * rotation_speed * delta
	camera_rotation.x = clamp(camera_rotation.x, -80, -10)

	zoom += (Input.get_action_strength(zoom_in) - Input.get_action_strength(zoom_out)) * zoom_speed * delta
	zoom = clamp(zoom, zoom_maximum, zoom_minimum)
