extends Node3D

@export var monster_scene: PackedScene
@export var respawn_delay: float = 12.0

var current_monster: Node = null
var respawn_timer: Timer

func _ready():
	respawn_timer = Timer.new()
	respawn_timer.one_shot = true
	respawn_timer.wait_time = respawn_delay
	respawn_timer.timeout.connect(_on_respawn_timeout)
	add_child(respawn_timer)

	spawn_monster()

func spawn_monster():
	if monster_scene == null:
		print("TRYING TO Spawn Monster", monster_scene)
		push_error("No monster scene assigned!")
		return

	current_monster = monster_scene.instantiate()
	get_tree().current_scene.add_child(current_monster)
	current_monster.global_position = global_position

	print("Spawn Monster", current_monster)
	
	# Listen for a 'defeated' or 'dead' signal (you must emit this from your monster)
	if current_monster.has_signal("defeated"):
		current_monster.connect("defeated", _on_monster_defeated)
	else:
		push_warning("Monster does not have 'defeated' signal. You must implement this in your monster script.")

func _on_monster_defeated():
	current_monster = null
	respawn_timer.start()

func _on_respawn_timeout():
	spawn_monster()
