# CardData.gd
class_name CardData

var suit: String
var rank: String

func _init(_suit: String = "", _rank: String = ""):
	suit = _suit
	rank = _rank
