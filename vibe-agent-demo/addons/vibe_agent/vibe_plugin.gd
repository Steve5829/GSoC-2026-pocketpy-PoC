@tool
extends EditorPlugin

var http_request : HTTPRequest

func _enter_tree():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	

	add_tool_menu_item("Vibe: Generate Asset", _on_generate_asset)
	add_tool_menu_item("Vibe: Editor Automation", _on_automate_editor)

func _exit_tree():
	remove_tool_menu_item("Vibe: Generate Asset")
	remove_tool_menu_item("Vibe: Editor Automation")
	if http_request:
		http_request.queue_free()

func _on_generate_asset():

	_send_request("generate", "pixel_art_axe")

func _on_automate_editor():
	_send_request("automate", "Rename all children starting from 0")

func _send_request(request_type: String, content: String):
	var query_key = "prompt" if request_type == "generate" else "command"
	var url = "http://127.0.0.1:8000/vibe/%s?%s=%s" % [request_type, query_key, content.uri_encode()]
	var error = http_request.request(url, [], HTTPClient.METHOD_POST)
	if error != OK:
		print("request sent failed: ", error)
		return

	print("request sent: ", request_type)

func _on_request_completed(result, response_code, _headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		print("HTTP request failed: ", result)
		return

	if response_code >= 400:
		print("backed returned HTTP failed: ", response_code)

	var body_str = body.get_string_from_utf8()
	var json = JSON.parse_string(body_str)
	
	if json == null or typeof(json) != TYPE_DICTIONARY:
		print("decrypting json failed: ", body_str)
		return

	var status = json.get("status", "")
	if status != "success":
		print("backend processing failed: ", json.get("message", "unknown error"))
		return

	var msg_type = json.get("type", "")
	
	if msg_type == "asset":
		var file_name = json.get("file", "unknown.png")
		print("resource generated successfully: ", file_name)
		get_editor_interface().get_resource_filesystem().scan()
	
	elif msg_type == "automation":
		var code = json.get("code", "")
		print("automate instruction received, showing code: \n", code)
	
	else:
		print("unknown response: ", json)
