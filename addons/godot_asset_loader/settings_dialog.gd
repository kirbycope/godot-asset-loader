# settings_dialog.gd
@tool
extends Window

signal settings_saved(json_url)

var json_url_input
var default_json_url = "https://raw.githubusercontent.com/kirbycope/godot-asset-library/refs/heads/main/resources.json"

func _ready():
	# Get UI elements
	json_url_input = $VBoxContainer/JSONURLContainer/JSONURLInput
	
	# Connect button signals
	$VBoxContainer/ButtonContainer/SaveButton.connect("pressed", Callable(self, "_on_save_pressed"))
	$VBoxContainer/ButtonContainer/CancelButton.connect("pressed", Callable(self, "_on_cancel_pressed"))
	
	# Connect close requested signal
	close_requested.connect(Callable(self, "_on_close_requested"))
	
	# Set window position to center of the screen
	# Using a different approach to center the window
	var screen_size = DisplayServer.window_get_size()
	position = (screen_size - size) / 2

# Set the initial values for the dialog fields
func initialize(current_url):
	if current_url.is_empty():
		json_url_input.text = default_json_url
	else:
		json_url_input.text = current_url

# Handler for Save button pressed
func _on_save_pressed():
	var url = json_url_input.text.strip_edges()
	# Basic validation
	if url.is_empty():
		url = default_json_url
		
	emit_signal("settings_saved", url)
	hide()

# Handler for Cancel button pressed
func _on_cancel_pressed():
	hide()

# Handler for window close requested
func _on_close_requested():
	hide()
