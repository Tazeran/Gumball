#info for extending commands
#https://docs.godotengine.org/en/stable/classes/class_editorcommandpalette.html

@tool
extends EditorPlugin

var dock: Control

func _enter_tree() -> void:
	# Optional: Add a dock panel (uncomment if you're using one)
	# dock = preload("res://addons/AIHelperPlugin/plugin_dock.tscn").instantiate()
	# add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, dock)
	# dock.get_node("VBoxContainer/Button").pressed.connect(_on_button_pressed)

	# Add to the top menu
	#add_tool_menu_item("Run My Command", _on_run_command)
	
	# Register with the EditorCommandPalette
	var palette = get_editor_interface().get_command_palette()
	if palette:
		palette.add_command(
			"Export Dump all Scripts",                             # Name of the command (shown in palette)
			"exportdumpscripts",
			Callable(self, "_dump_all_gd_scripts_to_file"),       # Binded Callable (target + method)
		)

func _exit_tree() -> void:
	#remove_tool_menu_item("Run My Command")
	var palette := get_editor_interface().get_command_palette()
	if palette:
		palette.remove_command("exportdumpscripts")

func _on_button_pressed() -> void:
	print("Button clicked! You can do anything here.")

func _on_run_command() -> void:
	print("This command runs from the menu or command palette!")
	_dump_all_gd_scripts_to_file()



var _gdscript_dump_output := ""

func _dump_all_gd_scripts_to_file(output_path: String = "res://gdscript_dump.txt") -> void:
	_gdscript_dump_output = ""
	process_dir("res://")

	var save_file := FileAccess.open(output_path, FileAccess.WRITE)
	if save_file:
		save_file.store_string(_gdscript_dump_output)
		print("Saved script dump to: %s" % output_path)
		#EditorInterface.get_resource_filesystem().navigate_to_path(output_path)
		OS.shell_open(ProjectSettings.globalize_path(output_path))
	else:
		printerr("Failed to save to %s" % output_path)


func process_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		printerr("Could not open directory: %s" % path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				process_dir(path.path_join(file_name))
		else:
			if file_name.ends_with(".gd"):
				var full_path := path.path_join(file_name)
				var script := FileAccess.open(full_path, FileAccess.READ)
				if script:
					var content := script.get_as_text()
					_gdscript_dump_output += "\n### FILE: %s ###\n" % full_path
					_gdscript_dump_output += content + "\n"
				else:
					printerr("Failed to read file: %s" % full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
