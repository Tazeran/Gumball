extends Node
@onready var start_p1 = $"CanvasLayer/UI Control/VBoxContainer/ButtonStart1"
@onready var start_p2 = $"CanvasLayer/UI Control/VBoxContainer/ButtonStart2"
@onready var start_p3 = $"CanvasLayer/UI Control/VBoxContainer/ButtonStart3"
@onready var start_p4 = $"CanvasLayer/UI Control/VBoxContainer/ButtonStart4"
@onready var quit = $"CanvasLayer/UI Control/VBoxContainer/ButtonQuit"

func _ready():
	var current = get_tree().current_scene
	var target_path = ""

	match Master.launch_mode:
		Master.LaunchMode.MAIN_MENU:
			target_path = Master.landing_scene_path
			setupMenu()
		Master.LaunchMode.DEV_DIRECT:
			target_path = Master.dev_scene_path

	if current and current.scene_file_path == target_path:
		return  # Already in the target scene, avoid reloading

	get_tree().change_scene_to_file(target_path)

func setupMenu():
	start_p1.grab_focus()
	start_p1.pressed.connect(_on_start_pressed.bind(1))
	start_p2.pressed.connect(_on_start_pressed.bind(2))
	start_p3.pressed.connect(_on_start_pressed.bind(3))
	start_p4.pressed.connect(_on_start_pressed.bind(4))
	quit.pressed.connect(_on_quit_pressed)

func _on_start_pressed(player_count: int):
	Master.player_count = player_count
	print("Start pressed: ", player_count)
	get_tree().change_scene_to_file(Master.priscilla1)

func _on_quit_pressed():
	get_tree().quit()
