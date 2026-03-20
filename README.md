# Vibe Agent Demo

Proof-of-concept Godot editor plugin with:

- a Godot frontend written in GDScript
- a local FastAPI backend in Python
- a text-model layer using an OpenAI-compatible API
- image generation powered by PixelLab

## What It Does

The plugin implements three editor workflows.

### 1. Generate Asset

In the FileSystem dock, right click a folder or blank space in the current folder and choose:

`Vibe: Generate Asset`

This opens a prompt dialog. Example:

`I want a 32x32 pixel style pickaxe icon`

The backend uses a text model to turn the prompt into structured generation settings, then calls PixelLab and saves the image into the selected Godot folder.

### 2. Modify Asset

In the FileSystem dock, right click an existing image asset and choose:

`Vibe: Modify Asset`

This opens a prompt dialog. Example:

`Resize the image into 16:9`

The backend uses the text model to plan a structured image edit and writes a new image beside the original asset.

Current PoC modification actions:

- resize to explicit dimensions like `256x128`
- resize canvas to an aspect ratio like `16:9`
- rotate by degrees like `rotate 90 degrees`

### 3. Editor Automation

In the Scene dock, right click a node and choose:

`Vibe: Automation`

Example prompt:

`Rename all children start from 0 with "child_%d" format`

The backend asks the text model to convert the prompt into a structured action. The plugin then executes that action through Godot editor APIs.

Current PoC automation actions:

- rename all children of the selected node with a `%d` pattern

## Project Layout

- [server.py](/Users/steve/pocket/vibe_agent_task/server.py): FastAPI backend
- [requirements.txt](/Users/steve/pocket/vibe_agent_task/requirements.txt): Python dependencies
- [vibe_plugin.gd](/Users/steve/pocket/vibe_agent_task/vibe-agent-demo/addons/vibe_agent/vibe_plugin.gd): Godot editor plugin
- [plugin.cfg](/Users/steve/pocket/vibe_agent_task/vibe-agent-demo/addons/vibe_agent/plugin.cfg): plugin manifest
- [project.godot](/Users/steve/pocket/vibe_agent_task/vibe-agent-demo/project.godot): demo Godot project

## Requirements

- Python 3.7+
- Godot 4.6
- PixelLab API key
- OpenAI-compatible API key for text planning

## Environment Variables

Copy [.env.example](/Users/steve/pocket/vibe_agent_task/.env.example) to `.env` and fill in your keys.

Supported variables:

- `PIXELLAB_API_KEY`: PixelLab API key
- `OPENAI_BASE_URL`: OpenAI-compatible base URL such as `https://api.openai.com/v1` or `https://api.deepseek.com/v1`
- `OPENAI_API_KEY`: API key for the text model provider
- `OPENAI_MODEL`: model name such as `gpt-4o-mini` or a DeepSeek chat model

The backend looks for `.env` in the repository root and also checks the Godot project folders for convenience.

## Install

```bash
python3 -m pip install -r requirements.txt
```

## Run The Backend

From the repository root:

```bash
python3 server.py
```

The server listens on `http://127.0.0.1:8000`.

## Open The Godot Project

Open:

```text
vibe-agent-demo/project.godot
```

The plugin is already enabled in the demo project.

## Notes On The Current PoC

- asset generation uses PixelLab `generate-image-pixflux`
- image modification is currently implemented as structured local image operations driven by text-model planning
- automation is intentionally structured and limited instead of executing arbitrary model-generated GDScript
- generated and modified files are saved as new assets inside the Godot project

## Troubleshooting

If the menu items do not appear:

- make sure the plugin is enabled in Godot
- reopen the project after editing plugin scripts

If the dialog works but the request fails:

- make sure `python3 server.py` is running
- check the Godot output panel
- check the backend terminal logs

If generation fails:

- verify `PIXELLAB_API_KEY`
- verify the machine can reach `api.pixellab.ai`

If automation falls back or behaves simply:

- verify `OPENAI_API_KEY`, `OPENAI_BASE_URL`, and `OPENAI_MODEL`
- the backend includes heuristic fallbacks, but richer prompts depend on the text model being reachable
