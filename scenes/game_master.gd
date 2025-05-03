extends Node3D

@export var card_scene: PackedScene  # Your Card.tscn

@export var A_DeckStack: DeckStack
@export var B_DeckStack: DeckStack
#each the other piles as well

var team_a_deck: Deck
var team_b_deck: Deck

func _ready():
	# Initialize decks
	team_a_deck = Deck.new()
	team_a_deck.create_full_deck()
	team_a_deck.shuffle()

	team_b_deck = Deck.new()
	team_b_deck.create_full_deck()
	team_b_deck.shuffle()

	# Debug: print how many cards
	print("Team A deck cards:", team_a_deck.cards_remaining())
	print("Team B deck cards:", team_b_deck.cards_remaining())

	A_DeckStack.team = "A"
	B_DeckStack.team = "B"
	
	# Deal cards to stacks
	dealDeckStack(team_a_deck, A_DeckStack, "A")
	dealDeckStack(team_b_deck, B_DeckStack, "B")

func dealDeckStack(deck : Deck, stack : DeckStack, teamStr : String):
	for i in range(52):  # Deal 15 cards per stack (for example)
			var card_data = deck.draw_card()
			if card_data:
				var card_node = card_scene.instantiate()
				add_child(card_node)
				#!!!! init or ready it, research
				#!!!! then stack function and it holds info about itself
				
				card_node.set_team(teamStr)
				card_node.set_card(card_data.suit, card_data.rank)
				stack.add_card(card_node)
				#card_node.change_state(card_node.CardState.ON_STACK)
				#card_node.mount_target = stack
				
				#print ("AAAAAAAAAAAAAA: ", (stack.global_position.y - deck_pos.y))
				## Space cards vertically based on how many are already stacked
				#var vertical_spacing = 0.015  # spacing per card
				#var card_index = stack.get_card_count()  # <-- you'll need to add get_card_count() in DeckStack
				#card_node.mount_offset = Transform3D(Basis(), Vector3(0, vertical_spacing * card_index - (stack.global_position.y - deck_pos.y), 0))
				##card_node.global_position = deck_pos + Vector3(0, vertical_spacing * card_index, 0)
				
				#stack.add_card(card_node)
