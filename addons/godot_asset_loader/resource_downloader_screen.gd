# resource_downloader_screen.gd
@tool
extends Control

var plugin_reference
var resources_grid
var selected_resource = null
var all_resources = []
var filtered_resources = []

# Search and filter references
var search_box
var category_filter
var type_filter
var settings_button
var settings_dialog

# Responsiveness variables
var min_card_width = 450  # Minimum width for cards
var resizing_timer = null
var last_width = 0

## Called when the node is "ready", i.e. when both the node and its children have entered the scene tree.
func _ready():
	resources_grid = $VBoxContainer/ContentContainer/ScrollContainer/ResourcesGrid
	
	# Set up button listeners
	$VBoxContainer/ButtonContainer/DownloadButton.connect("pressed", Callable(self, "_on_download_pressed"))
	$VBoxContainer/ButtonContainer/RefreshButton.connect("pressed", Callable(self, "_on_refresh_pressed"))
	
	# Set up search and filter controls
	search_box = $VBoxContainer/SearchContainer/SearchBox
	search_box.connect("text_changed", Callable(self, "_on_search_text_changed"))
	
	category_filter = $VBoxContainer/FilterContainer/CategoryFilter
	category_filter.connect("item_selected", Callable(self, "_on_filter_changed"))
	
	type_filter = $VBoxContainer/FilterContainer/TypeFilter
	type_filter.connect("item_selected", Callable(self, "_on_filter_changed"))
	
	# Setup settings button
	settings_button = $VBoxContainer/FilterContainer/SettingsButton
	settings_button.connect("pressed", Callable(self, "_on_settings_button_pressed"))
	
	# Create settings dialog
	settings_dialog = load("res://addons/godot_asset_loader/settings_dialog.tscn").instantiate()
	add_child(settings_dialog)
	settings_dialog.connect("settings_saved", Callable(self, "_on_settings_saved"))
	settings_dialog.hide()
	
	# Disable download button initially
	$VBoxContainer/ButtonContainer/DownloadButton.disabled = true
	
	# Set up responsiveness handling
	resizing_timer = Timer.new()
	add_child(resizing_timer)
	resizing_timer.wait_time = 0.2  # Small delay to avoid constant recalculation
	resizing_timer.one_shot = true
	resizing_timer.connect("timeout", Callable(self, "_on_resize_timeout"))
	
	# Connect to window resize notification
	get_tree().get_root().connect("size_changed", Callable(self, "_on_window_resized"))
	
	# Call updates on visibility change
	connect("visibility_changed", Callable(self, "_on_visibility_changed"))

## Override _process to check for container size changes
func _process(delta):
	var scroll_container = $VBoxContainer/ContentContainer/ScrollContainer
	if scroll_container and scroll_container.size.x != last_width:
		last_width = scroll_container.size.x
		_on_window_resized()

# Method to set the plugin reference
func set_plugin_reference(plugin):
	plugin_reference = plugin

# Method to get the plugin reference (used by resource cards)
func get_plugin_reference():
	return plugin_reference

# Populate the resource list from the loaded resources
func populate_resource_list(resources):
	all_resources = resources
	
	# Collect unique categories and types for filters
	var categories = {"All": true}
	var types = {"All": true}
	
	for resource in all_resources:
		if resource.has("category") and resource.category:
			categories[resource.category] = true
		if resource.has("type") and resource.type:
			types[resource.type] = true
	
	# Populate category filter dropdown
	category_filter.clear()
	category_filter.add_item("All")
	for category in categories.keys():
		if category != "All":
			category_filter.add_item(category)
	
	# Populate type filter dropdown
	type_filter.clear()
	type_filter.add_item("All")
	for type in types.keys():
		if type != "All":
			type_filter.add_item(type)
	
	# Apply current filters
	apply_filters()

