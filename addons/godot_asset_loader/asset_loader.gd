# asset_loader.gd
@tool
extends EditorPlugin

var resource_downloader_screen
var http_request
var resource_list = []
var download_path = "res://"

# Store the current resource data separately
var current_download_file = ""
var current_resource_data = null

# Settings
var settings_file_path = "user://asset_loader_settings.cfg"
var json_url = "https://raw.githubusercontent.com/kirbycope/godot-asset-library/refs/heads/main/resources.json"
var access_token = ""  # GitHub personal access token for private repos


## Called when the node enters the `SceneTree` (e.g. upon instantiating, scene changing, or after calling add_child in a script).
func _enter_tree():

	# Load settings
	load_settings()

	# Create the main editor screen
	resource_downloader_screen = load("res://addons/godot_asset_loader/resource_downloader_screen.tscn").instantiate()

	# Store a reference back to this plugin
	resource_downloader_screen.set_plugin_reference(self)

	# Add the screen as a main screen tab
	add_control_to_bottom_panel(resource_downloader_screen, "Resources")
	
	# Create HTTP request node
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_request_completed"))
	
	# Load resources from online JSON
	load_resources()


## Called when the node is about to leave the `SceneTree` (e.g. upon freeing, scene changing, or after calling remove_child in a script).
func _exit_tree():

	# Removes the control from the bottom panel
	remove_control_from_bottom_panel(resource_downloader_screen)

	# Check if the settings dialog exists and free it
	var settings_dialog = resource_downloader_screen.get_node_or_null("SettingsDialog")
	if settings_dialog:
		settings_dialog.queue_free()

	# You have to manually Node.queue_free the control
	resource_downloader_screen.free()

	# Free the HTTP request node
	http_request.free()


## Load settings from config file
func load_settings():
	if FileAccess.file_exists(settings_file_path):
		var config = ConfigFile.new()
		var err = config.load(settings_file_path)
		if err == OK:
			# Load JSON URL if it exists in the config
			if config.has_section_key("settings", "json_url"):
				json_url = config.get_value("settings", "json_url")
			# Load access token if it exists
			if config.has_section_key("settings", "access_token"):
				access_token = config.get_value("settings", "access_token")
		else:
			printerr("Error loading settings file: ", err)

## Save settings to config file
func save_settings(new_json_url, new_access_token=""):
	var config = ConfigFile.new()
	
	# Set the JSON URL in the config
	config.set_value("settings", "json_url", new_json_url)
	
	# Set the access token if provided
	config.set_value("settings", "access_token", new_access_token)
	
	# Save the config
	var err = config.save(settings_file_path)
	if err != OK:
		printerr("Error saving settings file: ", err)
	else:
		# Update the current values
		json_url = new_json_url
		access_token = new_access_token

## Load the resources from the remote JSON file.
func load_resources():
	# Create a separate HTTP request for loading resources
	var resources_http_request = HTTPRequest.new()
	add_child(resources_http_request)
	resources_http_request.connect("request_completed", _on_resources_loaded)
	
	# Prepare headers for authentication if token is provided
	var headers = []
	if not access_token.is_empty() and json_url.begins_with("https://"):
		headers.append("Authorization: token " + access_token)
	
	# Start the HTTP request
	var error = resources_http_request.request(json_url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		printerr("An error occurred when trying to fetch the resources.json file: ", error)

## Download the selected resource.
func download_resource(resource_data):
	# Set the download URL
	var url = resource_data.url

	# Get the file name including the extension
	var file_name = url.get_file()

	# Prepare headers for authentication if token is provided
	var headers = []
	if not access_token.is_empty() and (url.begins_with("https://github.com") or url.begins_with("https://raw.githubusercontent.com")):
		headers.append("Authorization: token " + access_token)

	# Start the download
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)

	# Check for errors
	if error != OK:
		printerr("An error occurred in the HTTP request. Error code: " + str(error))
		return

	# Store the resource info for when download completes
	current_download_file = file_name
	current_resource_data = resource_data

