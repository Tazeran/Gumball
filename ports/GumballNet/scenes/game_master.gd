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
var _online := false
var _dedicated := false
var _world_frame_timer := 0.0
var _ground_pound_authorized: Dictionary = {}

func _ready() -> void:
	_session = get_node_or_null("/root/NetworkSession")
	var dedicated := _session != null and bool(_session.get("IsDedicatedServer"))
	_dedicated = dedicated
	var local_slots: Array[int] = []
	if _session:
		for slot in _session.get("LocalPlayerSlots"):
			local_slots.append(int(slot))
	var online := dedicated or not local_slots.is_empty()
	_online = online
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
		_session.connect("PlayerAssignmentChanged", _on_local_assignment_changed)
		_session.connect("PlayerStateReceived", _on_player_state_received)
		_session.connect("PlayerCorrectionReceived", _on_player_correction_received)
		_session.connect("PlayerTeamChanged", _on_player_team_changed)
		_session.connect("WorldInteractionRequested", _on_world_interaction_requested)
		_session.connect("WorldSnapshotRequested", _on_world_snapshot_requested)
		_session.connect("WorldStateReceived", _on_world_state_received)
		_session.connect("WorldFrameReceived", _on_world_frame_received)
		_session.connect("GroundPoundRequested", _on_ground_pound_requested)
		_session.connect("StaminaSpentRequested", _on_stamina_spent_requested)
	else:
		for slot in range(1, Master.player_count + 1):
			local_slots.append(slot)
	_setup_local_views(local_slots)
	if not online:
		for index in range(Master.player_count, Players.size()):
			Players[index].queue_free()
			PlayerMarkers[index].queue_free()
	await get_tree().process_frame
	if not online or dedicated:
		setRound(0)
	if dedicated:
		_broadcast_world_state()
	elif online:
		_session.call("RequestWorldSnapshot")

func _process(delta: float) -> void:
	if not _dedicated:
		return
	for player in _online_players.values():
		player.stamina = minf(player.stamina + player.stamina_regen_rate * delta, player.stamina_max)
	_world_frame_timer -= delta
	if _world_frame_timer <= 0.0:
		_world_frame_timer = 0.1
		# Keep each unreliable ENet packet comfortably below its MTU. Each partial
		# frame is independently applicable, so losing one category does not erase
		# state from another category.
		var frame := _capture_world_frame()
		_session.call("BroadcastWorldFrame", JSON.stringify({"players": frame.players, "enemies": frame.enemies}))
		_session.call("BroadcastWorldFrame", JSON.stringify({"marbles": frame.marbles}))
		_session.call("BroadcastWorldFrame", JSON.stringify({"pickups": frame.pickups, "buttons": frame.buttons}))
		var platform_offset := 0
		while platform_offset < frame.falling_platforms.size():
			var platform_chunk: Array = frame.falling_platforms.slice(platform_offset, platform_offset + 8)
			_session.call("BroadcastWorldFrame", JSON.stringify({"falling_platforms": platform_chunk,
				"falling_offset": platform_offset}))
			platform_offset += platform_chunk.size()

func _capture_world_frame() -> Dictionary:
	var players: Array = []
	for slot in _online_players:
		var player: Player = _online_players[slot]
		players.append({"slot": slot, "health": player.health, "stamina": player.stamina, "coins": player.coins})
	var enemies: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemies.append({"spawner": enemy.network_spawner_path,
			"p": [enemy.global_position.x, enemy.global_position.y, enemy.global_position.z], "r": enemy.rotation.y})
	var marbles: Array = []
	for marble in get_tree().get_nodes_in_group("network_marbles"):
		marbles.append({"id": marble.network_id,
			"p": [marble.global_position.x, marble.global_position.y, marble.global_position.z],
			"q": [marble.quaternion.x, marble.quaternion.y, marble.quaternion.z, marble.quaternion.w]})
	var pickup_states: Array = []
	for pickup in get_tree().get_nodes_in_group("network_pickups"):
		pickup_states.append(pickup.is_network_active())
	var buttons: Array = []
	for button in get_tree().get_nodes_in_group("network_buttons"):
		buttons.append(button.is_active)
	var falling_platforms: Array = []
	for platform in get_tree().get_nodes_in_group("network_falling_platforms"):
		falling_platforms.append([platform.position.x, platform.position.y, platform.position.z,
			platform.scale.x, platform.scale.y, platform.scale.z])
	return {"players": players, "enemies": enemies, "marbles": marbles, "pickups": pickup_states,
		"buttons": buttons, "falling_platforms": falling_platforms}

