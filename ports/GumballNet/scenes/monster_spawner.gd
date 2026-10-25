extends Node3D

@export var monster_scene: PackedScene
@export var respawn_delay: float = 12.0

var current_monster: Node = null
var respawn_timer: Timer

func _ready():
	add_to_group("monster_spawners")
	respawn_timer = Timer.new()
	respawn_timer.one_shot = true
	respawn_timer.wait_time = respawn_delay
	respawn_timer.timeout.connect(_on_respawn_timeout)
	add_child(respawn_timer)

	# The arena may still be attaching its children during this node's _ready.
	# Defer spawning so the monster can safely enter the scene tree.
	var session = get_node_or_null("/root/NetworkSession")
	if session == null or bool(session.get("IsDedicatedServer")) or Array(session.get("LocalPlayerSlots")).is_empty():
		call_deferred("spawn_monster")

func spawn_monster():
	if monster_scene == null:
		print("TRYING TO Spawn Monster", monster_scene)
		push_error("No monster scene assigned!")
		return

	current_monster = monster_scene.instantiate()
	current_monster.set("network_spawner_path", str(get_path()))
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
