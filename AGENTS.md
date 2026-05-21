# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo shape

This is a polyglot monorepo (Go + TypeScript + Python) hosting the Zoea collaboration toolkit. It's not a single buildable project — each subdirectory is its own self-contained module with its own toolchain, run from its own working directory.

| Subdir | Language | Tooling | What it is |
|---|---|---|---|
| `zoea-server/` | Go (1.24+ / mod 1.25) | `go` | HTTP+WebSocket server bridging clients to `pi --mode rpc` agent subprocesses |
| `zoea-web-ui/` | TypeScript | `npm` + Vite | Browser chat UI (Lit + `@mariozechner/pi-web-ui`) backed by `zoea-server` |
| `gateway-tui-client/` | Go | `go` | Terminal UI client (Bubble Tea) for `zoea-server` |
| `zoea-tools/` | TypeScript | `npm` | Pi extension that discovers declarative tool manifests (`tools.toml`/`.json`/`.yaml`) and registers them as Pi custom tools |
| `zoea-core/` | Python (3.11+) | `uv` | Common Python interfaces for Zoea tools (`ZoeaContext`, output writers under `.zoea/output/<run-id>/`) |
| `zoea-deploy/` | Python | `uv` + pyinfra | Deploys server+web to exe.dev VMs via SSH/systemd/nginx |

The top-level `process-compose.yaml` is the local-dev orchestrator — see "Running everything together" below.

## Running everything together

