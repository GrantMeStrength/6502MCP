# 6502MCP

6502MCP is a project that takes the work done for the VirtualKim iOS app, and extracts the 6502 emulator and assembler into a reusable Swift Package - then exposes them through an MCP (Model Context Protocol) server. 

By using 6502MCP, an LLM such as Codex or Claude Code can write, assemble, run, debug and inspect 6502 programs via MCP tool calls more accurately than by using model inference alone.

This should be useful when debugging your own 6502 code.

I’ve not tried it, but prefacing your work with a description of your specific 6502-based hardware (use of zero page, useful ROM calls etc.) in a prompt (or preferably a config file) might allow some more machine-specific projects to work.

![Screenshot of the MCP Server being used to test 6502](screenshot.png)

## What this project does

- **Emulator6502 (library)**: 6502 CPU, memory map, KIM‑1 ROM loader, MOS 6532 RIOT emulation, and utility loaders.
- **Assembler6502 (library)**: two‑pass 6502 assembler producing object code, listing output, and a symbol table.
- **MCPServer (executable)**: MCP JSON‑RPC server over stdio that connects tools to the emulator and assembler.

## Mac quickstart (bash)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Install Xcode Command Line Tools if needed.
xcode-select --install || true

# Clone and build.
cd ~/Developer
git clone https://github.com/GrantMeStrength/6502MCP.git
cd 6502MCP
swift build
swift test
```

## Claude Code setup (bash)

```bash
#!/usr/bin/env bash
set -euo pipefail

cd ~/Developer/6502MCP
claude mcp add --transport stdio 6502mcp -- swift run MCPServer
claude
```

## Codex setup (bash)

```bash
#!/usr/bin/env bash
set -euo pipefail

cd ~/Developer/6502MCP
codex mcp add 6502mcp -- swift run MCPServer
codex
```

## Build

```bash
swift build
```

## Run MCP server (stdio)

```bash
swift run MCPServer
```

The server speaks MCP JSON‑RPC over stdio using `Content-Length` framing and writes emulator logs to **stderr** so JSON stays on stdout.

### Example MCP client config (stdio)

- **Command**: `swift`
- **Args**: `run MCPServer`
- **Working directory**: `~/Developer/6502MCP`

### Included tools

- `assemble`: assemble 6502 source into object code and a listing.
- `assemble_and_load`: assemble, load into memory, and set the PC to the origin.
- `load`: load raw bytes into memory.
- `reset`: reset the emulator and memory map.
- `set_pc`: set the program counter.
- `run`: run a number of CPU steps.
- `read_memory`: read memory bytes.
- `write_memory`: write memory bytes.
- `get_registers`: inspect CPU registers and flags.

## Tests

```bash
swift test
```

## Example LLM prompts

Use these with any MCP‑enabled LLM after registering the server:

1. **Write + test**
   - “Write a 6502 program that adds two numbers at $00 and $01 and stores the sum at $02. Assemble it, run it for 20 steps, then read $00–$02 to verify the result.”

2. **Debug**
   - “Here’s my 6502 loop that should increment $10 ten times. It doesn’t. Assemble and run it, inspect registers and $10, explain what’s wrong, and fix the code.”

3. **Test harness**
   - “Create a 6502 routine to sum a 4‑byte array at $20–$23 into $30. Include a small test harness, assemble_and_load it, run, and verify the output with read_memory.”

4. **Trace an error**
   - “Assemble this code, step 30 instructions, then show PC, A, X, Y, and $00–$0F so I can see where it went off course.”
