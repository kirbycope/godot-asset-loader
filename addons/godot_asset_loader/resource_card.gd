# resource_card.gd
@tool
extends Panel

signal card_selected(card)

var resource_data = null
var is_selected = false
var http_request

func _ready():
	self.gui_input.connect(Callable(self, "_on_gui_input"))
	
	# Create HTTP request for loading preview images
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", Callable(self, "_on_preview_image_loaded"))

func setup(data):
	resource_data = data
	
	# Safely access nodes
	var title_label = get_node_or_null("VBoxContainer/HBoxContainer/InfoContainer/Title")
	var type_label = get_node_or_null("VBoxContainer/HBoxContainer/InfoContainer/Type")
	var author_license_label = get_node_or_null("VBoxContainer/HBoxContainer/InfoContainer/AuthorLicense")
	var description_label = get_node_or_null("VBoxContainer/Description")
	
	# Set title
	if title_label:
		title_label.text = data.name if data.has("name") else "Unknown Title"
	
	# Set type
	if type_label:
		type_label.text = data.type if data.has("type") else "Unknown Type"
	
	# Handle author and license information
	if author_license_label:
		# Make sure we use has() to check for keys before accessing them
		var author = "Unknown"
		var license = "Unknown"
		
		if data.has("author"):
			author = data.author
		
		if data.has("license"):
			license = data.license
			
		author_license_label.text = author + " - " + license
		author_license_label.visible = true
	
	# Show description if available
	if description_label:
		if data.has("description") and data.description:
			var desc = data.description
			if desc.length() > 120:
				desc = desc.substr(0, 120) + "..."
			description_label.text = desc
			description_label.visible = true
		else:
			description_label.visible = false
	
	# Load preview image if available
	if data.has("preview") and data.preview:
		# Start by setting a placeholder color
		var preview_panel = get_node_or_null("VBoxContainer/HBoxContainer/PreviewPanel")
		if preview_panel:
			if data.has("type") and data.type == "3D Model":
				preview_panel.self_modulate = Color(0.2, 0.6, 1.0)  # Blue for 3D models
			else:
				preview_panel.self_modulate = Color(0.5, 0.8, 0.5)  # Green for others
		
		# Request the preview image
		load_preview_image(data.preview)

func load_preview_image(preview_url):
	# Start the HTTP request to get the image
	var headers = []

	# Check if this is a GitHub URL
	if preview_url.begins_with("https://github.com") or preview_url.begins_with("https://raw.githubusercontent.com"):
		# Get access token from plugin (parent nodes)
		var plugin = null
		var parent = get_parent()
		while parent and not plugin:
			if parent.has_method("get_plugin_reference"):
				plugin = parent.get_plugin_reference()
			parent = parent.get_parent()
		
		# Add authorization header if we found a plugin and it has an access token
		if plugin and not plugin.access_token.is_empty():
			headers.append("Authorization: token " + plugin.access_token)

	# Start the HTTP request
	var error = http_request.request(preview_url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		printerr("An error occurred in the HTTP request for preview image.")

func _on_preview_image_loaded(result, response_code, headers, body):
	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("Error downloading preview image: ", result)
		return
	
	if response_code != 200:
		printerr("HTTP Error: " + str(response_code) + " when loading preview image")
		return
	
	# Create an image from the downloaded data
	var image = Image.new()
	var error = OK
	
	# Determine image format by checking the file extension in URL or MIME type
	var image_format = ""
	for header in headers:
		if header.to_lower().begins_with("content-type:"):
			var content_type = header.substr("content-type:".length()).strip_edges().to_lower()
			if content_type == "image/jpeg" or content_type == "image/jpg":
				image_format = "jpg"
			elif content_type == "image/png":
				image_format = "png"
			break
	
	# If we couldn't determine from headers, try the URL
	if image_format.is_empty() and resource_data.has("preview"):
		var url = resource_data.preview.to_lower()
		if url.ends_with(".jpg") or url.ends_with(".jpeg"):
			image_format = "jpg"
		elif url.ends_with(".png"):
			image_format = "png"
	
	# Try to load the image based on format
	if image_format == "jpg":
		error = image.load_jpg_from_buffer(body)
	elif image_format == "png":
		error = image.load_png_from_buffer(body)
	else:
		# If we can't determine format, try both
		error = image.load_png_from_buffer(body)
		if error != OK:
			error = image.load_jpg_from_buffer(body)
	
	if error != OK:
		printerr("Failed to load image from buffer")
		return
	
	# Convert Image to ImageTexture
	var texture = ImageTexture.create_from_image(image)
	
	# Set the texture to the preview TextureRect
	var preview_rect = get_node_or_null("VBoxContainer/HBoxContainer/PreviewPanel/Preview")
	if preview_rect:
		preview_rect.texture = texture
		
		# Reset panel modulation since we now have an actual image
		var preview_panel = get_node_or_null("VBoxContainer/HBoxContainer/PreviewPanel")
		if preview_panel:
			preview_panel.self_modulate = Color(1, 1, 1)  # Reset to white

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		select()

func select():
	is_selected = true
	# Set selected styling
	self_modulate = Color(0.7, 0.8, 1.0)  # Light blue tint
	emit_signal("card_selected", self)

func deselect():
	is_selected = false
	self_modulate = Color(1, 1, 1)  # Reset to normal

# Method to adapt the card to the grid size
func set_card_width(width):
	# Update the card minimum size
	custom_minimum_size.x = width
	
	# Adjust the preview panel proportionally
	var preview_panel = get_node_or_null("VBoxContainer/HBoxContainer/PreviewPanel")
	if preview_panel:
		# Determine appropriate preview size (keeping it square)
		var preview_size = min(100, width * 0.25)  # 25% of width but not more than 100px
		preview_panel.custom_minimum_size = Vector2(preview_size, preview_size)
	
	# Make sure all text elements handle sizing properly
	var info_container = get_node_or_null("VBoxContainer/HBoxContainer/InfoContainer")
	if info_container:
		info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var title_label = get_node_or_null("VBoxContainer/HBoxContainer/InfoContainer/Title")
	if title_label:
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	var description_label = get_node_or_null("VBoxContainer/Description")
	if description_label:
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Request redraw
	queue_redraw()