## Called when the HTTP request is completed.
func _on_request_completed(result, response_code, headers, body):

	# Check if the request was not successful
	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("Error downloading resource: ", result)
		return

	# Get the downloaded file name and resource data
	var file_name = current_download_file
	var resource_data = current_resource_data

	# Save the downloaded file
	var save_path = download_path + file_name

	# Open the file for writing
	var file = FileAccess.open(save_path, FileAccess.WRITE)

	# Check if the file was opened successfully
	if file:
		# Write the downloaded data to the file
		file.store_buffer(body)
		file.close()
		
		# If this is a ZIP file, extract it
		if file_name.ends_with(".zip"):
			extract_zip(save_path, file_name)
		
		# If resource needs importing, trigger import
		elif ResourceLoader.exists(save_path):
			var resource = ResourceLoader.load(save_path)
	else:
		printerr("Failed to open file for writing: ", save_path)

	# Clear the current download info
	current_download_file = ""
	current_resource_data = null

## Called when the resources JSON file has been loaded.
func _on_resources_loaded(result, response_code, headers, body):
	# Check if the request was successful
	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("Error loading resources JSON: ", result)
		return
	
	# Check if the response code is valid
	if response_code != 200:
		printerr("Invalid HTTP response code: ", response_code)
		return
	
	# Check if the body is valid
	if body.size() == 0:
		printerr("Empty response body received")
		return

	# Parse the JSON content
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result == OK:
		# Get the list of resources
		resource_list = json.get_data()
		
		# Check if the resource list is valid
		if resource_list.size() == 0:
			printerr("Resource list is empty")
		
		# Populate the resource list in the UI
		resource_downloader_screen.populate_resource_list(resource_list)
	else:
		printerr("Error parsing JSON: ", parse_result, " at line ", json.get_error_line())
		printerr("Error string: ", json.get_error_message())
		
		# Print part of the raw JSON to help debug
		var json_string = body.get_string_from_utf8()
		if json_string.length() > 0:
			printerr("First 100 characters of JSON: ", json_string.substr(0, 100))
	
	# Clean up the HTTP request node - fix the potential null reference
	var request_node = get_node_or_null("HTTPRequest")
	if request_node:
		request_node.queue_free()

## Extract a ZIP file to the assets directory.
func extract_zip(zip_path, zip_filename):

	# Get the asset name without the .zip extension
	var asset_name = zip_filename.get_basename()

	# Define the target Godot directory
	var target_godot_dir = "res://assets/" + asset_name

	# Convert Godot paths to OS file paths
	var project_dir = ProjectSettings.globalize_path("res://")
	var zip_os_path = ProjectSettings.globalize_path(zip_path)
	var target_os_dir = ProjectSettings.globalize_path(target_godot_dir)

	# Use OS command to unzip
	var output = []
	var exit_code = 0

	# Get the operating system
	var os_name = OS.get_name()

	if os_name == "Windows":
		# Windows command
		# Make sure target directory exists first
		var dir_command = "New-Item -Path \"" + target_os_dir + "\" -ItemType Directory -Force"
		# Then extract the zip
		var extract_command = "Expand-Archive -Path \"" + zip_os_path + "\" -DestinationPath \"" + target_os_dir + "\" -Force"
		# Combine the commands
		exit_code = OS.execute("powershell", ["-command", dir_command + "; " + extract_command], output, true)
	elif os_name == "macOS" or os_name == "Linux":
		# macOS/Linux command (mkdir -p will create parent directories if needed)
		exit_code = OS.execute("bash", ["-c", "mkdir -p \"" + target_os_dir + "\" && unzip -o \"" + zip_os_path + "\" -d \"" + target_os_dir + "\""], output, true)

	if exit_code != 0:
		printerr("Failed to extract ZIP file: ", zip_path)
		for line in output:
			printerr(line)
	else:		
		# Delete the ZIP file after successful extraction
		var delete_success = delete_file(zip_path)
		if !delete_success:
			printerr("Failed to delete ZIP file: ", zip_path)

		# Refresh the FileSystem dock to show the new files and removed ZIP
		EditorInterface.get_resource_filesystem().scan()


## Delete a file.
func delete_file(file_path):
	if FileAccess.file_exists(file_path):
		var dir = DirAccess.open("res://")
		var error = dir.remove(file_path)
		return error == OK
	return false
