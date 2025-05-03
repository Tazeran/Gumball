extends CanvasLayer
#var ring

@onready var aring = $Interact/Prompt_A/Ring
@onready var interact = $Interact
@onready var interact_prompt = $Interact/Prompt

#func connect_to_player(player):
#	print("Connecting ", self.name ," to player: ", player.name, " asdf ", $Coins)
#	player.connect("coin_collected", Callable(self, "_on_coin_collected"))
func _ready():
	print("HUD ready: ", name, " (ref: ", self, ")")
	#ring = $Ring

func set_aring_percent(val: float):
	aring.percent = val

func set_stamina_percent(val: float):
	if has_node("Ring"):
		var ring = $Ring
		if ring:
			ring.percent = val

func set_health(val: int, val_max: int):
	if has_node("HeartBar"):
		var heartbar = $HeartBar
		if heartbar:
			heartbar.set_health(val, val_max)

func _on_coin_collected(coins):
	print(">>> ", name, " got coin update: ", coins)
	$Coins.text = str(coins)
