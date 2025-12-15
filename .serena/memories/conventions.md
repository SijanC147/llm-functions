# Code Style and Conventions

## Bash Scripts
- Shebang: `#!/usr/bin/env bash`
- Always `set -e` at top
- Use argc comment annotations for function declarations:
  - `# @describe <description>` - Tool description
  - `# @option --<name>! <desc>` - Required option (! = required)
  - `# @option --<name> <desc>` - Optional option
  - `# @env <VAR>! <desc>` - Required environment variable
- Main function pattern: `main() { ... }` then `eval "$(argc --argc-eval "$0" "$@")"`
- Output to `$LLM_OUTPUT` file

## JavaScript
- Use JSDoc comments for declarations:
  ```js
  /**
   * Description here
   * @typedef {Object} Args
   * @property {string} propName - Description
   * @param {Args} args
   */
  exports.run = function ({ propName }) { ... }
  ```

## Python
- Use docstrings with type hints:
  ```python
  def run(param: str):
      """Description here.
      Args:
          param: Parameter description
      """
  ```

## File Naming
- Tools: `<verb>_<noun>.{sh,js,py}` (e.g., `execute_command.sh`, `get_current_weather.sh`)
- Agents: Directory name = agent name (e.g., `agents/coder/`)

## Agent Structure
```
agents/<name>/
├── index.yaml        # Agent definition (name, description, instructions)
├── tools.txt         # List of shared tools to include
├── tools.{sh,js,py}  # Agent-specific tools
└── functions.json    # Auto-generated declarations
```
