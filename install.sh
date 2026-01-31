#!/usr/bin/env bash
# install.sh - macOS/Linux setup for Claude Voice MCP plugin
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODELS_DIR="$SCRIPT_DIR/voice/models"

echo "=== Claude Voice MCP - Setup ==="

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Darwin) PLATFORM="macos" ;;
    Linux)  PLATFORM="linux" ;;
    *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac

echo "Platform: $PLATFORM"

# 1. Check/install uv
if command -v uv &>/dev/null; then
    echo "[OK] uv found: $(uv --version)"
else
    echo "[..] Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    if command -v uv &>/dev/null; then
        echo "[OK] uv installed."
    else
        echo "[!!] uv install failed. See https://docs.astral.sh/uv/getting-started/installation/"
        exit 1
    fi
fi

# 2. Platform-specific system dependencies
if [ "$PLATFORM" = "macos" ]; then
    # onnxruntime needs libomp on macOS
    if brew list libomp &>/dev/null 2>&1; then
        echo "[OK] libomp found."
    elif command -v brew &>/dev/null; then
        echo "[..] Installing libomp (required by ONNX Runtime)..."
        brew install libomp
        echo "[OK] libomp installed."
    else
        echo "[!!] Homebrew not found. Install libomp manually:"
        echo "     /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo "     brew install libomp"
    fi
elif [ "$PLATFORM" = "linux" ]; then
    # sounddevice needs PortAudio on Linux (not bundled in pip wheel)
    if ldconfig -p 2>/dev/null | grep -q libportaudio; then
        echo "[OK] libportaudio found."
    elif dpkg -l libportaudio2 &>/dev/null 2>&1; then
        echo "[OK] libportaudio2 found."
    elif rpm -q portaudio &>/dev/null 2>&1; then
        echo "[OK] portaudio found."
    else
        echo "[!!] libportaudio not found. Install it:"
        if command -v apt-get &>/dev/null; then
            echo "     sudo apt-get install -y libportaudio2"
        elif command -v dnf &>/dev/null; then
            echo "     sudo dnf install -y portaudio"
        elif command -v pacman &>/dev/null; then
            echo "     sudo pacman -S portaudio"
        else
            echo "     Install PortAudio via your system package manager."
        fi
    fi
fi

# 3. Download TTS models
mkdir -p "$MODELS_DIR"

MODEL_FILE="$MODELS_DIR/kokoro-v1.0.onnx"
VOICES_FILE="$MODELS_DIR/voices-v1.0.bin"

MODEL_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
VOICES_URL="https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"

if [ -f "$MODEL_FILE" ]; then
    echo "[OK] Model file already downloaded."
else
    echo "[..] Downloading kokoro-v1.0.onnx (~310 MB)..."
    curl -L -o "$MODEL_FILE" "$MODEL_URL"
    echo "[OK] Model downloaded."
fi

if [ -f "$VOICES_FILE" ]; then
    echo "[OK] Voices file already downloaded."
else
    echo "[..] Downloading voices-v1.0.bin (~27 MB)..."
    curl -L -o "$VOICES_FILE" "$VOICES_URL"
    echo "[OK] Voices downloaded."
fi

echo ""
echo "=== Setup complete ==="
echo "The voice plugin is ready. Models and dependencies are pre-cached."
