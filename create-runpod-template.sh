#!/bin/bash
# Creates a RunPod template with pre-configured settings
# Usage: RUNPOD_API_KEY=your_key_here ./create-runpod-template.sh

set -e

if [ -z "$RUNPOD_API_KEY" ]; then
    echo "Error: RUNPOD_API_KEY environment variable not set"
    echo "Get your API key from: https://www.runpod.io/console/user/settings"
    echo ""
    echo "Usage: RUNPOD_API_KEY=your_key_here ./create-runpod-template.sh"
    exit 1
fi

echo "Creating RunPod template for FEDDA AI Studio..."

RESPONSE=$(curl -s -X POST \
  "https://api.runpod.io/graphql?api_key=${RUNPOD_API_KEY}" \
  -H "content-type: application/json" \
  -d '{
    "query": "mutation { saveTemplate(input: { dockerArgs: \"\", env: [], containerDiskInGb: 100, volumeInGb: 200, volumeMountPath: \"/workspace\", imageName: \"feddahannah/fedda-studio:latest\", name: \"FEDDA AI Studio\", ports: \"3000/http,8199/http\", readme: \"# FEDDA AI Studio\\n\\nFull-stack AI generation platform with ComfyUI, Ollama, and custom React UI.\\n\\n## Features\\n- Image generation (Z-Image, Qwen Multi-Angle)\\n- Video generation (LTX-2, Lipsync)\\n- Audio/TTS (ACE-Step 1.5)\\n- Chat with vision (Ollama + Llava)\\n- LoRA management\\n\\n## Access\\n- **Port 3000**: FEDDA React UI\\n- **Port 8199**: ComfyUI (direct access)\\n\\n## First Run\\n- Models download automatically in background\\n- UI available in ~2 minutes\\n- Full setup complete in ~15 minutes\\n\\n## Minimum GPU\\nRTX 3090 (24GB VRAM) or better\\n\\n## Storage\\n200GB network volume required for models\" }) { id name imageName containerDiskInGb volumeInGb volumeMountPath ports } }"
  }')

echo ""
echo "Response:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

# Extract template ID if successful
TEMPLATE_ID=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['saveTemplate']['id'])" 2>/dev/null || echo "")

if [ -n "$TEMPLATE_ID" ]; then
    echo ""
    echo "✅ Template created successfully!"
    echo "Template ID: $TEMPLATE_ID"
    echo ""
    echo "Share this URL with your users:"
    echo "https://runpod.io/console/deploy?template=$TEMPLATE_ID"
else
    echo ""
    echo "❌ Failed to create template. Check the error above."
    exit 1
fi
