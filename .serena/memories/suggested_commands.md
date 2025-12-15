# Suggested Commands

## Build Commands
```bash
argc build              # Build all tools and agents
argc build@tool         # Build tools only
argc build@agent        # Build agents only
argc clean              # Clean all build artifacts
```

## Run Commands
```bash
argc run@tool <tool> '<json>'           # Run a specific tool
argc run@agent <agent> <action> '<json>' # Run an agent action
```

## Check/Test Commands
```bash
argc check              # Check environment, deps, MCP status
argc check@tool <tool>  # Check specific tool
argc test               # Run all tests
argc test@tool          # Test tools
argc test@agent         # Test agents
```

## Listing Commands
```bash
argc list@tool          # List available tools
argc list@agent         # List available agents
```

## MCP Commands
```bash
argc mcp check          # Check MCP bridge status
argc mcp start          # Start MCP bridge server
argc mcp stop           # Stop MCP bridge server
```

## Utility Commands
```bash
argc link-web-search <tool>       # Link a tool as web_search
argc link-code-interpreter <tool> # Link a tool as code_interpreter
argc link-to-aichat              # Symlink to AIChat functions_dir
argc create@tool                  # Create boilerplate tool script
argc version                      # Show version info
```

## Darwin (macOS) System Commands
- `ls`, `cd`, `grep`, `find`, `cat` - Standard unix commands
- `ln -s` - Create symlinks
- `jq` - JSON processing
- `argc` - Command runner
