extends CanvasLayer

@export var player_id := 1  # Assigned when instancing

func _ready():
	# Connect to the right player’s signal
	var player = find_player_by_id(player_id)
	if player:
		player.connect("coin_collected", self, "_on_coin_collected")

func _on_coin_collected(coins):
	$Coins.text = str(coins)

func find_player_by_id(id):
	for player in get_tree().get_nodes_in_group("players"):
		if player.player_id == id:
			return player
	return null
