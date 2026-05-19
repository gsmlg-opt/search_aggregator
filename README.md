# Scout

Scout is a distributed Markdown fetch system for AI agents. It accepts URL fetch
jobs, dispatches them to Scout agents, renders pages with Lightpanda, and returns
Lightpanda's native Markdown output.

Scout is intentionally narrow: it does not index documents, persist fetched
content, generate embeddings, take screenshots, or manage RAG state.

## Architecture

Scout is an Elixir umbrella project:

- `apps/scout` - shared core: settings, fetch job/result structs, retry policy,
  URL security, Markdown helpers, and RabbitMQ helpers.
- `apps/scout_server` - server runtime: in-memory job lifecycle, dispatch,
  result handling, heartbeat handling, and the public `Scout.Server` API.
- `apps/scout_agent` - agent runtime: RabbitMQ job consumer, heartbeat publisher,
  NimblePool Lightpanda executor, and the public `Scout.Agent` API.
- `apps/scout_web` - Phoenix 1.8 web layer with the LiveView dashboard at `/`
  and JSON fetch API under `/api/fetch`.

The runtime flow is:

```text
URL -> Security.validate_url -> JobManager -> Dispatcher -> RabbitMQ
  -> Agent -> Lightpanda CLI -> Markdown result -> JobManager
```

Jobs and agent heartbeats are held in memory. Restarting the server clears the
dashboard state.

## Requirements

- Elixir 1.15 or newer with a compatible Erlang/OTP version
- Node/npm for web package imports
- RabbitMQ for real server/agent dispatch
- Lightpanda installed on agent hosts
- Bun and Tailwind binaries are managed through the project Mix tasks

## Setup

Install dependencies from the umbrella root:

```sh
mix setup
npm install --prefix apps/scout_web --omit=optional --ignore-scripts --no-audit --no-fund
```

Runtime settings are loaded from `settings.yaml` by default. Override the path
when running the server or agent:

```sh
SETTINGS_PATH=/absolute/path/to/settings.yaml mix phx.server
```

The default port is `6980`; override it with `PORT`.

## Run

Start the Phoenix API/dashboard and server runtime:

```sh
mix phx.server
```

Open:

- Dashboard: http://localhost:6980
- Fetch API: http://localhost:6980/api/fetch

For distributed fetches, run RabbitMQ, set `rabbitmq.enabled: true`, and run at
least one Scout agent with the same settings file. Use a unique `agent.id` or
set `SCOUT_AGENT_ID`; set `agent.lightpanda_path` if the binary is not named
`lightpanda`.

## API

Submit an async fetch job:

```sh
curl -X POST http://localhost:6980/api/fetch \
  -H 'content-type: application/json' \
  -d '{"url":"https://example.com/docs/page","region_hint":"eu","timeout_ms":30000}'
```

Check status:

```sh
curl http://localhost:6980/api/fetch/JOB_ID
```

Run a synchronous fetch and wait for the agent result:

```sh
curl -X POST http://localhost:6980/api/fetch/sync \
  -H 'content-type: application/json' \
  -d '{"url":"https://example.com/docs/page"}'
```

Accepted request fields include `url`, `timeout_ms`, `priority`, `region_hint`,
and `browser` options. URLs must use HTTP or HTTPS and must not target localhost
or blocked private CIDR ranges from `settings.yaml`.

## Configuration

`settings.yaml` controls:

- RabbitMQ URL, result queues, failed queue, heartbeat queue, and regional job
  queues
- Fetch defaults, max timeout, browser wait options, retry attempts, and backoff
- Agent identity, region, heartbeat interval, capacity, and Lightpanda path
- Allowed URL schemes, redirect limit, and SSRF blocklist

`Scout.Settings.reload!/0` reloads the YAML file in a running IEx session.

## Deployment

Scout builds separate OTP releases and Docker images:

- `ghcr.io/gsmlg-dev/scout-server:<tag>` - Phoenix API/dashboard plus
  `Scout.Server`
- `ghcr.io/gsmlg-dev/scout-agent:<tag>` - RabbitMQ consumer plus
  `Scout.Agent`

The server image exposes port `6980`. The agent image does not bundle
Lightpanda; provide the binary through a derived image, mounted file, or wrapper.

See [`docs/deploy.md`](docs/deploy.md) for Docker commands, runtime settings,
published image workflows, and E2E verification.

## Development

Run tests:

```sh
mix test
```

Run the handoff check:

```sh
mix precommit
```

`mix precommit` compiles with warnings as errors, checks unused dependencies,
formats the umbrella, and runs tests.
