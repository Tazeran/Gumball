extends Node3D

@export var TeamMasterA: TeamMaster
@export var TeamMasterB: TeamMaster

@onready var ScreenGrid = $"UI Control/GridContainer"
@onready var Views := [
	$"UI Control/GridContainer/SubViewportContainer1",
	$"UI Control/GridContainer/SubViewportContainer2",
	$"UI Control/GridContainer/SubViewportContainer3",
	$"UI Control/GridContainer/SubViewportContainer4"
]
@onready var Players := [
	$"Player1",
	$"Player2",
	$"Player3",
	$"Player4"
]
@onready var PlayerMarkers := [
	$"Marker1",
	$"Marker2",
	$"Marker3",
	$"Marker4",
]

func assignSubViewportContainerToPlayer(player, marker, subviewportcontainer):
	print("attachSubViewportContainerToPlayer ", subviewportcontainer, player, marker)
	player.marker = marker
	player.sub_viewport = subviewportcontainer
	player.hud = subviewportcontainer.get_node("SubViewport/HUD")
	player.view_camera = subviewportcontainer.get_node("SubViewport/View")
	player.view_camera.assignPlayer(player)
	player.setup()

func _ready():
	#get master variables and set things up
	#UI Control
	#Master.player_count
	#enable disable players, selectors, and cameras and UI?
	#for 1 player, set gridcontainer columns to 1
	#there might be a margin 1-2px to turn off somewhere too
	if(Master.player_count == 1):
		ScreenGrid.columns = 1
	else:
		ScreenGrid.columns = 2

	for i in range(Views.size()):
		var container = Views[i]
		assignSubViewportContainerToPlayer(Players[i], PlayerMarkers[i], container)
		container.visible = i < Master.player_count
		if(i >= Master.player_count):
			container.queue_free()
			PlayerMarkers[i].queue_free()
			Players[i].queue_free()
			continue;
		var top_left = container.get_node("SubViewport/HUD/ControlLayoutFullRect/ControlTopLeft")
		var top_right = container.get_node("SubViewport/HUD/ControlLayoutFullRect/ControlTopRight")
		var bottom_left = container.get_node("SubViewport/HUD/ControlLayoutFullRect/ControlBottomLeft")
		var bottom_right = container.get_node("SubViewport/HUD/ControlLayoutFullRect/ControlBottomRight")
		if top_left == null:
			continue
		var scale = null
		match Master.player_count:
			1:
				scale = Vector2(1, 1)
			2:
				scale = Vector2(0.8, 0.8)
			3, 4:
				scale = Vector2(0.6, 0.6)
		top_left.scale = scale
		top_right.scale = scale
		bottom_left.scale = scale
		bottom_right.scale = scale

	await get_tree().process_frame
	setRound(0)
	#Audio.play_music("")

func setRound(round: int):
	TeamMasterA.deal_hand()
	TeamMasterB.deal_hand()
