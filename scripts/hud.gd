extends CanvasLayer
#var ring

@onready var interact_ring = $ControlLayoutFullRect/ControlBottomRight/Interact/Prompt_A/Ring
@onready var stamina_ring = $ControlLayoutFullRect/ControlTopRight/Ring
@onready var interact = $ControlLayoutFullRect/ControlBottomRight/Interact
@onready var interact_prompt = $ControlLayoutFullRect/ControlBottomRight/Interact/Prompt
@onready var coins_text = $ControlLayoutFullRect/ControlBottomLeft/ControlCoins/Coins
@onready var heartbar = $ControlLayoutFullRect/ControlTopLeft/HeartBar

#func connect_to_player(player):
#	print("Connecting ", self.name ," to player: ", player.name, " asdf ", $Coins)
#	player.connect("coin_collected", Callable(self, "_on_coin_collected"))
func _ready():
	print("HUD ready: ", name, " (ref: ", self, ")")
	#ring = $Ring

func set_aring_percent(val: float):
	interact_ring.percent = val

func set_stamina_percent(val: float):
	stamina_ring.percent = val

func set_health(val: int, val_max: int):
	heartbar.set_health(val, val_max)

func update_coins(coins):
	print(">>> ", name, " got coin update: ", coins)
	coins_text.text = str(coins)
