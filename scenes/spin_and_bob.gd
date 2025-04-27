extends Node3D
var players: Array = []
@export var spin_speed := 40.0
@export var bob_height := 0.2
@export var bob_speed := 1.0
@export var detection_distance := 5.0

var id := -1;
var bob_timer := 0.0
var base_position := Vector3.ZERO

func _ready() -> void:
	base_position = global_position
	players = get_tree().get_nodes_in_group("players")
	#print(base_position, players)

func _process(delta: float) -> void:
	# Always bobbing
	players = get_tree().get_nodes_in_group("players")
	bob_timer += delta * bob_speed
	var offset_y = (sin(bob_timer) * 0.5 + 0.5) * bob_height
	global_position = base_position + Vector3(0, offset_y, 0)

	if players.is_empty():
		return

	var closest_player = get_closest_player()
	if closest_player:
		#get_child(0).set_edge_color(Color.GREEN)
		face_player(closest_player, delta)
	else:
		#get_child(0).set_edge_color(Color.DARK_GOLDENROD)
		rotate_y(deg_to_rad(spin_speed * delta))

func get_closest_player() -> Node3D:
	var closest_player = null
	var closest_dist = detection_distance

	for player in players:
		if not player:  # Player might have been deleted
			continue
		var dist = global_position.distance_to(player.global_position)
		if dist <= closest_dist:
			closest_dist = dist
			closest_player = player

	return closest_player

func face_player(player: Node3D, delta: float) -> void:
	var to_player = (player.global_position - global_position).normalized()
	var target_rotation = atan2(to_player.x, to_player.z)
	var current_yaw = rotation.y
	var new_yaw = lerp_angle(current_yaw, target_rotation, delta * 2.0)
	rotation.y = new_yaw
