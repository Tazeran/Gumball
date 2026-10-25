extends Node3D

const PLAYER_SCENE := preload("res://objects/Base/player.tscn")
const ONLINE_PLAYER_CAPACITY := 16

@export var TeamMasterA: TeamMaster
@export var TeamMasterB: TeamMaster

@onready var ScreenGrid = $"UI Control/GridContainer"
@onready var Views := [$"UI Control/GridContainer/SubViewportContainer1", $"UI Control/GridContainer/SubViewportContainer2", $"UI Control/GridContainer/SubViewportContainer3", $"UI Control/GridContainer/SubViewportContainer4"]
@onready var Players: Array[Player] = [$Player1, $Player2, $Player3, $Player4]
@onready var PlayerMarkers: Array[Node3D] = [$Marker1, $Marker2, $Marker3, $Marker4]

func _ready() -> void:
	var session := get_node_or_null("/root/NetworkSession")
	var dedicated := session != null and bool(session.get("IsDedicatedServer"))
	var local_slots: Array[int] = []
	if session:
		for slot in session.get("LocalPlayerSlots"):
			local_slots.append(int(slot))
	var online := dedicated or not local_slots.is_empty()
	if online:
		_ensure_global_players(ONLINE_PLAYER_CAPACITY)
	else:
		for slot in range(1, Master.player_count + 1):
			local_slots.append(slot)
	_setup_local_views(local_slots)
	if not online:
		for index in range(Master.player_count, Players.size()):
			Players[index].queue_free()
			PlayerMarkers[index].queue_free()
	await get_tree().process_frame
	setRound(0)

func _ensure_global_players(count: int) -> void:
	var origin := Players[0].global_position
	while Players.size() < count:
		var slot := Players.size() + 1
		var player := PLAYER_SCENE.instantiate() as Player
		player.name = "Player%d" % slot
		player.player_id = slot
		player.team = "A" if slot % 2 == 1 else "B"
		add_child(player)
		var column := (slot - 1) % 4
		var row := (slot - 1) / 4
		player.global_position = origin + Vector3(column * 1.6, 0.0, row * 1.6)
		Players.append(player)
		var marker := Node3D.new()
		marker.name = "Marker%d" % slot
		add_child(marker)
		PlayerMarkers.append(marker)

func _setup_local_views(local_slots: Array[int]) -> void:
	var local_count := local_slots.size()
	ScreenGrid.columns = 1 if local_count == 1 else 2
	for view_index in range(Views.size()):
		var container = Views[view_index]
		if view_index >= local_count:
			container.queue_free()
			continue
		var global_slot := local_slots[view_index]
		if global_slot < 1 or global_slot > Players.size():
			push_error("Invalid assigned player slot %d" % global_slot)
			container.queue_free()
			continue
		_assign_view(Players[global_slot - 1], PlayerMarkers[global_slot - 1], container)
		_scale_hud(container, local_count)

func _assign_view(player: Player, marker: Node3D, container: SubViewportContainer) -> void:
	player.marker = marker
	player.sub_viewport = container
	player.hud = container.get_node("SubViewport/HUD")
	player.view_camera = container.get_node("SubViewport/View")
	player.view_camera.assign_player(player)
	player.setup()

func _scale_hud(container: SubViewportContainer, local_count: int) -> void:
	var scale := Vector2.ONE
	if local_count == 2:
		scale = Vector2(0.8, 0.8)
	elif local_count >= 3:
		scale = Vector2(0.6, 0.6)
	var root := container.get_node("SubViewport/HUD/ControlLayoutFullRect")
	for corner_name in ["ControlTopLeft", "ControlTopRight", "ControlBottomLeft", "ControlBottomRight"]:
		var corner := root.get_node_or_null(corner_name)
		if corner:
			corner.scale = scale

func setRound(_round: int) -> void:
	TeamMasterA.deal_hand()
	TeamMasterB.deal_hand()
