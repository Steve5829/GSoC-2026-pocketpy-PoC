# Vibe Agent Demo

Small demo project that connects a Godot editor plugin to a local FastAPI backend.

The backend exposes two endpoints:

- `/vibe/generate`: asks PixelLab to generate a pixel-art asset and saves it into the Godot project
- `/vibe/automate`: returns a small editor automation snippet

The Godot plugin adds two menu actions inside the editor:

- `Vibe: Generate Asset`
- `Vibe: Editor Automation`

## Project Layout

- `server.py`: local FastAPI backend
- `requirements.txt`: Python dependencies
- `vibe-agent-demo/`: Godot 4 demo project
- `vibe-agent-demo/addons/vibe_agent/`: editor plugin

## Requirements

- Python 3.7+
- Godot 4.6
- A valid PixelLab API key

## Setup

Create a `.env` file in the repository root:

```env
PIXELLAB_API_KEY=your_api_key_here
```

Install Python dependencies:

```bash
python3 -m pip install -r requirements.txt
```

## Run The Backend

Start the FastAPI server from the repository root:

```bash
python3 server.py
```

The backend listens on `http://127.0.0.1:8000`.

## Open The Godot Project

Open:

```text
vibe-agent-demo/project.godot
```

The plugin is already enabled in the demo project through:

```text
vibe-agent-demo/addons/vibe_agent/plugin.cfg
```

## Use The Plugin

Once the backend is running and the Godot project is open:

1. Open the Godot editor.
2. Use the top menu item `Vibe: Generate Asset` to request an image.
3. Use `Vibe: Editor Automation` to request the sample automation response.

Generated assets are written into `vibe-agent-demo/` and the plugin triggers a filesystem refresh after success.

## Troubleshooting

If Godot prints `request sent failed`, the local backend is probably not running.

If Godot prints `backend processing failed`, check the backend terminal output from `server.py`.

If asset generation fails, verify:

- the `.env` file exists
- `PIXELLAB_API_KEY` is set correctly
- the machine can reach the PixelLab API
- the backend was restarted after code changes

## Notes

This repository is a minimal integration demo, not a production-ready plugin. The current automation endpoint returns code as a string and does not execute it inside the editor.
