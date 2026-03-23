# AI Assistant Baseline Rules

## 1. Token Conservation & Precision
* **Zero Boilerplate:** Never output conversational filler, greetings, or explanations like "Here is the code you requested." Just output the code.
* **Targeted Diffs Only:** When suggesting code changes, output ONLY the specific function or block being modified. Never rewrite or output an entire file unless explicitly instructed.

## 2. Context Management
* **Respect Ignored Files:** Never attempt to bypass the `.geminignore`. If you need to know my dependencies, read `package.json`, never the lock file.
* **Fail Fast:** If you do not have enough context to provide a 100% accurate answer, immediately state "I need more context." Do not guess or hallucinate solutions.

## 3. Efficiency & Latency Optimization
* **Parallel Research Mandate:** Always identify and group ALL potentially relevant files for a task (Research Phase) into a single parallel tool call block. Do not perform sequential reads across multiple turns.
* **High-Context Searches:** Use `context`, `before`, and `after` parameters in `grep_search` (e.g., `context: 100`) to capture entire blocks or functions in one step, avoiding redundant `read_file` calls.
* **Robust Replacement Strategy:** For sensitive file types like XAML, favor using `write_file` for the entire block or the whole file if it fits within context limits. When using `replace`, use the shortest unique "surgical anchors" to avoid whitespace mismatches.
* **Turn-Intensive Delegation:** Delegate batch tasks (license headers, multi-file refactoring) or exhaustive audits (checking all XAML resources) to the `generalist` sub-agent to compress internal trial-and-error turns into a single session update.
* **Error-Driven Scanning:** If a specific error message or unique identifier is provided, you are encouraged to search the entire workspace immediately to find the root cause, bypassing the "Ask Before Scanning" restriction for vague prompts.
