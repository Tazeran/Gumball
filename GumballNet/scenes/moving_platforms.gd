extends Node3D

@onready var path: Path3D = $"Path3D"

#Space out the platforms evently
func _ready():
	return
	#await get_tree().process_frame
	var path_length = path.curve.get_baked_length()
	var platforms := []

	# Collect all direct or recursive children that are CharacterBody3D
	for child in get_children():
		if child is CharacterBody3D:
			platforms.append(child)
#
	#if platforms.is_empty():
		#return

	for i in range(platforms.size()):
		var platform = platforms[i]
		platform.distance_offset += path_length * (float(i) / float(platforms.size()))
		platform.distance = platform.distance_offset
		print(i, " ", platform, " ", platform.distance_offset)