func _on_world_frame_received(json: String) -> void:
	if _dedicated:
		return
	var frame = JSON.parse_string(json)
	if typeof(frame) != TYPE_DICTIONARY:
		return
	for data in frame.get("players", []):
		var player: Player = _online_players.get(int(data.slot))
		if player:
			player.health = int(data.health)
			player.apply_authoritative_stamina(float(data.stamina))
			if player.coins != int(data.coins):
				player.coins = int(data.coins)
	if frame.has("enemies"):
		_apply_enemy_frame(frame.enemies)
	if frame.has("marbles"):
		_apply_marble_frame(frame.marbles)
	if frame.has("pickups"):
		var pickups := get_tree().get_nodes_in_group("network_pickups")
		var pickup_states: Array = frame.pickups
		for index in range(mini(pickups.size(), pickup_states.size())):
			pickups[index].set_network_active(bool(pickup_states[index]))
	if frame.has("buttons"):
		var buttons := get_tree().get_nodes_in_group("network_buttons")
		var button_states: Array = frame.buttons
		for index in range(mini(buttons.size(), button_states.size())):
			buttons[index].set_network_state(bool(button_states[index]))
	if frame.has("falling_platforms"):
		var falling_platforms := get_tree().get_nodes_in_group("network_falling_platforms")
		var platform_states: Array = frame.falling_platforms
		var platform_offset := int(frame.get("falling_offset", 0))
		for chunk_index in range(platform_states.size()):
			var platform_index := platform_offset + chunk_index
			if platform_index >= falling_platforms.size():
				break
			var data: Array = platform_states[chunk_index]
			falling_platforms[platform_index].position = Vector3(float(data[0]), float(data[1]), float(data[2]))
			falling_platforms[platform_index].scale = Vector3(float(data[3]), float(data[4]), float(data[5]))

func _apply_enemy_frame(states: Array) -> void:
	var live_spawners: Dictionary = {}
	for data in states:
		var path := String(data.spawner)
		live_spawners[path] = true
		var spawner = get_node_or_null(NodePath(path))
		if spawner == null:
			continue
		if not is_instance_valid(spawner.current_monster):
			spawner.spawn_monster()
		var enemy = spawner.current_monster
		enemy.global_position = Vector3(float(data.p[0]), float(data.p[1]), float(data.p[2]))
		enemy.rotation.y = float(data.r)
	for spawner in get_tree().get_nodes_in_group("monster_spawners"):
		if not live_spawners.has(str(spawner.get_path())) and is_instance_valid(spawner.current_monster):
			spawner.current_monster.free()
			spawner.current_monster = null

func _apply_marble_frame(states: Array) -> void:
	var spawner = get_node_or_null("MarbleSpawner")
	if spawner == null:
		return
	var by_id: Dictionary = {}
	for marble in get_tree().get_nodes_in_group("network_marbles"):
		by_id[marble.network_id] = marble
	var live: Dictionary = {}
	for data in states:
		var id := int(data.id)
		live[id] = true
		var marble = by_id.get(id)
		if marble == null:
			marble = spawner.marble_scene.instantiate()
			marble.network_id = id
			marble.freeze = true
			add_child(marble)
		var target := Vector3(float(data.p[0]), float(data.p[1]), float(data.p[2]))
		marble.global_position = marble.global_position.lerp(target, 0.65)
		marble.quaternion = Quaternion(float(data.q[0]), float(data.q[1]), float(data.q[2]), float(data.q[3]))
	for id in by_id:
		if not live.has(id):
			by_id[id].free()

