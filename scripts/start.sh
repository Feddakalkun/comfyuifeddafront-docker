#!/bin/bash
set -e

echo "========================================="
echo "  FEDDA AI Studio — Docker Startup"
echo "========================================="
echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'none detected')"
echo ""

# --- 1. Create network volume directory structure ---
MODELS_DIR="/workspace/models/comfyui"
mkdir -p "$MODELS_DIR"/{checkpoints,diffusion_models,clip,text_encoders,vae,loras,sams,ultralytics/bbox,model_patches}
mkdir -p /workspace/models/ollama
mkdir -p /workspace/output
mkdir -p /workspace/input

# --- 2. Symlink ComfyUI model directories to network volume ---
echo "[SETUP] Symlinking model directories to /workspace..."
for dir in checkpoints diffusion_models clip text_encoders vae loras sams ultralytics model_patches; do
    rm -rf "/app/ComfyUI/models/$dir"
    ln -sf "$MODELS_DIR/$dir" "/app/ComfyUI/models/$dir"
done

# Symlink output and input directories
rm -rf /app/ComfyUI/output
ln -sf /workspace/output /app/ComfyUI/output

rm -rf /app/ComfyUI/input
ln -sf /workspace/input /app/ComfyUI/input

# --- 3. Install custom nodes (first run only) ---
if [ ! -f "/workspace/.nodes_installed" ]; then
    echo ""
    echo "[SETUP] First run detected — installing custom nodes..."
    /app/scripts/install-nodes.sh
    touch /workspace/.nodes_installed
    echo "[SETUP] Custom nodes installed."
else
    echo "[SETUP] Custom nodes already installed (skipping)."
    # Ensure symlink exists
    if [ ! -L "/app/ComfyUI/custom_nodes" ] || [ ! -d "/app/ComfyUI/custom_nodes" ]; then
        rm -rf /app/ComfyUI/custom_nodes
        ln -sf /workspace/custom_nodes /app/ComfyUI/custom_nodes
    fi
fi

# --- 4. Copy bundled assets ---
cp -n /app/assets/styles.csv /app/ComfyUI/styles.csv 2>/dev/null || true

# Copy bundled LoRAs if they exist
if [ -d "/app/assets/loras" ]; then
    echo "[SETUP] Copying bundled LoRAs..."
    cp -rn /app/assets/loras/* "$MODELS_DIR/loras/" 2>/dev/null || true
fi

# --- 5. Configure ComfyUI-Manager ---
MANAGER_DIR="/app/ComfyUI/custom_nodes/ComfyUI-Manager"
if [ -d "$MANAGER_DIR" ]; then
    mkdir -p "$MANAGER_DIR/user"
    cat > "$MANAGER_DIR/user/config.ini" << 'EOF'
[default]
security_level = weak
network_mode = public
EOF
fi

# --- 6. Copy workflow files to a location ComfyUI can serve ---
# (Frontend fetches these from Nginx at /workflows/*)
# They're already in /app/frontend/dist/workflows/ from the build

# --- 7. Start model downloads in background ---
echo ""
echo "[MODELS] Starting background model downloads..."
/app/scripts/download-models.sh &

# --- 8. Launch all services via supervisord ---
echo ""
echo "========================================="
echo "  Starting services..."
echo "  UI will be available on port 3000"
echo "========================================="
exec supervisord -c /etc/supervisor/conf.d/supervisord.conf
