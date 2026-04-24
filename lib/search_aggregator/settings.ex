defmodule SearchAggregator.Settings do
  @moduledoc """
  Runtime loader for the SearXNG-style `settings.yaml` file.
  """

  use GenServer

  @default_settings %{
    "general" => %{
      "instance_name" => "SearchAggregator",
      "default_locale" => "en-US",
      "request_timeout_ms" => 5_000,
      "contact_url" => false
    },
    "search" => %{
      "result_limit" => 20,
      "max_limit" => 50,
      "autocomplete" => "off",
      "safe_search" => 0
    },
    "ui" => %{
      "theme" => "dawn",
      "default_category" => "general",
      "categories_as_tabs" => %{
        "general" => ["general"],
        "tech" => ["general", "tech"]
      }
    },
    "browser_simulator" => %{
      "enabled" => false,
      "pool_size" => 2,
      "export_path" => nil
    },
    "engines" => []
  }

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get do
    GenServer.call(__MODULE__, :get)
  end

  def reload! do
    GenServer.call(__MODULE__, :reload)
  end

  def settings_path do
    Application.fetch_env!(:search_aggregator, :settings_path)
  end

  @impl true
  def init(_state) do
    {:ok, load_settings!()}
  end

  @impl true
  def handle_call(:get, _from, state), do: {:reply, state, state}

  @impl true
  def handle_call(:reload, _from, _state) do
    state = load_settings!()
    {:reply, state, state}
  end

  def load_file!(path) do
    path
    |> YamlElixir.read_from_file!()
    |> normalize()
  end

  defp load_settings! do
    settings_path()
    |> load_file!()
    |> Map.put("__meta__", %{"path" => settings_path()})
  end

  defp normalize(raw) when is_map(raw) do
    raw
    |> deep_stringify_keys()
    |> then(&deep_merge(@default_settings, &1))
    |> normalize_engines()
  end

  defp normalize(_), do: raise(ArgumentError, "settings.yaml must contain a top-level map")

  defp normalize_engines(settings) do
    engines =
      settings
      |> Map.fetch!("engines")
      |> Enum.map(fn engine ->
        engine
        |> Map.put_new("name", engine["engine"])
        |> Map.put_new("mode", "http")
        |> Map.put_new("timeout_ms", settings["general"]["request_timeout_ms"])
        |> Map.put_new("categories", ["general"])
        |> Map.put_new("disabled", false)
      end)

    Map.put(settings, "engines", engines)
  end

  defp deep_stringify_keys(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      {to_string(key), deep_stringify_keys(nested_value)}
    end)
  end

  defp deep_stringify_keys(value) when is_list(value), do: Enum.map(value, &deep_stringify_keys/1)
  defp deep_stringify_keys(value), do: value

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_value, right_value ->
      deep_merge(left_value, right_value)
    end)
  end

  defp deep_merge(_left, right), do: right
end
