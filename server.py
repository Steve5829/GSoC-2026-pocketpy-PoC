import os
import re
import base64
import binascii
from pathlib import Path

import requests
from fastapi import FastAPI
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
for env_path in (
    BASE_DIR / ".env",
    BASE_DIR / "vibe-agent-demo" / ".env",
    BASE_DIR / "VibeAgentDemo" / ".env",
):
    if env_path.exists():
        load_dotenv(env_path, override=False)

app = FastAPI()

PIXELLAB_API_KEY = os.getenv("PIXELLAB_API_KEY") or os.getenv("PIXELLAB_SECRET")
GODOT_PROJECT_DIR = BASE_DIR / "vibe-agent-demo"


def _error(message: str):
    return {"status": "error", "type": "error", "message": message}


def _safe_asset_name(prompt: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", prompt.strip()).strip("._")
    if not cleaned:
        cleaned = "generated_asset"
    return f"{cleaned[:80]}.png"


def _decode_base64_image(data: dict) -> bytes:
    if not isinstance(data, dict):
        raise ValueError("Pixellab image payload is not an object")

    encoded = data.get("base64")
    if not isinstance(encoded, str) or not encoded:
        raise ValueError("Pixellab image payload does not contain base64 data")

    try:
        return base64.b64decode(encoded)
    except (ValueError, binascii.Error) as exc:
        raise ValueError("Pixellab returned invalid base64 image data") from exc


@app.post("/vibe/generate")
async def generate_asset(prompt: str):
    print(f"🎨 using Pixellab API generating: {prompt}")

    if not PIXELLAB_API_KEY:
        return _error("PIXELLAB_API_KEY is not configured")

    if not GODOT_PROJECT_DIR.exists():
        return _error(f"Godot project dir not found: {GODOT_PROJECT_DIR}")

    api_url = "https://api.pixellab.ai/v1/generate-image-pixflux"
    headers = {"Authorization": f"Bearer {PIXELLAB_API_KEY}"}
    payload = {
        "description": prompt,
        "image_size": {"width": 128, "height": 128},
        "no_background": True,
    }

    try:
        response = requests.post(api_url, json=payload, headers=headers, timeout=30)
        response.raise_for_status()
        data = response.json()

        if not isinstance(data, dict):
            return _error("Pixellab API returned an unexpected response")

        image_bytes = _decode_base64_image(data.get("image"))

        file_name = _safe_asset_name(prompt)
        save_path = GODOT_PROJECT_DIR / file_name
        save_path.write_bytes(image_bytes)

        return {"status": "success", "file": file_name, "type": "asset"}

    except requests.RequestException as e:
        print(f" API request failed: {e}")
        return _error(str(e))
    except ValueError as e:
        print(f" API response decode failed: {e}")
        return _error("Pixellab API returned invalid JSON")


@app.post("/vibe/automate")
async def automate_editor(command: str):
    print(f" receiving automation command: {command}")

    script_snippet = """
    for child in get_selected_nodes()[0].get_children():
        child.name = "child_" + str(child.get_index())
    """

    return {"status": "success", "code": script_snippet, "type": "automation"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="127.0.0.1", port=8000)
