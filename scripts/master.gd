extends Node

enum LaunchMode { DEV_DIRECT, MAIN_MENU }

var launch_mode := LaunchMode.MAIN_MENU
var dev_scene_path := "res://scenes/main.tscn"
var landing_scene_path := "res://scenes/Menu/landing.tscn"
var priscilla1 := "res://scenes/arena1.tscn"
var player_count := 1
