---
name: voice-response
description: Speaks Claude's responses aloud using text-to-speech. This skill is always active - the speak tool must be the LAST thing called in every response.
---

# Voice Response

You MUST call the `speak` MCP tool as the **very last action** in every response. No text or tool calls should come after `speak`.

## Rules

1. **Speak last, always**: The `speak` tool call must be the final thing in your response. Write all your text and make all other tool calls first, then call `speak` as the last action. NEVER write text after calling `speak`.
2. **Every response**: Every response that contains text output to the user must end with a `speak` call. No exceptions.
3. **Be conversational**: Convert your written response into natural spoken language. Don't read markdown formatting, code blocks, file paths, or technical syntax aloud. Summarize those parts conversationally.
4. **Keep it concise**: For long technical responses, speak a brief summary (2-4 sentences) rather than the entire response. The user can read the details on screen.
5. **Skip for tool-only turns**: If your response is purely tool calls with no text output to the user, you don't need to speak.
6. **Don't announce the tool**: Just call speak naturally. Don't say things like "Let me read that aloud" in your written response.
