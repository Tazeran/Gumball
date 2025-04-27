#info for extending commands
#https://docs.godotengine.org/en/stable/classes/class_editorcommandpalette.html

@tool
extends EditorPlugin

var dock: Control

func _enter_tree() -> void:
	_create_dialog()
	# Register with the EditorCommandPalette
	var palette = get_editor_interface().get_command_palette()
	if palette:
		palette.add_command(
			"Export Dump all Scripts",                             # Name of the command (shown in palette)
			"exportdumpscripts",
			Callable(self, "_dump_all_gd_scripts_to_file"),       # Binded Callable (target + method)
		)
		palette.add_command(
			"Arrange Selected Nodes in Grid",
			"arrangeselectednodesgrid",
			Callable(self, "_show_arrange_dialog"),
		)

func _exit_tree() -> void:
	if dialog:
		dialog.queue_free()
		dialog = null
	var palette := get_editor_interface().get_command_palette()
	if palette:
		palette.remove_command("exportdumpscripts")
		palette.remove_command("arrangeselectednodesgrid")

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


var dialog: AcceptDialog
var spacing_x_field: SpinBox
var spacing_y_field: SpinBox
var columns_field: SpinBox

func _create_dialog() -> void:
	dialog = AcceptDialog.new()
	dialog.dialog_text = "Grid Settings"
	dialog.ok_button_text = "Apply"

	var vbox = VBoxContainer.new()

	var spacing_x_label = Label.new()
	spacing_x_label.text = "Spacing X:"
	vbox.add_child(spacing_x_label)

	spacing_x_field = SpinBox.new()
	spacing_x_field.min_value = 0.1
	spacing_x_field.value = 2.0
	spacing_x_field.step = 0.1
	vbox.add_child(spacing_x_field)

	var spacing_y_label = Label.new()
	spacing_y_label.text = "Spacing Y (Z axis spacing!):"
	vbox.add_child(spacing_y_label)

	spacing_y_field = SpinBox.new()
	spacing_y_field.min_value = 0.1
	spacing_y_field.value = 2.0
	spacing_y_field.step = 0.1
	vbox.add_child(spacing_y_field)

	var columns_label = Label.new()
	columns_label.text = "Columns:"
	vbox.add_child(columns_label)

	columns_field = SpinBox.new()
	columns_field.min_value = 1
	columns_field.value = 5
	vbox.add_child(columns_field)

	dialog.add_child(vbox)
	dialog.confirmed.connect(_on_dialog_ok_pressed) # <-- use confirmed signal
	get_editor_interface().get_base_control().add_child(dialog)




func _show_arrange_dialog() -> void:
	dialog.popup_centered(Vector2(300, 200))

func _on_dialog_ok_pressed() -> void:
	_arrange_selected_nodes_grid(
		spacing_x_field.value,
		spacing_y_field.value,
		columns_field.value
	)
	dialog.hide()

func _arrange_selected_nodes_grid(spacing_x: float, spacing_y: float, columns: int) -> void:
	var selection = get_editor_interface().get_selection()
	var selected_nodes = selection.get_selected_nodes()

	if selected_nodes.is_empty():
		push_warning("No nodes selected to arrange.")
		return

	selected_nodes.sort_custom(func(a, b): return a.name.naturalnocasecmp_to(b.name) < 0)

	for i in range(selected_nodes.size()):
		var node = selected_nodes[i]
		if node is Node3D:
			var x = (i % columns) * spacing_x
			var z = (i / columns) * spacing_y
			var position = Vector3(x, node.transform.origin.y, z) # Keep original Y
			node.transform.origin = position
		else:
			push_warning("Node '%s' is not a Node3D, skipped." % node.name)
