# ============================================================================
# FEDDA AI Studio — Docker Image for RunPod
# Clones the main repo at build time — no code duplication
# Multi-stage: Node.js frontend build → CUDA runtime
# ============================================================================

# Stage 1: Clone main repo and build React frontend
FROM node:22-alpine AS frontend-builder

RUN apk add --no-cache git

# Clone the main FEDDA repo (source of truth for all app code)
ARG REPO_URL=https://github.com/Feddakalkun/comfyuifeddafront.git
ARG REPO_BRANCH=main
RUN git clone --depth 1 --branch ${REPO_BRANCH} ${REPO_URL} /app

# Build frontend
WORKDIR /app/frontend
RUN npm ci --no-audit --no-fund && npm run build

# ============================================================================
# Stage 2: Runtime image with CUDA + Python + all services
# ============================================================================
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=utf-8

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 python3.11-venv python3.11-dev python3-pip \
    git curl wget nginx supervisor ffmpeg \
    build-essential cmake ninja-build \
    libgl1-mesa-glx libglib2.0-0 libsm6 libxrender1 libxext6 \
    libffi-dev libssl-dev \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3 \
    && ln -sf /usr/bin/python3 /usr/bin/python

# Upgrade pip
RUN python3 -m pip install --no-cache-dir --upgrade pip wheel setuptools

# PyTorch + CUDA 12.4
RUN python3 -m pip install --no-cache-dir \
    torch torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu124

# Xformers
RUN python3 -m pip install --no-cache-dir \
    xformers --index-url https://download.pytorch.org/whl/cu124

# Clone ComfyUI at pinned stable commit
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /app/ComfyUI \
    && cd /app/ComfyUI \
    && git checkout 0467f69 \
    && pip install --no-cache-dir -r requirements.txt

# Build tools + insightface
RUN python3 -m pip install --no-cache-dir cmake ninja Cython \
    && python3 -m pip install --no-cache-dir insightface --prefer-binary --no-build-isolation

# Core Python dependencies (mirrors install.ps1 step 7)
RUN python3 -m pip install --no-cache-dir \
    accelerate transformers diffusers safetensors \
    huggingface-hub onnxruntime-gpu onnxruntime omegaconf \
    aiohttp aiohttp-sse \
    pytube yt-dlp moviepy youtube-transcript-api \
    numba \
    imageio imageio-ffmpeg av \
    gdown pandas reportlab "google-auth>=2.45.0" google-auth-oauthlib google-auth-httplib2 \
    GPUtil wandb \
    piexif rembg \
    pillow-heif \
    librosa soundfile \
    webdriver-manager beautifulsoup4 lxml shapely \
    deepdiff fal_client matplotlib scipy scikit-image scikit-learn \
    timm colour-science blend-modes loguru \
    fastapi "uvicorn[standard]" python-multipart \
    jupyterlab \
    numpy pillow tqdm requests psutil

# --- Copy app code from the cloned main repo (stage 1) ---
COPY --from=frontend-builder /app/backend /app/backend
COPY --from=frontend-builder /app/config /app/config
COPY --from=frontend-builder /app/assets /app/assets
COPY --from=frontend-builder /app/frontend/dist /app/frontend/dist

# --- Copy Docker-specific files from this repo ---
COPY scripts/ /app/scripts/
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make scripts executable
RUN chmod +x /app/scripts/*.sh

# Create log directory
RUN mkdir -p /var/log

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD /app/scripts/healthcheck.sh

EXPOSE 3000
EXPOSE 8199
EXPOSE 8888

ENTRYPOINT ["/app/scripts/start.sh"]


