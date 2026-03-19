@tool
extends EditorPlugin

var http_request : HTTPRequest

func _enter_tree():

	http_request = HTTPRequest.new()
	add_child(http_request)
	
	http_request.request_completed.connect(_on_request_completed)
	
	add_tool_menu_item("Vibe: Generate Asset", _on_generate_pressed)

func _exit_tree():
	remove_tool_menu_item("Vibe: Generate Asset")
	if http_request:
		http_request.queue_free()

func _on_generate_pressed():
	print("sending request to backend...")

	var url = "http://127.0.0.1:8000/vibe/generate?prompt=pixel_art_axe"
	var error = http_request.request(url, [], HTTPClient.METHOD_POST)
	
	if error != OK:
		print("failed to send request, error info: ", error)


func _on_request_completed(result, response_code, headers, body):
	var json = JSON.parse_string(body.get_string_from_utf8())
	print("from backend: ", json)
