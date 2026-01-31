# /// script
# requires-python = ">=3.10"
# dependencies = [
#   "mcp[cli]",
#   "kokoro-onnx>=0.4.0",
#   "sounddevice",
#   "soundfile",
#   "numpy",
# ]
# ///
"""
Claude Code Voice TTS MCP Server
Uses Kokoro-82M neural TTS for high-quality local text-to-speech.
Cross-platform: Windows, macOS, Linux.
"""

import asyncio
import os
import sys
import urllib.request
from pathlib import Path

from mcp.server.fastmcp import FastMCP

PLUGIN_ROOT = Path(__file__).parent
MODEL_DIR = PLUGIN_ROOT / "models"

MODEL_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
VOICES_URL = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"

LANG_MAP = {
    "a": "en-us",
    "b": "en-gb",
    "j": "ja",
    "z": "zh",
    "e": "es",
    "f": "fr",
    "h": "hi",
    "i": "it",
    "p": "pt-br",
}

VOICES = {
    # American English
    "af_heart": "American Female - Heart (highest quality)",
    "af_alloy": "American Female - Alloy",
    "af_aoede": "American Female - Aoede",
    "af_bella": "American Female - Bella",
    "af_jessica": "American Female - Jessica",
    "af_kore": "American Female - Kore",
    "af_nicole": "American Female - Nicole",
    "af_nova": "American Female - Nova",
    "af_river": "American Female - River",
    "af_sarah": "American Female - Sarah",
    "af_sky": "American Female - Sky",
    "am_adam": "American Male - Adam",
    "am_echo": "American Male - Echo",
    "am_eric": "American Male - Eric",
    "am_fenrir": "American Male - Fenrir",
    "am_liam": "American Male - Liam",
    "am_michael": "American Male - Michael",
    "am_onyx": "American Male - Onyx",
    "am_puck": "American Male - Puck",
    "am_santa": "American Male - Santa",
    # British English
    "bf_alice": "British Female - Alice",
    "bf_emma": "British Female - Emma",
    "bf_isabella": "British Female - Isabella",
    "bf_lily": "British Female - Lily",
    "bm_daniel": "British Male - Daniel",
    "bm_fable": "British Male - Fable",
    "bm_george": "British Male - George",
    "bm_lewis": "British Male - Lewis",
}

# Session state
_default_voice = "af_heart"
_kokoro = None


def _download_with_progress(url: str, dest: Path):
    """Download a file, printing progress to stderr."""
    filename = dest.name
    print(f"[voice-tts] Downloading {filename}...", file=sys.stderr, flush=True)

    def report(block_num, block_size, total_size):
        downloaded = block_num * block_size
        if total_size > 0:
            pct = min(100, downloaded * 100 // total_size)
            mb = downloaded / (1024 * 1024)
            total_mb = total_size / (1024 * 1024)
            print(
                f"\r[voice-tts] {filename}: {mb:.0f}/{total_mb:.0f} MB ({pct}%)",
                end="",
                file=sys.stderr,
                flush=True,
            )

    urllib.request.urlretrieve(url, dest, reporthook=report)
    print(file=sys.stderr, flush=True)


def _ensure_models() -> tuple[Path, Path]:
    """Download model files if not present."""
    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    model_path = MODEL_DIR / "kokoro-v1.0.onnx"
    voices_path = MODEL_DIR / "voices-v1.0.bin"
    if not model_path.exists():
        _download_with_progress(MODEL_URL, model_path)
    if not voices_path.exists():
        _download_with_progress(VOICES_URL, voices_path)
    return model_path, voices_path


def _get_kokoro():
    """Lazy-load the Kokoro TTS instance."""
    global _kokoro
    if _kokoro is None:
        from kokoro_onnx import Kokoro

        model_path, voices_path = _ensure_models()
        print("[voice-tts] Loading Kokoro model...", file=sys.stderr, flush=True)
        _kokoro = Kokoro(str(model_path), str(voices_path))
        print("[voice-tts] Model loaded.", file=sys.stderr, flush=True)
    return _kokoro


def _lang_for_voice(voice: str) -> str:
    """Infer language code from voice name prefix."""
    if voice and len(voice) >= 1:
        return LANG_MAP.get(voice[0], "en-us")
    return "en-us"


# --- MCP Server ---

mcp = FastMCP("voice-tts")


@mcp.tool()
async def speak(text: str, voice: str = "", speed: float = 1.0) -> str:
    """
    Speak text aloud using Kokoro neural text-to-speech.
    Call this tool to read your response to the user out loud.

    Args:
        text: The text to speak. Should be plain conversational text, not markdown or code.
        voice: Voice ID to use (e.g. af_heart, am_adam). Leave empty for default.
        speed: Speech speed multiplier. 1.0 is normal, 0.8 is slower, 1.2 is faster.
    """
    use_voice = voice if voice else _default_voice
    lang = _lang_for_voice(use_voice)

    kokoro = await asyncio.to_thread(_get_kokoro)
    samples, sample_rate = await asyncio.to_thread(
        kokoro.create, text, voice=use_voice, speed=speed, lang=lang
    )

    import sounddevice as sd

    await asyncio.to_thread(sd.play, samples, sample_rate)
    await asyncio.to_thread(sd.wait)

    preview = text[:80] + ("..." if len(text) > 80 else "")
    return f"Spoke aloud ({use_voice}): {preview}"


@mcp.tool()
async def list_voices(language: str = "en") -> str:
    """
    List available TTS voices.

    Args:
        language: Filter by language prefix. 'en' for all English, 'a' for American, 'b' for British, or 'all' for everything.
    """
    lines = []
    for vid, desc in VOICES.items():
        if language == "all" or vid.startswith(language) or (language == "en" and vid[0] in ("a", "b")):
            marker = " (default)" if vid == _default_voice else ""
            lines.append(f"  {vid}: {desc}{marker}")
    if not lines:
        return f"No voices found for language filter '{language}'. Use 'all' to see everything."
    return f"Available voices:\n" + "\n".join(lines)


@mcp.tool()
async def set_default_voice(voice: str) -> str:
    """
    Change the default voice for this session.

    Args:
        voice: Voice ID to set as default (e.g. af_heart, am_adam, bf_alice).
    """
    global _default_voice
    if voice not in VOICES:
        available = ", ".join(sorted(VOICES.keys()))
        return f"Unknown voice '{voice}'. Available: {available}"
    _default_voice = voice
    return f"Default voice set to: {voice} ({VOICES[voice]})"


if __name__ == "__main__":
    mcp.run()
