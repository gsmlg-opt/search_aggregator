defmodule Scout.RabbitMQ do
  @moduledoc """
  RabbitMQ publisher helpers for Scout jobs, results, failures, and heartbeats.
  """

  alias AMQP.{Basic, Channel, Connection, Queue}
  alias Scout.Fetch.{Job, Result}
  alias Scout.Settings
  require Logger

  def enabled? do
    Settings.get()["rabbitmq"]["enabled"]
  end

  def publish_job(%Job{} = job) do
    publish(queue("jobs", job.region_hint), Job.to_map(job))
  end

  def publish_result(%Result{ok: true} = result) do
    publish(queue("results"), Result.to_map(result))
  end

  def publish_result(%Result{} = result) do
    publish(queue("failed"), Result.to_map(result))
  end

  def publish_heartbeat(payload) do
    publish(queue("heartbeat"), payload)
  end

  def open_channel do
    config = Settings.get()["rabbitmq"]
    Logger.info("[RabbitMQ] Opening connection to #{config["url"]}")

    with {:ok, connection} <- Connection.open(config["url"]),
         {:ok, channel} <- Channel.open(connection) do
      Logger.info("[RabbitMQ] Connection established and channel opened")
      declare_known_queues(channel)
      {:ok, connection, channel}
    end
  end

  defp publish(queue, payload) do
    config = Settings.get()["rabbitmq"]
    body = Jason.encode!(payload)

    with {:ok, connection} <- Connection.open(config["url"]),
         {:ok, channel} <- Channel.open(connection),
         {:ok, _} <- Queue.declare(channel, queue, durable: true),
         :ok <-
           Basic.publish(channel, "", queue, body,
             persistent: true,
             content_type: "application/json"
           ) do
      Channel.close(channel)
      Connection.close(connection)
      :ok
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, error}
    end
  end

  defp declare_known_queues(channel) do
    settings = Settings.get()["rabbitmq"]

    settings["queues"]
    |> Map.values()
    |> Kernel.++(Map.values(settings["regional_queues"]))
    |> Enum.each(&Queue.declare(channel, &1, durable: true))
  end

  defp queue(name, region_hint \\ nil)

  defp queue("jobs", region_hint) when is_binary(region_hint) do
    settings = Settings.get()["rabbitmq"]
    settings["regional_queues"][region_hint] || settings["queues"]["jobs"]
  end

  defp queue(name, _region_hint) do
    Settings.get()["rabbitmq"]["queues"][name]
  end
end
