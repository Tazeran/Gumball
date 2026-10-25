extends Node
@onready var doNothing = $"CanvasLayer/UI Control/VBoxContainer/DoNothing"
@onready var start_p1 = $"CanvasLayer/UI Control/VBoxContainer/ButtonStart1"
@onready var start_p2 = $"CanvasLayer/UI Control/VBoxContainer/ButtonStart2"
@onready var start_p3 = $"CanvasLayer/UI Control/VBoxContainer/ButtonStart3"
@onready var start_p4 = $"CanvasLayer/UI Control/VBoxContainer/ButtonStart4"
@onready var quit = $"CanvasLayer/UI Control/VBoxContainer/ButtonQuit"

func testJoys():
	print("----")
	#var mapping_string = "030000005e0400008e02000000000000,Xbox Controller,a:b0,b:b1,x:b2,y:b3,back:b6,start:b7,leftshoulder:b4,rightshoulder:b5,leftstick:b8,rightstick:b9,dpleft:b10,dpdown:b11,dpright:b12,dpup:b13,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:a4,righttrigger:a5"
	#Input.add_joy_mapping(mapping_string, true)
	
	for id in range(8):
		var name = Input.get_joy_name(id)
		var guid = Input.get_joy_guid(id)
		if guid != "":
			print("Device", id, "Name:", name, "GUID:", guid)

	#for id in range(16):
		#var name = Input.get_joy_name(id)
		#if name != "":
			#print("Device ID:", id, "Name:", name, "GUID:", Input.get_joy_guid(id))
	print(Input.get_connected_joypads())
	for id in range(8):
		print("ID:", id, " name:", Input.get_joy_name(id), " guid:", Input.get_joy_guid(id))
	#for i in range(0,7):
		#print("[",i,"] ", Input.get_joy_name(i))


func _ready():
	#testJoys()
	var current = get_tree().current_scene
	var target_path = ""

	match Master.launch_mode:
		Master.LaunchMode.MAIN_MENU:
			target_path = Master.landing_scene_path
			setupMenu()
		Master.LaunchMode.DEV_DIRECT:
			target_path = Master.dev_scene_path
			Master.player_count = 2
			

	if current and current.scene_file_path == target_path:
		return  # Already in the target scene, avoid reloading

	get_tree().change_scene_to_file(target_path)

func setupMenu():
	doNothing.grab_focus()
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
