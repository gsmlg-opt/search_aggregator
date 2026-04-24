defmodule SearchAggregator.Search do
  @moduledoc """
  Parallel metasearch orchestrator with SearXNG-style graceful degradation.
  """

  alias SearchAggregator.Search.Result
  alias SearchAggregator.Settings

  @engines %{
    "wikipedia" => SearchAggregator.Search.Engines.Wikipedia,
    "hacker_news" => SearchAggregator.Search.Engines.HackerNews,
    "stack_overflow" => SearchAggregator.Search.Engines.StackOverflow
  }

  def start(query, recipient \\ self(), opts \\ []) when is_binary(query) do
    settings = Settings.get()
    search_ref = make_ref()
    opts = normalize_options(opts, settings)

    enabled_engines = enabled_engines(settings, opts)

    Enum.each(enabled_engines, fn engine ->
      Task.Supervisor.start_child(SearchAggregator.TaskSupervisor, fn ->
        result = run_engine(engine, query, settings, opts)
        send(recipient, {:search_engine_result, search_ref, result})
      end)
    end)

    %{ref: search_ref, total: length(enabled_engines), settings: settings, opts: opts}
  end

  def search(query, opts \\ []) when is_binary(query) do
    settings = Settings.get()
    opts = normalize_options(opts, settings)

    {duration_ms, reports} =
      :timer.tc(
        fn ->
          settings
          |> enabled_engines(opts)
          |> Enum.map(&run_engine(&1, query, settings, opts))
        end,
        :millisecond
      )

    results =
      reports
      |> Enum.flat_map(& &1.results)
      |> merge_results([], opts["limit"])

    %{
      query: query,
      category: opts["category"],
      opts: opts,
      results: results,
      engine_reports: reports,
      settings: settings,
      total_results: length(results),
      duration_ms: duration_ms
    }
  end

  def enabled_engines(settings, opts \\ %{}) do
    allowed_engine_names = Map.get(opts, "engine_names", MapSet.new())
    category = Map.get(opts, "category", settings["ui"]["default_category"])
    categories = mapped_categories(settings, category)

    settings["engines"]
    |> Enum.reject(& &1["disabled"])
    |> Enum.filter(&Map.has_key?(@engines, &1["engine"]))
    |> Enum.filter(fn engine ->
      category == "all" or Enum.any?(List.wrap(engine["categories"]), &(&1 in categories))
    end)
    |> Enum.filter(fn engine ->
      MapSet.size(allowed_engine_names) == 0 or
        MapSet.member?(allowed_engine_names, engine["name"])
    end)
  end

  def normalize_options(opts, settings) when is_list(opts) do
    opts
    |> Enum.into(%{})
    |> normalize_options(settings)
  end

  def normalize_options(opts, settings) when is_map(opts) do
    %{
      "category" => normalize_category(opts["category"] || opts[:category], settings),
      "limit" => normalize_limit(opts["limit"] || opts[:limit], settings),
      "engine_names" =>
        normalize_engine_names(
          opts["engine_names"] || opts[:engine_names] || opts["engines"] || opts[:engines]
        ),
      "language" => opts["language"] || opts[:language] || settings["general"]["default_locale"]
    }
  end

  def merge_results(results, new_results, limit) do
    results
    |> Enum.concat(new_results)
    |> Enum.reduce(%{}, fn result, acc ->
      key = normalize_url(result.url)

      Map.update(acc, key, result, fn existing ->
        merge_duplicate(existing, result)
      end)
    end)
    |> Map.values()
    |> Enum.sort_by(&{-(&1.score || 0), &1.title})
    |> Enum.take(limit)
  end

  def run_engine(engine, query, settings, opts \\ %{}) do
    module = Map.fetch!(@engines, engine["engine"])

    started_at = System.monotonic_time(:millisecond)

    payload =
      case dispatch_engine(module, query, engine, settings, opts) do
        {:ok, results} ->
          %{
            engine: engine["name"],
            mode: engine["mode"],
            ok?: true,
            results: results,
            error: nil
          }

        {:error, reason} ->
          %{
            engine: engine["name"],
            mode: engine["mode"],
            ok?: false,
            results: [],
            error: inspect(reason)
          }
      end

    Map.put(payload, :duration_ms, System.monotonic_time(:millisecond) - started_at)
  end

  def serialize_result(%Result{} = result) do
    %{
      title: result.title,
      url: result.url,
      content: result.content,
      engine: result.engine,
      source: result.source,
      score: result.score,
      published_at: result.published_at
    }
  end

  defp dispatch_engine(module, query, engine, settings, opts) do
    case engine["mode"] do
      "browser" ->
        SearchAggregator.Search.BrowserSimulator.search(module, query, engine, settings, opts)

      _ ->
        module.search(query, engine, Map.put(settings, "__request__", opts))
    end
  end

  defp merge_duplicate(left, right) do
    merged_sources =
      [left.engine | List.wrap(right.engine)]
      |> Enum.uniq()
      |> Enum.join(", ")

    %Result{
      left
      | title: pick_longer(left.title, right.title),
        content: pick_longer(left.content, right.content),
        engine: merged_sources,
        score: (left.score || 0) + (right.score || 0) + 25
    }
  end

  defp normalize_url(url) do
    url
    |> URI.parse()
    |> Map.take([:scheme, :host, :path])
    |> then(fn %{scheme: scheme, host: host, path: path} ->
      "#{scheme}://#{String.downcase(host || "")}#{path || "/"}"
    end)
  end

  defp pick_longer(nil, value), do: value
  defp pick_longer(value, nil), do: value
  defp pick_longer(left, right) when byte_size(left) >= byte_size(right), do: left
  defp pick_longer(_left, right), do: right

  defp normalize_category(nil, settings), do: settings["ui"]["default_category"]
  defp normalize_category("", settings), do: settings["ui"]["default_category"]
  defp normalize_category(category, _settings), do: to_string(category)

  defp normalize_limit(nil, settings), do: settings["search"]["result_limit"]
  defp normalize_limit("", settings), do: settings["search"]["result_limit"]

  defp normalize_limit(limit, settings) when is_binary(limit) do
    case Integer.parse(limit) do
      {value, ""} -> normalize_limit(value, settings)
      _ -> settings["search"]["result_limit"]
    end
  end

  defp normalize_limit(limit, settings) when is_integer(limit) do
    limit
    |> max(1)
    |> min(settings["search"]["max_limit"])
  end

  defp normalize_engine_names(nil), do: MapSet.new()
  defp normalize_engine_names(""), do: MapSet.new()

  defp normalize_engine_names(names) when is_binary(names) do
    names
    |> String.split(",", trim: true)
    |> normalize_engine_names()
  end

  defp normalize_engine_names(names) when is_list(names) do
    names
    |> Enum.map(&to_string/1)
    |> MapSet.new()
  end

  defp normalize_engine_names(%MapSet{} = names), do: names

  defp mapped_categories(settings, category) do
    settings["ui"]["categories_as_tabs"][category] || [category]
  end
end
