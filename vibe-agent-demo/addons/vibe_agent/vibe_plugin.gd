@tool
extends EditorPlugin

const BACKEND_URL := "http://127.0.0.1:8000/vibe"
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]


class FilesystemCreateContextMenuPlugin:
	extends EditorContextMenuPlugin

	var owner

	func _init(p_owner):
		owner = p_owner

	func _popup_menu(_paths: PackedStringArray):
		add_context_menu_item("Vibe: Generate Asset", Callable(owner, "_on_generate_context"))


class FilesystemAssetContextMenuPlugin:
	extends EditorContextMenuPlugin

	var owner

	func _init(p_owner):
		owner = p_owner

	func _popup_menu(paths: PackedStringArray):
		if paths.size() == 1 and owner._is_supported_image_path(paths[0]):
			add_context_menu_item("Vibe: Modify Asset", Callable(owner, "_on_modify_context"))


class SceneTreeContextMenuPlugin:
	extends EditorContextMenuPlugin

	var owner

	func _init(p_owner):
		owner = p_owner

	func _popup_menu(paths: PackedStringArray):
		if not paths.is_empty():
			add_context_menu_item("Vibe: Automation", Callable(owner, "_on_automation_context"))


var http_request: HTTPRequest
var prompt_dialog: ConfirmationDialog
var prompt_summary_label: Label
var prompt_example_label: Label
var prompt_input: TextEdit

var filesystem_create_menu
var filesystem_asset_menu
var scene_tree_menu

var active_dialog_kind := ""
var active_dialog_context := {}
var pending_request_kind := ""
var pending_request_context := {}


func _enter_tree():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

	_create_prompt_dialog()

	filesystem_create_menu = FilesystemCreateContextMenuPlugin.new(self)
	filesystem_asset_menu = FilesystemAssetContextMenuPlugin.new(self)
	scene_tree_menu = SceneTreeContextMenuPlugin.new(self)

	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE, filesystem_create_menu)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, filesystem_asset_menu)
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_SCENE_TREE, scene_tree_menu)


func _exit_tree():
	if filesystem_create_menu:
		remove_context_menu_plugin(filesystem_create_menu)
	if filesystem_asset_menu:
		remove_context_menu_plugin(filesystem_asset_menu)
	if scene_tree_menu:
		remove_context_menu_plugin(scene_tree_menu)

	if prompt_dialog:
		prompt_dialog.queue_free()
	if http_request:
		http_request.queue_free()


func _create_prompt_dialog():
	prompt_dialog = ConfirmationDialog.new()
	prompt_dialog.title = "Vibe"
	prompt_dialog.min_size = Vector2(560, 320)
	prompt_dialog.get_ok_button().text = "Run"
	prompt_dialog.confirmed.connect(_on_prompt_confirmed)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(520, 260)
	prompt_dialog.add_child(root)

	prompt_summary_label = Label.new()
	prompt_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(prompt_summary_label)

	prompt_example_label = Label.new()
	prompt_example_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(prompt_example_label)

	prompt_input = TextEdit.new()
	prompt_input.custom_minimum_size = Vector2(520, 180)
	prompt_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_input.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(prompt_input)

	get_editor_interface().get_base_control().add_child(prompt_dialog)


func _is_supported_image_path(path: String) -> bool:
	return path.get_extension().to_lower() in IMAGE_EXTENSIONS


func _current_folder_path() -> String:
	var current_path := get_editor_interface().get_current_path()
	if current_path.is_empty():
		return "res://"
	if _is_supported_image_path(current_path):
		return current_path.get_base_dir()
	return current_path


func _selected_folder_from_context(selection: Array) -> String:
	if not selection.is_empty():
		var first = selection[0]
		if first is Array and not first.is_empty():
			return str(first[0])
		if first is PackedStringArray and not first.is_empty():
			return str(first[0])
		return str(first)
	return _current_folder_path()


func _selected_asset_from_context(selection: Array) -> String:
	if selection.is_empty():
		return ""
	var first = selection[0]
	if first is Array and not first.is_empty():
		return str(first[0])
	if first is PackedStringArray and not first.is_empty():
		return str(first[0])
	return str(first)


func _scene_relative_path(node: Node) -> String:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return ""
	if node == scene_root:
		return "."
	return str(scene_root.get_path_to(node))


func _serialize_selected_nodes(nodes: Array) -> Array:
	var serialized: Array = []
	for item in nodes:
		if item is Node:
			var node: Node = item
			var child_names: Array = []
			for child in node.get_children():
				if child is Node:
					child_names.append(String(child.name))

			serialized.append(
				{
					"scene_path": _scene_relative_path(node),
					"name": String(node.name),
					"type": node.get_class(),
					"child_count": node.get_child_count(),
					"child_names": child_names,
				}
			)
	return serialized


func _normalize_context_items(selection) -> Array:
	if selection is Array:
		return selection
	if selection == null:
		return []
	return [selection]


func _open_prompt_dialog(kind: String, summary: String, example: String, confirm_text: String, context: Dictionary):
	active_dialog_kind = kind
	active_dialog_context = context

	prompt_dialog.title = "Vibe: " + confirm_text
	prompt_dialog.get_ok_button().text = confirm_text
	prompt_summary_label.text = summary
	prompt_example_label.text = example
	prompt_input.clear()
	prompt_dialog.popup_centered(Vector2i(560, 320))
	prompt_input.grab_focus()


