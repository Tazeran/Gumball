extends CanvasLayer

#func connect_to_player(player):
#	print("Connecting ", self.name ," to player: ", player.name, " asdf ", $Coins)
#	player.connect("coin_collected", Callable(self, "_on_coin_collected"))
func _ready():
	print("HUD ready: ", name, " (ref: ", self, ")")


func _on_coin_collected(coins):
	print(">>> ", name, " got coin update: ", coins)
	$Coins.text = str(coins)
