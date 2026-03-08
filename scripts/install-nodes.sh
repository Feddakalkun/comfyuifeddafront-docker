#!/bin/bash
# Install ComfyUI custom nodes from config/nodes.json
# Clones to /workspace/custom_nodes/ (persisted on network volume)
set -e

NODES_DIR="/workspace/custom_nodes"
CONFIG="/app/config/nodes.json"

mkdir -p "$NODES_DIR"

echo "========================================="
echo "  Installing Custom Nodes"
echo "========================================="

# Parse nodes.json and clone each non-local node
python3 << 'PYEOF'
import json, subprocess, os, sys

config_path = "/app/config/nodes.json"
nodes_dir = "/workspace/custom_nodes"

with open(config_path) as f:
    nodes = json.load(f)

total = len([n for n in nodes if not n.get("local")])
installed = 0

for node in nodes:
    if node.get("local"):
        continue

    installed += 1
    name = node["name"]
    url = node["url"]
    folder = node["folder"]
    dest = os.path.join(nodes_dir, folder)

    if os.path.exists(dest):
        print(f"  [{installed}/{total}] {name} — already installed")
        continue

    print(f"  [{installed}/{total}] Installing {name}...")
    result = subprocess.run(
        ["git", "clone", "--depth", "1", url, dest],
        capture_output=True, text=True
    )

    if result.returncode != 0:
        print(f"    WARNING: Failed to clone {name}: {result.stderr.strip()}")
        continue

    # Install Python requirements if present
    req_path = os.path.join(dest, "requirements.txt")
    if os.path.exists(req_path):
        print(f"    Installing requirements for {name}...")
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "-r", req_path,
             "--no-warn-script-location", "-q"],
            capture_output=True, text=True
        )

print(f"\nDone: {installed} nodes processed.")
PYEOF

# Symlink custom_nodes into ComfyUI
rm -rf /app/ComfyUI/custom_nodes
ln -sf "$NODES_DIR" /app/ComfyUI/custom_nodes

echo "[NODES] Custom nodes symlinked to ComfyUI."
