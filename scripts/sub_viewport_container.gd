extends SubViewportContainer

func _notification(what):
	if what == NOTIFICATION_RESIZED:
		$SubViewport.size = size
