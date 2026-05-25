# Deployment

Scout deploys as two OTP releases backed by RabbitMQ:

- `ghcr.io/gsmlg-dev/scout-server:<tag>` runs the Phoenix API/dashboard and `Scout.Server`.
- `ghcr.io/gsmlg-dev/scout-agent:<tag>` consumes jobs and runs `Scout.Agent`.

The server never runs Lightpanda directly. It dispatches jobs through RabbitMQ, and agents fetch pages with Lightpanda and publish results back to the server.

## Build Images

Use the Docker build workflow for published images:

```sh
gh workflow run docker-build.yml \
  --ref main \
  -f git_ref=main \
  -f docker_image_tag=latest
```

The workflow also runs on pushes to `main` and when a GitHub release is
published. Every Docker workflow run publishes `latest`; release and manual runs
also publish the requested version tag. To build locally:

```sh
docker build -f Dockerfile.server -t ghcr.io/gsmlg-dev/scout-server:TAG .
docker build -f Dockerfile.agent -t ghcr.io/gsmlg-dev/scout-agent:TAG .
```

## Runtime Configuration

Mount the same settings file into the server and all agents, and set `SETTINGS_PATH` to that path. Enable RabbitMQ for distributed dispatch:

```yaml
rabbitmq:
  enabled: true
  url: amqp://scout:change-me@rabbitmq:5672
  queues:
    jobs: scout.fetch.jobs
    results: scout.fetch.results
    failed: scout.fetch.failed
    heartbeat: scout.agent.heartbeat

agent:
  id: agent-us-1
  region: us
  lightpanda_path: lightpanda
```

Use a unique `agent.id` per running agent. Set `agent.lightpanda_path` to the Lightpanda executable or wrapper available inside the agent container.

## Run With Docker

Create a shared Docker network and start RabbitMQ:

```sh
docker network create scout
docker run -d --name rabbitmq --network scout \
  -e RABBITMQ_DEFAULT_USER=scout \
  -e RABBITMQ_DEFAULT_PASS='change-me' \
  rabbitmq:3-alpine
```

Start the server:

```sh
docker run -d --name scout-server --network scout -p 6980:6980 \
  -e PHX_SERVER=true \
  -e PHX_HOST=scout.example.com \
  -e PORT=6980 \
  -e SECRET_KEY_BASE="$(openssl rand -hex 64)" \
  -e SETTINGS_PATH=/app/settings.yaml \
  -v "$PWD/settings.prod.yaml:/app/settings.yaml:ro" \
  ghcr.io/gsmlg-dev/scout-server:TAG
```

Start an agent:

```sh
docker run -d --name scout-agent-us-1 --network scout \
  -e SETTINGS_PATH=/app/settings.yaml \
  -v "$PWD/settings.prod.yaml:/app/settings.yaml:ro" \
  ghcr.io/gsmlg-dev/scout-agent:TAG
```

The agent image does not bundle Lightpanda. Provide it by building a derived image, mounting a binary, or using a controlled wrapper. Avoid mounting the Docker socket in production unless the host is dedicated to this workload.

## Verify Deployment

Check the server:

```sh
curl http://localhost:6980/
```

Run a synchronous fetch through RabbitMQ and an agent:

```sh
curl -X POST http://localhost:6980/api/fetch/sync \
  -H 'content-type: application/json' \
  -d '{"url":"https://example.com"}'
```

For published images, run the manual E2E workflow:

```sh
gh workflow run e2e.yml \
  --ref main \
  -f git_ref=main \
  -f docker_image_tag=TAG
```

## Security Notes

Do not expose RabbitMQ publicly. Use strong credentials, private networking, and TLS where appropriate. Keep the SSRF protections in `security.blocked_cidrs` enabled unless a reviewed change and tests justify otherwise.
