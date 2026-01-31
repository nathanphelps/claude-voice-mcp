---
name: voice-response
description: Speaks Claude's responses aloud using text-to-speech. This skill is always active - after every response, Claude should call the speak tool to read a conversational summary to the user.
---

# Voice Response

After EVERY response you give to the user, you MUST call the `speak` MCP tool to read your response aloud.

## Rules

1. **Always speak**: After every response, call the `speak` tool with a spoken version of your answer.
2. **Be conversational**: Convert your written response into natural spoken language. Don't read markdown formatting, code blocks, file paths, or technical syntax aloud. Summarize those parts conversationally.
3. **Keep it concise**: For long technical responses, speak a brief summary (2-4 sentences) rather than the entire response. The user can read the details on screen.
4. **Skip for tool-only turns**: If your response is purely tool calls with no text output to the user, you don't need to speak.
5. **Don't announce the tool**: Just call speak naturally. Don't say things like "Let me read that aloud" in your written response.