The whole stack runs under [process-compose](https://github.com/F1bonacc1/process-compose). `process-compose.yaml.example` is the canonical reference; copy it to `process-compose.yaml` and edit, then:

```bash
process-compose
```

`ZOEA_LISTEN_ADDR` must be in `host:port` form — Go's `net.Listen` rejects bare ports. Use `:14300`, not `14300`. The example file uses the correct form.

Each `zoea-server-*` process gets isolated state via `ZOEA_STORE_DSN`, `ZOEA_PI_SESSION_DIR`, and `ZOEA_WORKING_DIR`, so you can run multiple instances in parallel for different projects.

## zoea-server (Go)

`cd zoea-server` first. Module: `github.com/unbracketed/zoea-server`.

```bash
go run ./cmd/server                # start (defaults to :7777)
go run ./cmd/server status         # local status subcommand
go test ./...                      # all tests
go test ./internal/api -run TestX  # single package / single test
go build ./cmd/server              # build binary
```

No config is needed for local dev — defaults bind `:7777` with auth disabled and grant full access from `127.0.0.1`/`::1`. With `AUTH_API_KEYS=app:sk_secret:scope` set, all non-health endpoints require `Authorization: Bearer sk_secret`.

Key env vars (full list in `zoea-server/docs/configuration.md`):
- `ZOEA_LISTEN_ADDR` — `:7777` by default; **must include the colon**
- `PI_BIN_PATH` / `PI_DEFAULT_ARGS` — path to `pi` binary and its default args (`--mode rpc`)
- `ZOEA_PI_SESSION_DIR` — where Pi's per-session JSONL transcripts live
- `ZOEA_WORKING_DIR` — when set, every Pi subprocess starts here and per-request `working_dir` is ignored
- `ZOEA_STORE_DSN` — SQLite path (default `./.zoea.db`); `:memory:` for tests

### Server architecture

The server is a thin shell around long-lived `pi --mode rpc` subprocesses. Each REST/WS request ultimately speaks JSONL to a Pi process.

```
HTTP/WS client
  → internal/api      (Routes, handlers, request validation)
  → internal/auth     (middleware: rate limit → API-key/JWT auth)
  → internal/session  (Manager: session lifecycle, ID assignment, persistence)
  → internal/process  (RPCProcessManager: spawns/owns pi subprocesses)
  → internal/rpc      (JSONL framing, command-id correlation, event mapping)
  → pi --mode rpc subprocess
       writes transcript JSONL into ZOEA_PI_SESSION_DIR/<user>/<session-id>/
```

`internal/store` (SQLite) stores **session metadata only** — `id`, `user_id`, `external_id`, `pi_pid`, timestamps. **Pi owns the transcript on disk** as the source of truth; the server does not mirror messages into SQLite (a legacy `session_messages` table exists but is no longer written to). On resume, the server respawns Pi with `--continue` so it loads its own JSONL.

`external_id` (e.g. `telegram:12345`) is the bridge integration key: unique per session, used by `GET /v1/sessions?external_id=…` and rejected with `409` on duplicates.

`internal/ws` streams Pi events (`agent.text.*`, `agent.thinking.*`, `agent.toolcall.*`, `agent.tool.start/end`, `agent.compaction.*`, `agent.retry.*`, `agent.message.error`, `agent.run.end`) to clients over WebSocket; `agent.run.end` is the only event that updates `last_active_at`.

`internal/gateway` exists for the cross-host gateway path (separate from the in-process flow above).

## zoea-web-ui (TypeScript / Vite)

`cd zoea-web-ui` first.

```bash
npm install
npm run dev           # Vite dev server
npm run build         # tsc --noEmit && vite build
npm run check         # type-check only
```

Vite proxies `/v1`, `/healthz`, `/readyz` to `VITE_ZOEA_DEV_PROXY_TARGET` (default `http://localhost:14004`). The production build is deployed as a same-origin app behind nginx, which proxies the API paths — there is no CORS path; if you change the dev proxy target, the prod nginx config must mirror it.

Built on `@mariozechner/pi-web-ui` (Lit components). `VITE_ZOEA_USER_ID` / `VITE_ZOEA_PROJECT_ID` seed the session-creation defaults.

## gateway-tui-client (Go)

`cd gateway-tui-client` first. Module: `github.com/brian/zoea-tui-client`.

```bash
go run ./cmd/tui                                          # connects to localhost:7777
go run ./cmd/tui --addr http://my-server:7777 --api-key X
ZOEA_ADDR=… ZOEA_API_KEY=… go run ./cmd/tui              # env-var equivalents
```

Bubble Tea app with two screens (session select / chat). Renders the same agent event types that `zoea-server` emits over WS.

## zoea-tools (Pi extension, TypeScript)

Loaded into Pi via `pi install ./zoea-tools` or `pi -e ./zoea-tools` (one-off). It scans default locations (`.zoea/tools.*`, `.pi/tools.*`, `~/.zoea/tools.*`, plus `ZOEA_TOOL_PATHS`) for tool manifests and registers each with `pi.registerTool()`.

```bash
npm run typecheck     # tsc --noEmit
```

Manifest format and the runtime contract (`ZOEA_SESSION_CWD`, kebab-case flags, repeatable inputs) are in `zoea-tools/README.md`. To debug a Pi session's tool discovery, run `/zoea-tools-status` inside Pi.

## zoea-core (Python)

`cd zoea-core` first.

```bash
uv sync
uv run pytest                                       # all tests
uv run pytest tests/test_output.py::test_x          # single test
```

Provides `create_zoea_context()` / `run_zoea_tool()` / `@zoea_tool` so Python tools write results and artifacts to a consistent layout under `.zoea/output/<run-id>/`. Config merges `~/.zoea/config.json` → `<project>/.zoea/config.json` → env vars (`ZOEA_PROJECT_DIR`, `ZOEA_OUTPUT_DIR`, `ZOEA_DATA_STORE_DIR`, `ZOEA_RUN_ID`, `ZOEA_SESSION_ID`).

`ZoeaContext` exposes `output`, `data_store`, `tools`, `workflow`, `tasks`, `scheduler`, `session`, `logger`. Only `output` is considered stable; the rest are starter contracts that may evolve.

## zoea-deploy (pyinfra)

`cd zoea-deploy` first.

```bash
uv sync
uv run pyinfra inventories/example.py deploy.py
uv run pyinfra inventories/production.py deploy.py --limit api.exe.xyz
ZOEA_DEPLOY_BUILD_SERVER=0 uv run pyinfra …    # skip Go build
ZOEA_DEPLOY_BUILD_WEB=0    uv run pyinfra …    # skip web build
```

`config.py` builds artifacts locally (`go build` for the server, `npm ci && npm run build` for the web UI) before pyinfra connects. Each host's `zoea_components` list (`["server"]`, `["web"]`, or both) selects what gets deployed. Web-only hosts must set `zoea_api_upstream` because nginx proxies `/v1` to a remote backend.

## Cross-cutting conventions

- Storage backend is pluggable in principle (`store.Open(driver, dsn)`), but only SQLite is implemented. Multi-instance deployments share state by sharing the SQLite file — there's no Postgres path yet, and SQLite's single-writer constraint applies.
- Session IDs are sequential (`s_000001`, `s_000002`, …). On startup the server seeds its counter from the highest existing ID in the store so restarts don't collide.
- Local dev: when running multiple `zoea-server` instances simultaneously (as the example process-compose config does), each must have its own `ZOEA_STORE_DSN` and `ZOEA_PI_SESSION_DIR` — they cannot share state.
- Pi processes do **not** auto-resurrect after a server restart. Clients must call the resume path; the server respawns Pi with `--continue` against the saved session-dir. The web UI does this automatically when a stored session is reopened.
