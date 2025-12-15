# LLM Functions Architecture

This document explains how all the components in the llm-functions repository work together and interact with [AIChat](https://github.com/sigoden/aichat) to expose MCP (Model Context Protocol) tools.

## Table of Contents

- [Overview](#overview)
- [High-Level Architecture](#high-level-architecture)
- [Core Components](#core-components)
  - [Tools](#tools)
  - [Agents](#agents)
  - [Build System](#build-system)
  - [Execution Runtime](#execution-runtime)
- [AIChat Integration](#aichat-integration)
- [MCP Integration](#mcp-integration)
  - [MCP Server (Outbound)](#mcp-server-outbound)
  - [MCP Bridge (Inbound)](#mcp-bridge-inbound)
- [Data Flow](#data-flow)
- [File Structure Reference](#file-structure-reference)
- [Environment Variables](#environment-variables)

---

## Overview

**LLM Functions** is a framework for building LLM tools and agents using Bash, JavaScript, and Python. It leverages [function calling](https://platform.openai.com/docs/guides/function-calling) to connect LLMs to custom code, enabling command execution, data processing, and API interaction.

The framework provides:
- **Tools**: Individual functions that perform specific tasks (e.g., execute commands, fetch URLs, search the web)
- **Agents**: Composite entities combining instructions (prompts), tools (function calling), and documents (RAG)
- **MCP Support**: Bidirectional Model Context Protocol integration

**AIChat** is currently the primary CLI tool that consumes llm-functions, providing a unified interface to 20+ LLM providers with function calling support.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                   USER                                          │
└────────────────────────────────────┬────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AIChat CLI                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │  • Sends prompts to LLM providers                                           ││
│  │  • Receives function call requests from LLM                                 ││
│  │  • Executes tools/agents via bin/ symlinks                                  ││
│  │  • Returns results to LLM for response generation                           ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
└────────────────────────────────────┬────────────────────────────────────────────┘
                                     │
              ┌──────────────────────┴──────────────────────┐
              │                                             │
              ▼                                             ▼
┌─────────────────────────────┐               ┌─────────────────────────────┐
│      functions.json         │               │       bin/ directory        │
│  ┌───────────────────────┐  │               │  ┌───────────────────────┐  │
│  │ JSON Schema           │  │               │  │ Symlinks to           │  │
│  │ declarations for      │  │               │  │ run-tool.{sh,js,py}   │  │
│  │ all tools/agents      │  │               │  │ run-agent.{sh,js,py}  │  │
│  └───────────────────────┘  │               │  └───────────────────────┘  │
└─────────────────────────────┘               └──────────────┬──────────────┘
                                                             │
                                                             ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           scripts/ (Execution Runtime)                          │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │  run-tool.{sh,js,py}  → Executes tools with JSON parameters                 ││
│  │  run-agent.{sh,js,py} → Executes agent functions with JSON parameters       ││
│  │  run-mcp-tool.sh      → Executes external MCP tools via bridge              ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
└────────────────────────────────────┬────────────────────────────────────────────┘
                                     │
              ┌──────────────────────┴──────────────────────┐
              │                                             │
              ▼                                             ▼
┌─────────────────────────────┐               ┌─────────────────────────────┐
│        tools/               │               │        agents/              │
│  ┌───────────────────────┐  │               │  ┌───────────────────────┐  │
│  │ execute_command.sh    │  │               │  │ coder/                │  │
│  │ fetch_url_via_curl.sh │  │               │  │   ├── index.yaml     │  │
│  │ web_search.sh         │  │               │  │   ├── tools.sh       │  │
│  │ fs_cat.sh             │  │               │  │   ├── tools.txt      │  │
│  │ ...                   │  │               │  │   └── functions.json │  │
│  └───────────────────────┘  │               │  └───────────────────────┘  │
└─────────────────────────────┘               └─────────────────────────────┘
```

---

## Core Components

### Tools

Tools are individual functions that perform specific tasks. They can be written in Bash, JavaScript, or Python.

**Location**: `tools/<tool-name>.{sh,js,py}`

**Key Characteristics**:
- Single-purpose functions
- Auto-generated JSON declarations from source code comments
- Language-agnostic interface via JSON parameters
- Output written to `$LLM_OUTPUT` file

**Example Tool (Bash)**:
```bash
#!/usr/bin/env bash
set -e

# @describe Execute the shell command.
# @option --command! The command to execute.

main() {
    eval "$argc_command" >> "$LLM_OUTPUT"
}

eval "$(argc --argc-eval "$0" "$@")"
```

**How Tools Are Declared**:
- **Bash**: Uses `argc` comment tags (`@describe`, `@option`, `@flag`)
- **JavaScript**: Uses JSDoc-style comments (`@typedef`, `@property`)
- **Python**: Uses type hints and docstrings

### Agents

Agents are higher-level constructs that combine:
- **Instructions**: Prompts defining agent behavior
- **Tools**: Function calling capabilities (agent-specific + shared)
- **Documents**: RAG (Retrieval-Augmented Generation) resources

**Location**: `agents/<agent-name>/`

**Directory Structure**:
```
agents/
└── myagent/
    ├── index.yaml           # Agent definition
    ├── functions.json       # Auto-generated declarations
    ├── tools.{sh,js,py}     # Agent-specific tools
    └── tools.txt            # Shared tools to include
```

**index.yaml Structure**:
```yaml
name: MyAgent
description: Agent description
version: 0.1.0
instructions: |
  You are an AI agent that...
  Available tools: {{__tools__}}
variables:
  - name: api_key
    description: API key for service
conversation_starters:
  - "What can you do?"
documents:
  - ./local-doc.md
  - https://example.com/remote-doc.txt
```

### Build System

The build system is managed by `Argcfile.sh` using the [argc](https://github.com/sigoden/argc) framework.

**Key Commands**:

| Command | Description |
|---------|-------------|
| `argc build` | Build all tools and agents |
| `argc build@tool` | Build tools (declarations + binaries) |
| `argc build@agent` | Build agents (declarations + binaries) |
| `argc check` | Verify environment and dependencies |
| `argc run@tool <name> <json>` | Execute a tool directly |
| `argc run@agent <name> <action> <json>` | Execute an agent action |

**Build Process**:

```
┌────────────────────────────────────────────────────────────────────────────┐
│                              BUILD PROCESS                                  │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  1. Read Configuration                                                     │
│     ┌──────────────┐      ┌──────────────┐                                │
│     │  tools.txt   │      │  agents.txt  │                                │
│     │              │      │              │                                │
│     │ tool1.sh     │      │ coder        │                                │
│     │ tool2.js     │      │ todo         │                                │
│     │ tool3.py     │      │              │                                │
│     └──────────────┘      └──────────────┘                                │
│            │                     │                                         │
│            ▼                     ▼                                         │
│  2. Parse Source Files (via build-declarations.{sh,js,py})                │
│     ┌──────────────────────────────────────────────────────────────┐      │
│     │  Extract function signatures from comments/type hints        │      │
│     │  • Bash: @describe, @option, @flag tags                      │      │
│     │  • JavaScript: JSDoc @typedef, @property                     │      │
│     │  • Python: Type hints + docstrings                           │      │
│     └──────────────────────────────────────────────────────────────┘      │
│            │                                                               │
│            ▼                                                               │
│  3. Generate JSON Declarations                                            │
│     ┌──────────────────────────────────────────────────────────────┐      │
│     │  functions.json (root)        │  agents/*/functions.json     │      │
│     │  [                            │  [                           │      │
│     │    {                          │    {                         │      │
│     │      "name": "tool1",         │      "name": "action1",      │      │
│     │      "description": "...",    │      "description": "...",   │      │
│     │      "parameters": {...}      │      "parameters": {...},    │      │
│     │    }                          │      "agent": true           │      │
│     │  ]                            │    }                         │      │
│     │                               │  ]                           │      │
│     └──────────────────────────────────────────────────────────────┘      │
│            │                                                               │
│            ▼                                                               │
│  4. Create Binary Symlinks                                                │
│     ┌──────────────────────────────────────────────────────────────┐      │
│     │  bin/                                                        │      │
│     │  ├── tool1 → scripts/run-tool.sh                            │      │
│     │  ├── tool2 → scripts/run-tool.js                            │      │
│     │  ├── tool3 → scripts/run-tool.py                            │      │
│     │  ├── coder → scripts/run-agent.sh                           │      │
│     │  └── todo  → scripts/run-agent.sh                           │      │
│     └──────────────────────────────────────────────────────────────┘      │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### Execution Runtime

The execution runtime (`scripts/run-*.{sh,js,py}`) handles:
1. Parsing tool/agent name from invocation
2. Loading environment variables from `.env`
3. Setting up runtime environment (`LLM_ROOT_DIR`, `LLM_TOOL_NAME`, etc.)
4. Converting JSON parameters to command-line arguments
5. Executing the tool/agent script
6. Capturing output to `$LLM_OUTPUT`

**Execution Flow**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TOOL EXECUTION FLOW                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  AIChat calls: bin/execute_command '{"command": "ls -la"}'                 │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  bin/execute_command (symlink → scripts/run-tool.sh)                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  scripts/run-tool.sh                                                │   │
│  │  1. Determine tool name from $0 (execute_command)                   │   │
│  │  2. Load .env file                                                  │   │
│  │  3. Set environment variables:                                       │   │
│  │     - LLM_ROOT_DIR=/path/to/llm-functions                           │   │
│  │     - LLM_TOOL_NAME=execute_command                                 │   │
│  │     - LLM_TOOL_CACHE_DIR=$LLM_ROOT_DIR/cache/execute_command        │   │
│  │  4. Parse JSON → CLI args via jq:                                   │   │
│  │     '{"command": "ls -la"}' → '--command "ls -la"'                  │   │
│  │  5. Execute: tools/execute_command.sh --command "ls -la"            │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  tools/execute_command.sh                                           │   │
│  │  1. argc parses --command argument → $argc_command                  │   │
│  │  2. Execute: eval "$argc_command" >> "$LLM_OUTPUT"                  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Output written to $LLM_OUTPUT file                                 │   │
│  │  AIChat reads output and returns to LLM                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## AIChat Integration

[AIChat](https://github.com/sigoden/aichat) is the primary consumer of llm-functions. It provides function calling support across 20+ LLM providers.

### Connection Setup

AIChat expects llm-functions to be in its `functions_dir`. Two methods to connect:

**Method 1: Symlink**
```bash
ln -s "$(pwd)" "$(aichat --info | sed -n 's/^functions_dir\s\+//p')"
# OR
argc link-to-aichat
```

**Method 2: Environment Variable**
```bash
export AICHAT_FUNCTIONS_DIR="/path/to/llm-functions"
```

### How AIChat Uses LLM Functions

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AIChat ↔ LLM Functions Integration                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  User: "What's the weather in Paris?"                                      │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  AIChat                                                              │   │
│  │  1. Load functions.json (tool declarations)                         │   │
│  │  2. Send prompt + tool definitions to LLM                           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LLM (e.g., GPT-4, Claude)                                          │   │
│  │  Returns function call request:                                      │   │
│  │  {                                                                   │   │
│  │    "name": "get_current_weather",                                   │   │
│  │    "arguments": {"location": "Paris"}                               │   │
│  │  }                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  AIChat                                                              │   │
│  │  1. Set LLM_OUTPUT to temp file                                     │   │
│  │  2. Execute: bin/get_current_weather '{"location": "Paris"}'        │   │
│  │  3. Read tool output from $LLM_OUTPUT                               │   │
│  │  4. Send output back to LLM for final response                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LLM generates human-readable response:                             │   │
│  │  "The current weather in Paris is 18°C with partly cloudy skies."  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Agent Usage in AIChat

```bash
# Using tools (via %functions% role)
aichat --role %functions% what is the weather in Paris?

# Using agents
aichat --agent todo list all my todos
aichat --agent coder refactor this function
```

---

## MCP Integration

LLM Functions provides bidirectional MCP (Model Context Protocol) support:

1. **MCP Server**: Expose llm-functions tools/agents to MCP clients
2. **MCP Bridge**: Consume external MCP tools within llm-functions

### MCP Server (Outbound)

Located at `mcp/server/`, this component exposes llm-functions as an MCP server, allowing any MCP-compatible client to use the tools.

**Architecture**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MCP SERVER ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  MCP Client (Claude Desktop, Cursor, etc.)                          │   │
│  │  Connects via stdio transport                                        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        │ MCP Protocol (JSON-RPC)                           │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  mcp/server/index.js                                                │   │
│  │                                                                      │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │  Server Initialization                                       │    │   │
│  │  │  - Reads functions.json (or agents/*/functions.json)        │    │   │
│  │  │  - Filters out MCP-sourced tools (f.mcp property)           │    │   │
│  │  │  - Registers ListToolsRequestSchema handler                  │    │   │
│  │  │  - Registers CallToolRequestSchema handler                   │    │   │
│  │  └─────────────────────────────────────────────────────────────┘    │   │
│  │                                                                      │   │
│  │  Request Handlers:                                                   │   │
│  │                                                                      │   │
│  │  ListToolsRequest → Returns tool definitions from functions.json    │   │
│  │                                                                      │   │
│  │  CallToolRequest:                                                    │   │
│  │  1. Find tool in functions array                                    │   │
│  │  2. Spawn process: bin/<tool-name> '{"args": ...}'                  │   │
│  │  3. Set LLM_OUTPUT to temp file                                     │   │
│  │  4. Read output and return via MCP response                         │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  bin/<tool-name> → scripts/run-tool.{sh,js,py}                      │   │
│  │  → tools/<tool-name>.{sh,js,py}                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Configuration (for MCP clients)**:

```json
{
  "mcpServers": {
    "tools": {
      "command": "npx",
      "args": ["mcp-llm-functions", "<llm-functions-dir>"]
    }
  }
}
```

**Serving a Specific Agent**:
```json
{
  "mcpServers": {
    "coder": {
      "command": "npx",
      "args": ["mcp-llm-functions", "<llm-functions-dir>", "coder"]
    }
  }
}
```

**Environment Variables**:
- `AGENT_TOOLS_ONLY`: Set to `true` to expose only agent-specific tools

### MCP Bridge (Inbound)

Located at `mcp/bridge/`, this component allows llm-functions to consume external MCP servers, making their tools available within the llm-functions ecosystem.

**Architecture**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MCP BRIDGE ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Configuration: mcp.json                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  {                                                                   │   │
│  │    "mcpServers": {                                                  │   │
│  │      "sqlite": {                                                    │   │
│  │        "command": "uvx",                                            │   │
│  │        "args": ["mcp-server-sqlite", "--db-path", "/tmp/foo.db"]   │   │
│  │      },                                                             │   │
│  │      "github": {                                                    │   │
│  │        "command": "npx",                                            │   │
│  │        "args": ["-y", "@modelcontextprotocol/server-github"],      │   │
│  │        "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "..." }            │   │
│  │      }                                                              │   │
│  │    }                                                                │   │
│  │  }                                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        │ argc mcp start                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  mcp/bridge/index.js (HTTP server on port 8808)                     │   │
│  │                                                                      │   │
│  │  For each MCP server in mcp.json:                                   │   │
│  │  1. Spawn the MCP server process                                    │   │
│  │  2. Connect as MCP client via stdio                                 │   │
│  │  3. Call listTools() to get available tools                         │   │
│  │  4. Register tools with prefixed names (e.g., sqlite_query)        │   │
│  │                                                                      │   │
│  │  HTTP Endpoints:                                                     │   │
│  │  GET  /tools            → Returns all tool declarations             │   │
│  │  POST /tools/:name      → Execute tool with JSON body               │   │
│  │  GET  /health           → Health check                              │   │
│  │  GET  /pid              → Server process ID                         │   │
│  │                                                                      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        │ Tools merged into functions.json                  │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  scripts/mcp.sh merge-functions                                     │   │
│  │                                                                      │   │
│  │  1. Fetch tool declarations from bridge: GET /tools                 │   │
│  │  2. Add "mcp": "<server-name>" property to each tool               │   │
│  │  3. Merge with existing functions.json                              │   │
│  │  4. Create bin/<tool-name> symlinks → scripts/run-mcp-tool.sh      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        │ Tool execution                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  scripts/run-mcp-tool.sh                                            │   │
│  │                                                                      │   │
│  │  1. Receive tool name and JSON arguments                            │   │
│  │  2. POST to bridge: /tools/<tool-name> with JSON body              │   │
│  │  3. Write response to $LLM_OUTPUT                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**MCP Bridge Commands**:

| Command | Description |
|---------|-------------|
| `argc mcp start` | Start bridge server, merge tools, build binaries |
| `argc mcp stop` | Stop bridge server, remove MCP tools from functions.json |
| `argc mcp logs` | View bridge server logs |
| `argc mcp check` | Check if bridge server is running |
| `argc mcp run@tool <name> <json>` | Execute an MCP tool directly |

---

## Data Flow

### Complete Request Flow (AIChat + MCP)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COMPLETE DATA FLOW                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  User: "Search GitHub for repositories about rust async"                   │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  AIChat                                                              │   │
│  │  • Loads functions.json (includes native tools + MCP tools)         │   │
│  │  • Sends to LLM with tool definitions                               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  LLM decides to call: github_search_repositories                    │   │
│  │  Arguments: {"query": "rust async"}                                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  AIChat executes: bin/github_search_repositories '{"query":...}'   │   │
│  │                        │                                             │   │
│  │  bin/github_search_repositories                                     │   │
│  │  (symlink → scripts/run-mcp-tool.sh)                                │   │
│  │                        │                                             │   │
│  │  scripts/run-mcp-tool.sh                                            │   │
│  │  • POST http://localhost:8808/tools/github_search_repositories     │   │
│  │  • Body: {"query": "rust async"}                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  MCP Bridge (mcp/bridge/index.js)                                   │   │
│  │  • Finds github_search_repositories tool                            │   │
│  │  • Calls underlying GitHub MCP server via client.callTool()        │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  GitHub MCP Server (@modelcontextprotocol/server-github)            │   │
│  │  • Executes GitHub API search                                       │   │
│  │  • Returns repository results                                       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                        │                                                    │
│                        ▼                                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Response flows back:                                               │   │
│  │  MCP Server → Bridge → run-mcp-tool.sh → $LLM_OUTPUT → AIChat → LLM│   │
│  │                                                                      │   │
│  │  LLM generates response: "I found several popular Rust async       │   │
│  │  repositories including tokio, async-std, and futures-rs..."       │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## File Structure Reference

```
llm-functions/
├── Argcfile.sh              # Build system and command definitions
├── tools.txt                # Tools to build (one per line)
├── agents.txt               # Agents to build (one per line)
├── functions.json           # Auto-generated tool declarations
├── .env                     # Environment variables (git-ignored)
│
├── tools/                   # Individual tool scripts
│   ├── execute_command.sh
│   ├── fetch_url_via_curl.sh
│   ├── web_search.sh → web_search_perplexity.sh
│   ├── fs_cat.sh
│   ├── fs_write.sh
│   └── ...
│
├── agents/                  # Agent directories
│   ├── coder/
│   │   ├── index.yaml       # Agent definition
│   │   ├── functions.json   # Auto-generated declarations
│   │   ├── tools.sh         # Agent-specific tools
│   │   └── tools.txt        # Shared tools to include
│   └── todo/
│       └── ...
│
├── bin/                     # Generated executable symlinks
│   ├── execute_command → scripts/run-tool.sh
│   ├── coder → scripts/run-agent.sh
│   └── ...
│
├── scripts/                 # Runtime and build scripts
│   ├── run-tool.{sh,js,py}  # Tool execution runtime
│   ├── run-agent.{sh,js,py} # Agent execution runtime
│   ├── run-mcp-tool.sh      # MCP tool execution
│   ├── build-declarations.{sh,js,py}  # Declaration generators
│   ├── mcp.sh               # MCP bridge management
│   └── ...
│
├── mcp/
│   ├── server/              # Expose tools via MCP
│   │   ├── index.js
│   │   └── package.json
│   └── bridge/              # Consume external MCP tools
│       ├── index.js
│       └── package.json
│
├── utils/                   # Helper utilities
│   ├── guard_operation.sh
│   ├── guard_path.sh
│   └── patch.awk
│
├── cache/                   # Runtime cache (git-ignored)
│   ├── __mcp__/             # MCP bridge data
│   └── <tool-name>/         # Per-tool cache
│
└── docs/                    # Documentation
    ├── tool.md
    ├── agent.md
    ├── argcfile.md
    └── environment-variables.md
```

---

## Environment Variables

### Injected by Runtime

| Variable | Description | Set By |
|----------|-------------|--------|
| `LLM_ROOT_DIR` | Path to llm-functions directory | run-tool.*, run-agent.* |
| `LLM_TOOL_NAME` | Current tool name (e.g., `execute_command`) | run-tool.* |
| `LLM_TOOL_CACHE_DIR` | Tool-specific cache directory | run-tool.* |
| `LLM_AGENT_NAME` | Current agent name (e.g., `coder`) | run-agent.* |
| `LLM_AGENT_FUNC` | Current agent function (e.g., `fs_patch`) | run-agent.* |
| `LLM_AGENT_ROOT_DIR` | Path to agent directory | run-agent.* |
| `LLM_AGENT_CACHE_DIR` | Agent-specific cache directory | run-agent.* |
| `LLM_OUTPUT` | Output file path for results | AIChat |
| `LLM_AGENT_VAR_<NAME>` | Agent variables from index.yaml | AIChat |

### User Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `LLM_DUMP_RESULTS` | Regex for tools to print output | `get_current_weather\|fs.*` |
| `LLM_MCP_NEED_CONFIRM` | Regex for tools requiring confirmation | `git_commit\|git_reset` |
| `LLM_MCP_SKIP_CONFIRM` | Regex for tools skipping confirmation | `git_status\|git_diff` |

### Built-in Agent Variables

Available in agent `instructions` via `{{variable}}` syntax:

| Variable | Description | Example |
|----------|-------------|---------|
| `__os__` | Operating system | `linux` |
| `__os_family__` | OS family | `unix` |
| `__arch__` | System architecture | `x86_64` |
| `__shell__` | Default shell | `bash` |
| `__locale__` | Language/region | `en-US` |
| `__now__` | Current timestamp (ISO 8601) | `2024-07-29T08:11:24.367Z` |
| `__cwd__` | Current working directory | `/home/user` |
| `__tools__` | List of available agent tools | |

---

## Summary

LLM Functions provides a comprehensive framework for extending LLM capabilities through:

1. **Multi-language Support**: Write tools in Bash, JavaScript, or Python
2. **Auto-generated Declarations**: JSON schemas derived from source code comments
3. **AIChat Integration**: Seamless connection to 20+ LLM providers
4. **MCP Compatibility**: Bidirectional Model Context Protocol support
5. **Agent Architecture**: Combine instructions, tools, and RAG for complex workflows

The architecture prioritizes simplicity (write a function, add comments) while enabling sophisticated integrations (MCP servers, RAG documents, multi-tool agents).
