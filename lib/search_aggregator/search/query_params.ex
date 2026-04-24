defmodule SearchAggregator.Search.QueryParams do
  @moduledoc false

  alias SearchAggregator.Search
  alias SearchAggregator.Settings

  def parse(params, settings \\ Settings.get()) do
    query = params["q"] |> to_string_safe() |> String.trim()

    opts =
      Search.normalize_options(
        %{
          "category" => params["category"] || params["categories"],
          "limit" => params["limit"] || params["count"],
          "engines" => params["engines"],
          "language" => params["language"]
        },
        settings
      )

    %{query: query, opts: opts}
  end

  def to_query_params(query, opts, settings \\ Settings.get()) do
    category = opts["category"] || settings["ui"]["default_category"]
    limit = opts["limit"] || settings["search"]["result_limit"]

    %{}
    |> maybe_put("q", query)
    |> maybe_put("category", unless_default(category, settings["ui"]["default_category"]))
    |> maybe_put("limit", unless_default(limit, settings["search"]["result_limit"]))
    |> maybe_put("engines", encode_engines(opts["engine_names"]))
    |> maybe_put("language", unless_default(opts["language"], settings["general"]["default_locale"]))
  end

  defp encode_engines(names) do
    if MapSet.size(names || MapSet.new()) == 0 do
      nil
    else
      names
      |> Enum.sort()
      |> Enum.join(",")
    end
  end

  defp unless_default(value, default) when value == default, do: nil
  defp unless_default(value, _default), do: value

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp to_string_safe(nil), do: ""
  defp to_string_safe(value), do: to_string(value)
end
