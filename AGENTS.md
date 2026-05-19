# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- **Setup Dependencies:** `mix setup`
- **Start Development Server:** `mix phx.server` (or `iex -S mix phx.server` for an interactive shell)
- **Run All Tests:** `mix test`
- **Run a Specific Test:** `mix test path/to/file_test.exs` or `mix test path/to/file_test.exs:123` (to run a specific line)
- **Pre-commit Check (Compile, Format, Test):** `mix precommit` (Use this alias when you are done with all changes to catch warnings and run tests)
- Default port is **6980** (override with `PORT`). Settings path overridable with `SETTINGS_PATH`.

## Architecture

Scout is an **Elixir umbrella project** — a distributed Markdown fetch system for AI agents. It accepts URL fetch jobs, dispatches them to agents, renders pages with Lightpanda, and returns Lightpanda's native Markdown output. Scout does not index, persist documents, or generate embeddings.

### Umbrella Apps

- **`apps/scout`** — Shared core: settings (YAML GenServer), job/result structs, retry policy, URL security, Markdown helpers, and RabbitMQ helpers.
- **`apps/scout_server`** — Server runtime: job lifecycle, agent registry, RabbitMQ dispatch, result consumers, heartbeat consumers, and public `Scout.Server` API.
- **`apps/scout_agent`** — Agent runtime: RabbitMQ job consumer, heartbeat publisher, NimblePool Lightpanda executor, and public `Scout.Agent` API.
- **`apps/scout_web`** — Phoenix 1.8 web layer: LiveView dashboard at `/`, JSON API at `/api/fetch`.

### Core Pipeline

```
URL → Security.validate_url → Job.new → Dispatcher.dispatch
  → Executor.fetch (Lightpanda CLI) → Result.success/failure
  → ResultHandler → JobManager (in-memory lifecycle)
```

Dispatch is RabbitMQ-based. `Scout.Server` publishes jobs, consumes agent results and heartbeats, and never runs Lightpanda directly. `Scout.Agent` consumes jobs, serializes fetches through a single-worker NimblePool, and publishes results and heartbeats.

### Key Modules

- **`Scout`** — Shared core namespace. Use `Scout.Server` and `Scout.Agent` for runtime APIs.
- **`Scout.Server`** — Public server API: `submit_fetch/1`, `get_fetch/1`, `list_fetches/0`, `fetch_sync/1`, `list_agents/0`.
- **`Scout.Agent`** — Public agent API: `fetch/1` and `status/0`.
- **`Scout.Settings`** — GenServer loading `settings.yaml` at startup, merged with defaults. Call `Settings.get/0`; `Settings.reload!/0` for hot reload.
- **`Scout.Server.JobManager`** — GenServer tracking job lifecycle in-memory (queued → running → completed/failed/retrying). Handles retry scheduling via `Process.send_after`.
- **`Scout.Server.Dispatcher`** — Publishes jobs to RabbitMQ through `Scout.RabbitMQ`.
- **`Scout.Agent.Executor`** — Runs a single fetch through `Scout.Agent.LightpandaPool`, builds `Result` structs.
- **`Scout.Agent.Lightpanda`** — Behaviour (`@callback fetch/2`) with pluggable adapter. Default adapter: `Scout.Agent.Lightpanda.CLI` which shells out to the `lightpanda` binary.
- **`Scout.Agent.Heartbeat`** — Periodic GenServer broadcasting agent status to `AgentRegistry` and optionally RabbitMQ.
- **`Scout.Server.AgentRegistry`** — In-memory registry of recent agent heartbeats, broadcast via PubSub.
- **`Scout.RabbitMQ`** — Queue declaration and publish helpers using the `amqp` library.
- **`Scout.Fetch.Job`** — Job struct with URL validation, `new/1`, `retry/1`.
- **`Scout.Fetch.Result`** — Result struct with `success/2`, `failure/3` constructors.
- **`Scout.Fetch.RetryPolicy`** — Classifies retryable errors (timeout, 429, 502, 503, browser_crash) and computes exponential backoff with jitter.
- **`Scout.Security`** — SSRF protection: validates schemes (http/https only), blocks localhost and private network CIDRs.
- **`Scout.Markdown`** — Extracts title from `# heading` and counts words from Markdown text.

### Supervision Tree (scout app)

```
Scout.Supervisor (one_for_one)
  ├── Scout.Settings (GenServer)

Scout.Server.Supervisor (one_for_one)
  ├── Phoenix.PubSub (Scout.PubSub)
  ├── Scout.Server.AgentRegistry (GenServer)
  ├── Scout.Server.JobManager (GenServer)
  ├── Scout.Server.ResultConsumer (when rabbitmq.enabled)
  └── Scout.Server.HeartbeatConsumer (when rabbitmq.enabled)

Scout.Agent.Supervisor (one_for_one)
  ├── Scout.Agent.LightpandaPool (NimblePool, size 1)
  ├── Scout.Agent.Heartbeat (GenServer)
  └── Scout.Agent.AMQPConsumer (when rabbitmq.enabled)
```

### Web Layer (scout_web app)

- **`ScoutWeb.Router`** — `/` → `DashboardLive`, `POST /api/fetch` → create, `GET /api/fetch/:job_id` → show, `POST /api/fetch/sync` → sync.
- **`ScoutWeb.DashboardLive`** — LiveView subscribing to `scout:jobs` and `scout:agents` PubSub topics. Shows job list, agent list, and a submit form.
- **`ScoutWeb.FetchController`** — JSON API controller.
- **`ScoutWeb.Layouts`** — App layout using `phoenix_duskmoon` components (`dm_appbar`, `dm_flash_group`, `dm_theme_switcher`).

## Project Guidelines

### UI Library

This project uses the DuskMoon UI system:

- **`phoenix_duskmoon`** — Phoenix LiveView UI component library (primary web UI)
- **`@duskmoon-dev/core`** — Core Tailwind CSS plugin and utilities

Do NOT use DaisyUI or other CSS component libraries. Do NOT use `core_components.ex` — use `phoenix_duskmoon` components instead.
Use `@duskmoon-dev/core/plugin` as the Tailwind CSS plugin.

### Reporting issues or feature requests

If you encounter missing features, bugs, or need functionality not yet available in any DuskMoon package, open a GitHub issue in the appropriate repository with the label `internal request`:

- **`phoenix_duskmoon`** — https://github.com/gsmlg-dev/phoenix_duskmoon/issues
- **`@duskmoon-dev/core`** — https://github.com/gsmlg-dev/duskmoon-dev/issues

### Elixir Best Practices
- **HTTP Client:** Use the included `Req` library for HTTP requests. **Avoid** `:httpoison`, `:tesla`, and `:httpc`.
- **List Access:** Do not use index-based access syntax on lists (e.g., `mylist[i]` is invalid). Always use `Enum.at(mylist, i)`.
- **Variable Binding:** Elixir variables are immutable. For block expressions (`if`, `case`, `cond`), you must bind the *result* of the expression to a variable rather than rebinding inside the block.

### Phoenix v1.8 Conventions
- **LiveView Layouts:** Always begin LiveView templates with `<Layouts.app flash={@flash} ...>` to wrap all inner content.
- **Current Scope Assign:** If you see `current_scope` assign errors, move the routes to the proper `live_session` and pass `current_scope`.
- **Flash Messages:** Use DuskMoon flash components through `Layouts`; do not call legacy `<.flash_group>`.
- **UI Components:** Use `phoenix_duskmoon` components and helpers. Do not reintroduce `core_components.ex`.