func _on_world_interaction_requested(slot: int, target_path: String, hold: bool) -> void:
	if not _dedicated:
		return
	var player: Player = _online_players.get(slot)
	var target := get_tree().current_scene.get_node_or_null(NodePath(target_path))
	if player == null or target == null:
		push_warning("Rejected interaction for slot %d: unknown target '%s'." % [slot, target_path])
		return
	if player.global_position.distance_to(target.global_position) > 8.0:
		push_warning("Rejected distant interaction for slot %d and target '%s' (%.2fm)." % [
			slot, target_path, player.global_position.distance_to(target.global_position)])
		return
	if not target.has_method("interaction_available") or not bool(target.interaction_available(player)):
		push_warning("Rejected unavailable interaction for slot %d and target '%s'." % [slot, target_path])
		return
	if hold and target.has_method("finish_hold"):
		target.finish_hold(player)
	elif target.has_method("interact"):
		target.interact(player)
	await get_tree().process_frame
	_broadcast_world_state()

func _on_ground_pound_requested(slot: int, position: Vector3, impact_speed: float) -> void:
	if not _dedicated or not _online_players.has(slot):
		return
	var player: Player = _online_players[slot]
	if not _ground_pound_authorized.get(slot, false) or player.global_position.distance_to(position) > 3.0:
		return
	_ground_pound_authorized.erase(slot)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - position
		if Vector2(offset.x, offset.z).length() <= player.ground_pound_impact_radius and absf(offset.y) <= 1.6:
			enemy.receive_ground_pound(player, impact_speed)
	for button in get_tree().get_nodes_in_group("network_buttons"):
		if button.global_position.distance_to(position) <= player.ground_pound_impact_radius:
			button.press()
	await get_tree().process_frame
	_broadcast_world_state()

func _on_stamina_spent_requested(slot: int, action: String) -> void:
	if not _dedicated or not _online_players.has(slot):
		return
	var player: Player = _online_players[slot]
	var cost := 0.0
	match action:
		"double_jump": cost = player.double_jump_stamina_cost
		"crouch_jump": cost = player.crouch_jump_stamina_cost
		"ground_pound": cost = player.ground_pound_stamina_cost
		_: return
	if player.stamina < cost:
		return
	player.stamina -= cost
	if action == "ground_pound":
		_ground_pound_authorized[slot] = true

func _on_world_snapshot_requested(peer_id: int) -> void:
	if _dedicated:
		_session.call("SendWorldState", peer_id, JSON.stringify(_capture_world_state()))

func _broadcast_world_state() -> void:
	if _dedicated:
		_session.call("BroadcastWorldState", JSON.stringify(_capture_world_state()))

func _capture_world_state() -> Dictionary:
	var card_states: Array = []
	for card in get_tree().get_nodes_in_group("cards"):
		card_states.append({
			"id": card.network_id,
			"team": card.team,
			"suit": card.suit,
			"rank": card.rank,
			"face_up": card.is_face_up,
			"state": card.state,
			"carrier": card.carrier_player.player_id if card.carrier_player else 0,
			"position": [card.global_position.x, card.global_position.y, card.global_position.z],
			"rotation": [card.rotation.x, card.rotation.y, card.rotation.z]
		})
	var stack_states: Array = []
	for stack in get_tree().get_nodes_in_group("decks"):
		var ids: Array = []
		for card in stack.cards:
			ids.append(card.network_id)
		stack_states.append({"path": str(get_path_to(stack)), "cards": ids,
			"locked_by": stack.locked_by_card.network_id if stack.locked_by_card else ""})
	var player_states: Array = []
	for slot in _online_players:
		var player: Player = _online_players[slot]
		player_states.append({"slot": slot, "health": player.health, "stamina": player.stamina, "coins": player.coins})
	return {"cards": card_states, "stacks": stack_states, "players": player_states}

