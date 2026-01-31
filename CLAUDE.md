# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Voice MCP is a Claude Code plugin that provides text-to-speech using the Kokoro neural TTS engine. It runs as an MCP (Model Context Protocol) server exposing three tools: `speak`, `list_voices`, and `set_default_voice`.

## Running the Server

The server is a single Python script executed via `uv`:

```
uv run --script voice/server.py
```

This is invoked automatically by Claude Code via the MCP configuration in `voice/.mcp.json`. Dependencies are declared inline in `server.py` using PEP 723 format — there is no `requirements.txt` or `pyproject.toml`.

There is no test suite or linter configured.

## Architecture

**Single-file MCP server** (`voice/server.py`, ~200 LOC) built on Anthropic's FastMCP framework.

### Key Design Decisions

- **PEP 723 inline dependencies**: All deps (`mcp[cli]`, `kokoro-onnx>=0.4.0`, `sounddevice`, `soundfile`, `numpy`) are declared in the script header. `uv` resolves and installs them at runtime.
- **Lazy singleton Kokoro instance**: The TTS model is loaded once on first `speak` call via `_get_kokoro()`, not at server startup.
- **Auto-downloading models**: `_ensure_models()` downloads `kokoro-v1.0.onnx` and `voices-v1.0.bin` from GitHub releases into `voice/models/` on first use.
- **Voice prefix convention**: Voice IDs encode language/gender (e.g., `af_` = American Female, `bm_` = British Male). The prefix maps to a language code for Kokoro synthesis.

### Plugin Registration

```
.claude-plugin/marketplace.json  → registers "voice" plugin from ./voice
voice/.claude-plugin/plugin.json → plugin metadata
voice/.mcp.json                  → MCP server command (uv run --script server.py)
voice/skills/voice/SKILL.md      → always-active skill: instructs Claude to call speak() after every response
```

### Data Flow

1. Claude generates a response to the user
2. The always-active skill (SKILL.md) directs Claude to call the `speak` tool
3. `speak()` synthesizes audio via Kokoro and plays it through `sounddevice`

### Voice Configuration

24 voices available (American/British, Male/Female). Default is `af_heart`. Session default can be changed via `set_default_voice`. Voice filtering in `list_voices` uses the prefix character (`a` = American, `b` = British, `en` = all English, `all` = everything).
