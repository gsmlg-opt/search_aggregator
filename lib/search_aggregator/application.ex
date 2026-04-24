defmodule SearchAggregator.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SearchAggregatorWeb.Telemetry,
      {Task.Supervisor, name: SearchAggregator.TaskSupervisor},
      SearchAggregator.Settings,
      {DNSCluster, query: Application.get_env(:search_aggregator, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SearchAggregator.PubSub},
      SearchAggregatorWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SearchAggregator.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SearchAggregatorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
