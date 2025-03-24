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
	
	# Disable download button initially
	$VBoxContainer/ButtonContainer/DownloadButton.disabled = true


# Method to set the plugin reference
func set_plugin_reference(plugin):
	plugin_reference = plugin


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
