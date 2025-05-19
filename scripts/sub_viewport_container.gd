extends SubViewportContainer

func _notification(what):
	print("view not: ", what)
	if what == NOTIFICATION_RESIZED:
		$SubViewport.size = size