func _on_generate_context(selection):
	var items := _normalize_context_items(selection)
	var folder_path := _selected_folder_from_context(items)
	_open_prompt_dialog(
		"generate",
		"Generate a new asset in %s" % folder_path,
		"Example: I want a 32x32 pixel style pickaxe icon",
		"Generate",
		{"folder_path": folder_path},
	)


func _on_modify_context(selection):
	var items := _normalize_context_items(selection)
	var asset_path := _selected_asset_from_context(items)
	if asset_path.is_empty():
		return

	_open_prompt_dialog(
		"modify",
		"Modify image asset %s" % asset_path,
		"Example: Resize the image into 16:9",
		"Modify",
		{"asset_path": asset_path},
	)


func _on_automation_context(selection):
	var items := _normalize_context_items(selection)
	var selected_nodes := _serialize_selected_nodes(items)
	if selected_nodes.is_empty():
		return

	_open_prompt_dialog(
		"automate",
		"Automate the selected scene tree node(s)",
		'Example: Rename all children start from 0 with "child_%d" format',
		"Automate",
		{"selected_nodes": selected_nodes},
	)


func _on_prompt_confirmed():
	var prompt := prompt_input.text.strip_edges()
	if prompt.is_empty():
		print("Vibe prompt cannot be empty")
		return

	match active_dialog_kind:
		"generate":
			_send_request(
				"generate",
				{
					"prompt": prompt,
					"folder_path": String(active_dialog_context.get("folder_path", "res://")),
				}
			)
		"modify":
			_send_request(
				"modify",
				{
					"prompt": prompt,
					"asset_path": String(active_dialog_context.get("asset_path", "")),
				}
			)
		"automate":
			_send_request(
				"automate",
				{
					"prompt": prompt,
					"selected_nodes": active_dialog_context.get("selected_nodes", []),
				}
			)


func _send_request(request_kind: String, payload: Dictionary):
	if http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		print("Vibe request already in flight")
		return

	pending_request_kind = request_kind
	pending_request_context = payload

	var error := http_request.request(
		BACKEND_URL + "/" + request_kind,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		print("Failed to send Vibe request: ", error)
		pending_request_kind = ""
		pending_request_context = {}
		return

	print("Vibe request sent: ", request_kind)


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	pending_request_kind = ""
	pending_request_context = {}

	if result != HTTPRequest.RESULT_SUCCESS:
		print("HTTP request failed: ", result)
		return

	var body_text := body.get_string_from_utf8()
	var payload = JSON.parse_string(body_text)
	if payload == null or typeof(payload) != TYPE_DICTIONARY:
		print("Failed to parse backend JSON: ", body_text)
		return

	if response_code >= 400:
		print("Backend returned HTTP error: ", response_code, " body: ", payload)

	var status := String(payload.get("status", ""))
	if status != "success":
		print("Backend processing failed: ", payload.get("message", "unknown error"))
		return

	var msg_type := String(payload.get("type", ""))
	if msg_type == "asset":
		_handle_asset_response(payload)
	elif msg_type == "automation":
		_handle_automation_response(payload)
	else:
		print("Unknown backend response: ", payload)


func _handle_asset_response(payload: Dictionary):
	var file_path := String(payload.get("file_path", ""))
	print("Asset ready: ", file_path)
	get_editor_interface().get_resource_filesystem().scan()
	if not file_path.is_empty():
		get_editor_interface().select_file(file_path)


func _handle_automation_response(payload: Dictionary):
	var action = payload.get("action", {})
	if typeof(action) != TYPE_DICTIONARY:
		print("Automation response missing action payload")
		return

	_apply_automation_action(action)


func _resolve_scene_node(scene_path: String):
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return null
	if scene_path.is_empty() or scene_path == ".":
		return scene_root
	return scene_root.get_node_or_null(NodePath(scene_path))


func _apply_automation_action(action: Dictionary):
	var action_type := String(action.get("action", ""))
	if action_type != "rename_children":
		print("Unsupported automation action: ", action_type)
		return

	var target_path := String(action.get("target_node_path", "."))
	var target_node = _resolve_scene_node(target_path)
	if target_node == null:
		print("Automation target node not found: ", target_path)
		return

	var pattern := String(action.get("pattern", "child_%d"))
	if not pattern.contains("%d"):
		print("Automation pattern must contain %d")
		return

	var start_index := int(action.get("start_index", 0))
	var child_count := target_node.get_child_count()
	if child_count == 0:
		print("Target node has no children to rename")
		return

	var undo_redo = get_undo_redo()
	undo_redo.create_action("Vibe Rename Children")
	for index in range(child_count):
		var child := target_node.get_child(index)
		if not (child is Node):
			continue
		var new_name := pattern % (start_index + index)
		undo_redo.add_do_property(child, "name", new_name)
		undo_redo.add_undo_property(child, "name", String(child.name))
	undo_redo.commit_action()

	print("Automation applied: renamed ", child_count, " children on ", target_node.name)