func _on_world_state_received(json: String) -> void:
	if _dedicated:
		return
	var state = JSON.parse_string(json)
	if typeof(state) != TYPE_DICTIONARY:
		return
	_apply_card_state(state.get("cards", []), state.get("stacks", []))
	for player_state in state.get("players", []):
		var player: Player = _online_players.get(int(player_state.slot))
		if player:
			player.health = int(player_state.health)
			player.stamina = float(player_state.stamina)
			player.coins = int(player_state.coins)
			if player.hud:
				player.hud.set_health(player.health, player.health_max)
				player.hud.set_stamina_percent(player.stamina / player.stamina_max)

func _apply_card_state(card_states: Array, stack_states: Array) -> void:
	for player in _online_players.values():
		player.carried_cards.clear()
	for stack in get_tree().get_nodes_in_group("decks"):
		stack.cards.clear()
		stack.unlock_stack()
	for old_card in get_tree().get_nodes_in_group("cards"):
		old_card.free()
	var cards_by_id: Dictionary = {}
	for data in card_states:
		var master: TeamMaster = TeamMasterA if String(data.team) == TeamMasterA.team_name else TeamMasterB
		var card = master.card_scene.instantiate()
		card.network_id = String(data.id)
		card.name = "Card_%s" % String(data.id).replace(":", "_")
		master.add_child(card)
		card.set_team(String(data.team))
		card.set_card(String(data.suit), String(data.rank), Master.team_backs[String(data.team)])
		cards_by_id[card.network_id] = card
	for stack_data in stack_states:
		var stack: DeckStack = get_node_or_null(NodePath(String(stack_data.path)))
		if stack == null:
			continue
		for card_id in stack_data.cards:
			if cards_by_id.has(String(card_id)):
				stack.add_card(cards_by_id[String(card_id)])
		var locked_id := String(stack_data.locked_by)
		if not locked_id.is_empty() and cards_by_id.has(locked_id):
			stack.lock_stack(cards_by_id[locked_id])
	for data in card_states:
		var card = cards_by_id[String(data.id)]
		var carrier_slot := int(data.carrier)
		if carrier_slot > 0 and _online_players.has(carrier_slot):
			_online_players[carrier_slot].pick_up_card(card)
		elif int(data.state) == PCard.CardState.FREE_FLOATING:
			card.global_position = Vector3(float(data.position[0]), float(data.position[1]), float(data.position[2]))
			card.rotation = Vector3(float(data.rotation[0]), float(data.rotation[1]), float(data.rotation[2]))
			card.drop_to_ground()
		card.set_face_up(bool(data.face_up))

func _on_roster_changed(active_slots) -> void:
	var slots: Array[int] = []
	for slot in active_slots:
		slots.append(int(slot))
	_apply_online_roster(slots)
	_refresh_local_views()

func _on_local_assignment_changed(_slot: int, _owner: bool) -> void:
	# Assignment and roster RPCs can arrive in either order. Waiting one frame
	# lets newly-added player nodes exist before their cameras are rebound.
	await get_tree().process_frame
	_refresh_local_views()

func _refresh_local_views() -> void:
	if _session == null or bool(_session.get("IsDedicatedServer")):
		return
	var local_slots: Array[int] = []
	for slot in _session.get("LocalPlayerSlots"):
		local_slots.append(int(slot))
	_setup_local_views(local_slots)

func _on_player_state_received(slot: int, position: Vector3, rotation_y: float, player_velocity: Vector3) -> void:
	var player: Player = _online_players.get(slot)
	if player:
		player.apply_network_state(position, rotation_y, player_velocity)

func _on_player_correction_received(slot: int, position: Vector3, rotation_y: float, player_velocity: Vector3) -> void:
	var player: Player = _online_players.get(slot)
	if player:
		player.global_position = position
		player.rotation.y = rotation_y
		player.velocity = player_velocity
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
			container.visible = false
			var dormant_viewport := container.get_node("SubViewport") as SubViewport
			dormant_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			container.get_node("SubViewport/View").set("target", null)
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
			container.visible = false
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
