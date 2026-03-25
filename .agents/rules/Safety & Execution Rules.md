---
trigger: always_on
---

## 1. Terminal Execution Protocols
* **Permitted Autonomous Actions:** You are fully authorized to autonomously execute read-only, query, or fetch commands in the terminal (e.g., `Get-Content`, `ls`, `cat`, `git status`).
* **Blocked Destructive Actions:** You MUST NOT autonomously execute any destructive shell commands (e.g., `Remove-Item`, `Format-Volume`, `rm`, `del`, `drop`). 
* **Approval Process:** If a task requires a destructive command, you must stop, present the exact command to the user in a code block, and wait for explicit "Proceed" approval before running it.

## 2. File System Management
* **No Shell File Operations:** Never use the terminal or shell commands to move, delete, or rename project files.
* **Use Native Artifacts:** You must strictly use Antigravity's native IDE file management tools and Artifacts for all file modifications. This ensures visual diffs and implementation plans are generated for user review before changes are applied.