# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :search_aggregator,
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :search_aggregator_web, SearchAggregatorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: SearchAggregatorWeb.ErrorHTML, json: SearchAggregatorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SearchAggregator.PubSub,
  live_view: [signing_salt: "GhjRd1eC"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :search_aggregator, :settings_path, Path.expand("../settings.yaml", __DIR__)

config :bun,
  version: "1.3.4",
  path: System.get_env("MIX_BUN_PATH") || System.find_executable("bun"),
  search_aggregator_web: [
    args:
      ~w(build assets/js/app.js --outdir=priv/static/assets --external /fonts/* --external /images/*),
    cd: Path.expand("../apps/search_aggregator_web", __DIR__)
  ]

config :tailwind,
  version: "4.1.11",
  version_check: false,
  path:
    System.get_env("MIX_TAILWIND_PATH") ||
      Path.expand("../apps/search_aggregator_web/node_modules/.bin/tailwindcss", __DIR__),
  search_aggregator_web: [
    args: ~w(--input=assets/css/app.css --output=priv/static/assets/app.css),
    cd: Path.expand("../apps/search_aggregator_web", __DIR__)
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
