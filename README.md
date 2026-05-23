# Zoea Collaboration Toolkit

A custom agent harness built on Pi with goals of providing a light framework for building virtual assistants, agentic workflows, and domain-specific automations. 

**zoea-server**: HTTP/WebSocket server that bridges clients to `pi --mode rpc` agent subprocesses. Create sessions, send prompts, stream events — all over a REST API.

**zoea-web-ui**: A minimal browser chat UI backed by `zoea-server`

**zoea-tools**: Pi package that discovers declarative tool manifests and registers them as custom tools.

**zoea-core**: Common Python interfaces and utilities for Zoea tools, starting with consistent result/artifact output under `.zoea/output`.

**gateway-tui-client**: A terminal UI client for [zoea-server](../zoea-server). Connect to a running server instance, create or load sessions, send messages, and stream responses in real-time.

The Web UI can connect to either local or remote Zoea servers and switch between multiple connections. 

## Getting Started

This repo is the installer/workspace for the Zoea stack. Each component lives in its own GitHub repo under `unbracketed/`; `scripts/install.sh` clones them as siblings and runs per-repo bootstrap (`go mod download`, `npm install`, `uv sync`, `pi install`).

```sh
git clone https://github.com/unbracketed/zoea.git Zoea
cd Zoea
./scripts/install.sh
cp process-compose.yaml.example process-compose.yaml
# edit process-compose.yaml — point ZOEA_WORKING_DIR, ZOEA_STORE_DSN, etc. at your project
process-compose
```

Web UI listens on `14314` by default; the server on whatever `ZOEA_LISTEN_ADDR` you set in `process-compose.yaml` (the example uses `:14300`).

### Managing the child repos

All scripts operate on every Zoea repo that's been cloned into this workspace. Repos not present yet are skipped.

| Script | Purpose |
|---|---|
| `scripts/install.sh` | Clone any missing repos, `git pull --ff-only` the rest, then run per-repo bootstrap. Pass `--no-bootstrap` to skip dependency installs. |
| `scripts/update.sh` | `git pull --ff-only` each repo. Skips dirty trees and detached HEADs. |
| `scripts/status.sh` | One-line-per-repo summary: branch, dirty flag, ahead/behind vs upstream. |
| `scripts/foreach.sh "<cmd>"` | Run an arbitrary shell command inside each child repo. E.g. `scripts/foreach.sh "git fetch"`. |

The repo list is a plain bash array at the top of `scripts/install.sh`. Tracks `main` for every repo — no version pinning.

### Using zoea-tools in your project

After the stack is running, register the tools package with Pi in your project working directory:

```sh
pi install -l /path/to/Zoea/zoea-tools
```

## Architecture

To Do: diagram showing Pi agent, core, tools, connectors


**HTTP Gateway** - make Pi available on any server
**Web UI** - a capable, minimal web client purpose-built for the Zoea architecture
**Core** - common interfaces for storage, organizing and orchestrating work; scheduled jobs and workflows
**Channels** - Control agents via Slack, Email, Discord
**Capability System** - skills with extra protocols and metadata
**Memory** - knowledge base, temporal reasoning, connect facts
**Peer Collaboration** - users connect to multiple / external agents; A2A (agent to agent) support, mobile / offline / off-grid collaboration
**Evolution** - continual refinement of available capabilities and quality of memory system through analysis and feedback loops