# LLM Functions - Project Overview

## Purpose
LLM Functions is a framework for building LLM tools and agents using Bash, JavaScript, and Python. It leverages function calling to connect LLMs directly to custom code.

## Tech Stack
- **Primary Language**: Bash
- **Supported Languages**: Bash (.sh), JavaScript (.js), Python (.py)
- **Build System**: [argc](https://github.com/sigoden/argc) - Bash command-line framework
- **JSON Processing**: jq
- **Integration**: AIChat CLI tool

## Architecture
```
llm-functions/
├── tools/           # Individual tool scripts (*.sh, *.js, *.py)
├── agents/          # Agent directories with index.yaml + tools
├── scripts/         # Build and utility scripts
├── bin/             # Built binaries (symlinks to runners)
├── mcp/             # MCP server and bridge components
├── utils/           # Utility scripts (guards, helpers)
├── tools.txt        # Tool configuration (which tools to build)
├── agents.txt       # Agent configuration (which agents to build)
├── functions.json   # Generated function declarations
└── Argcfile.sh      # Build system commands
```

## Key Concepts
- **Tools**: Single-purpose functions (e.g., `execute_command.sh`, `web_search.sh`)
- **Agents**: Prompt + Tools + Documents (like OpenAI GPTs)
- **Function Declarations**: Auto-generated from code comments

## Current Configuration
- **Active Tools**: 20+ tools including execute_command, fs_*, web_search, etc.
- **Active Agents**: coder, todo
