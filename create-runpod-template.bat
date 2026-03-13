@echo off
REM Creates a RunPod template with pre-configured settings
REM Usage: set RUNPOD_API_KEY=your_key_here && create-runpod-template.bat

if "%RUNPOD_API_KEY%"=="" (
    echo Error: RUNPOD_API_KEY environment variable not set
    echo Get your API key from: https://www.runpod.io/console/user/settings
    echo.
    echo Usage: set RUNPOD_API_KEY=your_key_here ^&^& create-runpod-template.bat
    exit /b 1
)

echo Creating RunPod template for FEDDA AI Studio...

curl -s -X POST ^
  "https://api.runpod.io/graphql?api_key=%RUNPOD_API_KEY%" ^
  -H "content-type: application/json" ^
  -d "{\"query\": \"mutation { saveTemplate(input: { containerDiskInGb: 100, volumeInGb: 200, volumeMountPath: \\\"/workspace\\\", imageName: \\\"feddahannah/fedda-studio:latest\\\", name: \\\"FEDDA AI Studio\\\", ports: \\\"3000/http,8199/http\\\", readme: \\\"# FEDDA AI Studio\\n\\nFull-stack AI generation platform with ComfyUI, Ollama, and custom React UI.\\n\\n## Features\\n- Image generation (Z-Image, Qwen Multi-Angle)\\n- Video generation (LTX-2, Lipsync)\\n- Audio/TTS (ACE-Step 1.5)\\n- Chat with vision (Ollama + Llava)\\n- LoRA management\\n\\n## Access\\n- **Port 3000**: FEDDA React UI\\n- **Port 8199**: ComfyUI (direct access)\\n\\n## First Run\\n- Models download automatically in background\\n- UI available in ~2 minutes\\n- Full setup complete in ~15 minutes\\n\\n## Minimum GPU\\nRTX 3090 (24GB VRAM) or better\\n\\n## Storage\\n200GB network volume required for models\\\" }) { id name imageName containerDiskInGb volumeInGb volumeMountPath ports } }\"}"

echo.
echo Done! Check response above for template ID.
