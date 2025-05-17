extends Node3D

@export var TeamMasterA: TeamMaster
@export var TeamMasterB: TeamMaster

func _ready():
	await get_tree().process_frame
	setRound(0)
	#Audio.play_music("")

func setRound(round: int):
	TeamMasterA.deal_hand()
	TeamMasterB.deal_hand()
