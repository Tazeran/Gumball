extends Node3D

const PLAYER_SCENE := preload("res://objects/Base/player.tscn")
@export var TeamMasterA: TeamMaster
@export var TeamMasterB: TeamMaster

@onready var ScreenGrid = $"UI Control/GridContainer"
@onready var Views := [$"UI Control/GridContainer/SubViewportContainer1", $"UI Control/GridContainer/SubViewportContainer2", $"UI Control/GridContainer/SubViewportContainer3", $"UI Control/GridContainer/SubViewportContainer4"]
@onready var Players: Array[Player] = [$Player1, $Player2, $Player3, $Player4]
@onready var PlayerMarkers: Array[Node3D] = [$Marker1, $Marker2, $Marker3, $Marker4]

var _online_players: Dictionary = {}
var _online_markers: Dictionary = {}
var _team_spawn_origins: Dictionary = {}
var _session: Node

func _ready() -> void:
	_session = get_node_or_null("/root/NetworkSession")
	var dedicated := _session != null and bool(_session.get("IsDedicatedServer"))
	var local_slots: Array[int] = []
	if _session:
		for slot in _session.get("LocalPlayerSlots"):
			local_slots.append(int(slot))
	var online := dedicated or not local_slots.is_empty()
	if online:
		_team_spawn_origins = {"A": Players[0].global_position, "B": Players[1].global_position}
		for player in Players:
			player.free()
		for marker in PlayerMarkers:
			marker.free()
		Players.clear()
		PlayerMarkers.clear()
		var active_slots: Array[int] = []
		for slot in _session.get("ActivePlayerSlots"):
			active_slots.append(int(slot))
		for slot in local_slots:
			if not active_slots.has(slot):
				active_slots.append(slot)
		_apply_online_roster(active_slots)
		_session.connect("RosterChanged", _on_roster_changed)
		_session.connect("PlayerStateReceived", _on_player_state_received)
		_session.connect("PlayerTeamChanged", _on_player_team_changed)
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

func _on_roster_changed(active_slots) -> void:
	var slots: Array[int] = []
	for slot in active_slots:
		slots.append(int(slot))
	_apply_online_roster(slots)

func _on_player_state_received(slot: int, position: Vector3, rotation_y: float, player_velocity: Vector3) -> void:
	var player: Player = _online_players.get(slot)
	if player:
		player.apply_network_state(position, rotation_y, player_velocity)

func _on_player_team_changed(slot: int, team: String) -> void:
	var player: Player = _online_players.get(slot)
	if player:
		player.apply_team(team, _team_spawn_position(slot, team), true)

func _apply_online_roster(active_slots: Array[int]) -> void:
	for existing_slot in _online_players.keys():
		if not active_slots.has(existing_slot):
			_online_players[existing_slot].queue_free()
			_online_markers[existing_slot].queue_free()
			_online_players.erase(existing_slot)
			_online_markers.erase(existing_slot)
	for slot in active_slots:
		if _online_players.has(slot):
			continue
		var player := PLAYER_SCENE.instantiate() as Player
		player.name = "Player%d" % slot
		player.player_id = slot
		var team := String(_session.call("GetPlayerTeam", slot))
		player.team = team
		player.position = _team_spawn_position(slot, team)
		add_child(player)
		_online_players[slot] = player
		var marker := Node3D.new()
		marker.name = "Marker%d" % slot
		add_child(marker)
		_online_markers[slot] = marker

func _team_spawn_position(slot: int, team: String) -> Vector3:
	var origin: Vector3 = _team_spawn_origins.get(team, Vector3.ZERO)
	var index := slot - 1
	var column := index % 4
	var row := index / 4
	var inward_direction := -1.0 if team == "A" else 1.0
	return origin + Vector3(column * 1.5 * inward_direction, 0.0, row * 1.5)

func _setup_local_views(local_slots: Array[int]) -> void:
	var local_count := local_slots.size()
	ScreenGrid.columns = 1 if local_count == 1 else 2
	for view_index in range(Views.size()):
		var container: SubViewportContainer = Views[view_index]
		if view_index >= local_count:
			container.queue_free()
			continue
		# Views 2–4 are dormant templates in arena1.tscn. Explicitly wake each
		# requested local view; otherwise GridContainer reserves its split while
		# the disabled SubViewport only displays its gray clear color.
		container.visible = true
		var sub_viewport := container.get_node("SubViewport") as SubViewport
		sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var global_slot := local_slots[view_index]
		var player: Player = _online_players.get(global_slot) if not _online_players.is_empty() else Players[global_slot - 1]
		var marker: Node3D = _online_markers.get(global_slot) if not _online_markers.is_empty() else PlayerMarkers[global_slot - 1]
		if player == null or marker == null:
			push_error("Invalid assigned player slot %d" % global_slot)
			container.queue_free()
			continue
		_assign_view(player, marker, container)
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
