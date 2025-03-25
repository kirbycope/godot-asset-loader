# godot-asset-loader
This project allows you to download assets directly into your Godot Project. 
</br>The assets are defined in JSON format using the following template:
```
[
	{
		"name": "",
		"type": "",
		"description": "",
		"category": "",
		"author": "",
		"license": "",
		"source": "",
		"preview": "",
		"url": ""
	}
]
```
- name: The name of the asset.
- type: The kind of asset (populates the dropdown).
- description: A brief summary of the asset.
- category: The collection the asset belongs to (populates the dropdown).
- source: The URL of where the asset came from.
- preview: The URL of the preview image.
- url: The download URL of the asset ZIP file.

## Installing the Addon
Open terminal/command-prompt and run `curl -s https://raw.githubusercontent.com/kirbycope/godot-asset-loader/main/install-godot-asset-loader.sh | bash`

## Using a Private Repo as a Source
1. Use [resources.json](https://github.com/kirbycope/godot-asset-library/blob/main/resources.json) as a template
1. Set JSON in Asset Loader Settings
1. Create a [PAT](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-fine-grained-personal-access-token) for your repo
    - Give it Read-Only for "Content" and "Metadata"
1. Set the Token in Asset Loader Settings
