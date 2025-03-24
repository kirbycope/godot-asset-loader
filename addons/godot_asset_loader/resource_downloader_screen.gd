# resource_downloader_screen.gd
@tool
extends Control

var plugin_reference
var resources_grid
var selected_resource = null


## Called when the node is "ready", i.e. when both the node and its children have entered the scene tree.
func _ready():
	resources_grid = $VBoxContainer/ScrollContainer/ResourcesGrid
	$VBoxContainer/ButtonContainer/DownloadButton.connect("pressed", Callable(self, "_on_download_pressed"))
	$VBoxContainer/ButtonContainer/RefreshButton.connect("pressed", Callable(self, "_on_refresh_pressed"))
	
	# Disable download button initially
	$VBoxContainer/ButtonContainer/DownloadButton.disabled = true


# Method to set the plugin reference
func set_plugin_reference(plugin):
	plugin_reference = plugin


func populate_resource_list(resources):
	# Clear existing children
	for child in resources_grid.get_children():
		child.queue_free()
	
	for resource in resources:
		var resource_card = load("res://addons/godot_asset_loader/resource_card.tscn").instantiate()
		resources_grid.add_child(resource_card)
		resource_card.setup(resource)
		resource_card.connect("card_selected", Callable(self, "_on_resource_card_selected"))


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


func _on_download_pressed():
	if selected_resource and plugin_reference:
		plugin_reference.download_resource(selected_resource)


func _on_refresh_pressed():
	if plugin_reference:
		plugin_reference.load_resources()
