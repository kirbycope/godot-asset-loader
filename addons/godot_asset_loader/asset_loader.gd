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


## Called when the node enters the `SceneTree` (e.g. upon instantiating, scene changing, or after calling add_child in a script).
func _enter_tree():

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
	
	# Load resources from JSON
	load_resources()


## Called when the node is about to leave the `SceneTree` (e.g. upon freeing, scene changing, or after calling remove_child in a script).
func _exit_tree():

	# Removes the control from the bottom panel
	remove_control_from_bottom_panel(resource_downloader_screen)

	# You have to manually Node.queue_free the control
	resource_downloader_screen.free()

	# Free the HTTP request node
	http_request.free()


## Load the resources from the JSON file.
func load_resources():

	# Check if the resources JSON file exists
	if FileAccess.file_exists("res://addons/godot_asset_loader/resources.json"):

		# Read the JSON file with resource listings
		var file = FileAccess.open("res://addons/godot_asset_loader/resources.json", FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()

		# Parse the JSON file
		var json = JSON.new()
		var parse_result = json.parse(json_string)

		# Check if the JSON file was parsed successfully
		if parse_result == OK:

			# Get the list of resources
			resource_list = json.get_data()

			# Populate the resource list in the UI
			resource_downloader_screen.populate_resource_list(resource_list)


## Download the selected resource.
func download_resource(resource_data):

	# Set the download URL
	var url = resource_data.url

	# Get the file name including the extension
	var file_name = url.get_file()

	# Start the download
	var headers = []
	var error = http_request.request(url, headers, HTTPClient.METHOD_GET)

	# Check for errors
	if error != OK:
		printerr("An error occurred in the HTTP request.")
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
		print("Resource downloaded successfully: ", save_path)
		
		# If this is a ZIP file, extract it
		if file_name.ends_with(".zip"):
			extract_zip(save_path, file_name)
		
		# If resource needs importing, trigger import
		elif ResourceLoader.exists(save_path):
			var resource = ResourceLoader.load(save_path)
			if resource:
				print("Resource loaded: ", resource)
	else:
		printerr("Failed to open file for writing: ", save_path)

	# Clear the current download info
	current_download_file = ""
	current_resource_data = null


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
		print("ZIP extracted successfully to: ", target_godot_dir)
		
		# Delete the ZIP file after successful extraction
		var delete_success = delete_file(zip_path)
		if delete_success:
			print("ZIP file deleted: ", zip_path)
		else:
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
