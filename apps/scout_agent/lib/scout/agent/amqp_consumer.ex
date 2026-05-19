defmodule Scout.Agent.AMQPConsumer do
  @moduledoc """
  RabbitMQ consumer for Scout Agent mode.
  """

  use GenServer
  require Logger

  alias AMQP.Basic
  alias Scout.Agent
  alias Scout.Fetch.{Job, Result}
  alias Scout.RabbitMQ
  alias Scout.Settings

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    settings = Settings.get()
    rabbitmq = settings["rabbitmq"]
    agent = settings["agent"]

    with {:ok, connection, channel} <- RabbitMQ.open_channel() do
      Logger.info("[Agent] Connected to RabbitMQ at #{rabbitmq["url"]}")

      # Always consume from global jobs queue
      global_queue = rabbitmq["queues"]["jobs"]
      {:ok, _} = Basic.consume(channel, global_queue, nil, no_ack: false)
      Logger.info("[Agent] Consuming from global queue: #{global_queue}")

      # Optionally consume from regional queue if configured and different from global
      regional_queue = rabbitmq["regional_queues"][agent["region"]]

      if regional_queue && regional_queue != global_queue do
        {:ok, _} = Basic.consume(channel, regional_queue, nil, no_ack: false)
        Logger.info("[Agent] Consuming from regional queue: #{regional_queue}")
      end

      {:ok, %{connection: connection, channel: channel}}
    else
      {:error, reason} ->
        Logger.error("[Agent] Failed to connect to RabbitMQ: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_info({:basic_deliver, payload, meta}, state) do
    result =
      with {:ok, map} <- Jason.decode(payload),
           {:ok, job} <- Job.from_map(map) do
        Logger.info("[Agent] Starting fetch for URL: #{job.url} (job_id: #{job.job_id})")
        Agent.fetch(job)
      else
        error ->
          Logger.error("[Agent] Failed to decode job payload: #{inspect(error)}")

          %Result{
            job_id: nil,
            ok: false,
            url: nil,
            error: %{type: "invalid_job", message: inspect(error), retryable: false}
          }
      end

    Logger.info("[Agent] Job completed (ok: #{result.ok}), publishing result")
    _ = RabbitMQ.publish_result(result)
    Basic.ack(state.channel, meta.delivery_tag)
    {:noreply, state}
  end

  def handle_info({:basic_consume_ok, _meta}, state), do: {:noreply, state}
  def handle_info({:basic_cancel, _meta}, state), do: {:stop, :normal, state}
  def handle_info({:basic_cancel_ok, _meta}, state), do: {:noreply, state}
end
