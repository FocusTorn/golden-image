# Autonomous Agent Rules

## 1. Operational Restraint
* **Plan First, Act Second:** Before executing any multi-file code change, generating a new component, or running a complex terminal sequence, you MUST generate a brief implementation plan and await my approval.
* **No Unsolicited Refactoring:** Only modify the exact files and lines required to complete the specific task. Do not "clean up" adjacent code, update documents/documentation or upgrade dependencies unless explicitly told to do so.

## 2. Terminal & Execution Guardrails
* **The "Two-Strike" Rule:** If you run a terminal command (e.g., `npm run build` or a test script) and it fails, you may try to fix it and run it ONE more time. If it fails a second time, STOP IMMEDIATELY and ask for my intervention. Do not loop.
* **Efficient Discovery:** When researching the codebase, rely on fast search tools (like `grep` or `rg`) to find keywords. Do not open and read entire files into the context window just to see if they contain what you are looking for.
* **Artifacts Over Logs:** If a test fails, do not dump the entire 500-line console log into the chat. Summarize the error and provide a specific artifact or snippet.
