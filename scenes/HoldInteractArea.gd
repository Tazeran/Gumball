class_name HoldInteractable
extends Area3D

@export var hold_time_required: float = 1.5  # Seconds to trigger
@export var one_shot: bool = false  # Disable after activation
@export var prompt_text: String = "Hold to Buy"
@export var team: String = "" #Any
var interaction_available_delegate: Callable  #set at ready with the delegate node

signal hold_completed(player: Node)


var holding_players: Dictionary = {}  # player_id -> { time: float, player: Node }
var has_triggered := false

func _ready():
	add_to_group("interactables")

#TODO Could be a whole interact information, text, type, position, visible, etcc
func get_marker_position(player: Player):
	return global_position

func interaction_available(player: Player) -> bool:
	if team != "":
		if player.team != team:
			return false
	if interaction_available_delegate and interaction_available_delegate.is_valid():
		return interaction_available_delegate.call(player, self)
	#if interaction_available_delegate and interaction_available_delegate.has_method("interaction_available"):
		#return interaction_available_delegate.interaction_available(player, self)
	return true

func finish_hold(player: Player):
	if one_shot:
		has_triggered = true
		monitoring = false
		set_deferred("monitorable", false)
	hold_completed.emit(player)

#func _process(delta):
	#if one_shot and has_triggered:
		#return
#
	#for player_id in holding_players.keys():
		#var entry = holding_players[player_id]
		#if !is_instance_valid(entry.player):
			#holding_players.erase(player_id)
			#continue
#
		#entry.time += delta
		##var progress = entry.time / hold_time_required
#
		#if entry.time >= hold_time_required:
			#print("Player", player_id, "finished holding", )
			#hold_completed.emit(player_id, entry.player)
			#holding_players.erase(player_id)
			#if one_shot:
				#has_triggered = true
				#monitoring = false
				#set_deferred("monitorable", false)

#func start_holding(player_id: int, player: Node):
	#if has_triggered or !is_instance_valid(player):
		#return
	#if !interaction_available(player):
		#return
	#if !holding_players.has(player_id):
		#holding_players[player_id] = {
			#"time": 0.0,
			#"player": player
		#}
#
#func stop_holding(player_id: int):
	#if holding_players.has(player_id):
		#holding_players.erase(player_id)
#
#func get_hold_progress(player_id: int) -> float:
	#if holding_players.has(player_id):
		#return clamp(holding_players[player_id].time / hold_time_required, 0, 1)
	#return 0.0



#extends Area3D
#
#@export var hold_time_required: float = 1.5  # Seconds needed to activate
#
#signal hold_progress(player_id: int, progress: float)
#signal hold_completed(player_id: int)
#
#var holding_players: Dictionary = {}  # player_id -> current hold time
#
#func _ready():
	#add_to_group("interactables")
#
#func _process(delta):
	#for player_id in holding_players.keys():
		#holding_players[player_id] += delta
		#var progress = holding_players[player_id] / hold_time_required
#
		## Emit progress for HUD
		#hold_progress.emit(player_id, clamp(progress, 0, 1))
#
		#if holding_players[player_id] >= hold_time_required:
			## Player finished holding!
			#print("Player finished holding to activate!")
			#hold_completed.emit(player_id)
			#holding_players.erase(player_id)
#
#func progress(player_id: int):
	#if holding_players.has(player_id):
		#return holding_players[player_id]
#
#func start_holding(player_id: int):
	#if !holding_players.has(player_id):
		#holding_players[player_id] = 0.0
#
#func stop_holding(player_id: int):
	#if holding_players.has(player_id):
		#holding_players.erase(player_id)
		## Optionally emit a "hold cancelled" signal if needed