# Apply all current filters and search criteria
func apply_filters():
	var search_text = search_box.text.to_lower()
	var selected_category = category_filter.get_item_text(category_filter.selected)
	var selected_type = type_filter.get_item_text(type_filter.selected)
	
	filtered_resources = []
	
	for resource in all_resources:
		var matches_search = search_text.is_empty() or (
			(resource.has("name") and resource.name.to_lower().contains(search_text)) or
			(resource.has("description") and resource.description.to_lower().contains(search_text))
		)
		
		var matches_category = selected_category == "All" or (
			resource.has("category") and resource.category == selected_category
		)
		
		var matches_type = selected_type == "All" or (
			resource.has("type") and resource.type == selected_type
		)
		
		if matches_search and matches_category and matches_type:
			filtered_resources.append(resource)
	
	display_resources()

# Display the filtered resources in the grid
func display_resources():
	# Clear existing children
	for child in resources_grid.get_children():
		child.queue_free()
	
	# Create resource cards for filtered resources
	for resource in filtered_resources:
		var resource_card = load("res://addons/godot_asset_loader/resource_card.tscn").instantiate()
		resources_grid.add_child(resource_card)
		resource_card.setup(resource)
		resource_card.connect("card_selected", Callable(self, "_on_resource_card_selected"))
	
	# Update UI based on results
	var results_label = $VBoxContainer/ContentContainer/ResultsLabel
	results_label.text = str(filtered_resources.size()) + " resources found"
	
	# Update grid columns for responsiveness
	_update_grid_columns()

# Handler for search text changes
func _on_search_text_changed(new_text):
	apply_filters()

# Handler for category or type filter changes
func _on_filter_changed(index):
	apply_filters()

# Handler for resource card selection
func _on_resource_card_selected(resource_card):
	# Deselect all cards
	for card in resources_grid.get_children():
		if card != resource_card:
			card.deselect()
	
	# Select this card if it wasn't already selected
	if selected_resource != resource_card.resource_data:
		selected_resource = resource_card.resource_data
		$VBoxContainer/ButtonContainer/DownloadButton.disabled = false
	else:
		# Toggle off if it was already selected
		resource_card.deselect()
		selected_resource = null
		$VBoxContainer/ButtonContainer/DownloadButton.disabled = true

# Handler for download button press
func _on_download_pressed():
	if selected_resource and plugin_reference:
		plugin_reference.download_resource(selected_resource)

# Handler for refresh button press
func _on_refresh_pressed():
	if plugin_reference:
		plugin_reference.load_resources()

# Handler for settings button press
func _on_settings_button_pressed():
	if plugin_reference:
		settings_dialog.initialize(plugin_reference.json_url, plugin_reference.access_token)
		settings_dialog.show()

# Handler for when settings are saved
func _on_settings_saved(json_url, access_token):
	if plugin_reference:
		# Save the new settings
		plugin_reference.save_settings(json_url, access_token)

		# Reload resources with the new URL
		plugin_reference.load_resources()

# Responsive layout handlers
func _on_window_resized():
	resizing_timer.start()

func _on_resize_timeout():
	_update_grid_columns()

func _on_visibility_changed():
	if visible:
		# Update columns when the tab becomes visible
		_update_grid_columns()

func _update_grid_columns():
	if resources_grid and resources_grid.is_inside_tree():
		var scroll_container = $VBoxContainer/ContentContainer/ScrollContainer
		var available_width = scroll_container.size.x
		
		# Calculate how many cards can fit
		var columns = max(1, int(available_width / min_card_width))
		
		# Update the grid
		resources_grid.columns = columns
		
		# Calculate appropriate card width
		var margin = 10  # Margin between cards
		var card_width = (available_width - (margin * (columns - 1))) / columns
		
		# Update each card's size
		for card in resources_grid.get_children():
			# If the card has a set_card_width method (which we added), use it
			if card.has_method("set_card_width"):
				card.set_card_width(card_width - 10)  # Account for internal padding
			else:
				# Otherwise just set the minimum size directly
				card.custom_minimum_size.x = card_width - 10
