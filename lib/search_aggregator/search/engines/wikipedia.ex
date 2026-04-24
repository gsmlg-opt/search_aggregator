defmodule SearchAggregator.Search.Engines.Wikipedia do
  @moduledoc false

  @behaviour SearchAggregator.Search.Engine

  alias SearchAggregator.Search.HTTP
  alias SearchAggregator.Search.Result

  @impl true
  def search(query, engine, settings) do
    params = [
      action: "opensearch",
      format: "json",
      limit: settings["search"]["result_limit"],
      search: query
    ]

    case HTTP.get_json(engine["base_url"], params: params, receive_timeout: engine["timeout_ms"]) do
      {:ok, %{status: 200, body: [_query, titles, descriptions, urls]}} ->
        results =
          titles
          |> Enum.with_index()
          |> Enum.map(fn {title, index} ->
            %Result{
              title: title,
              url: Enum.at(urls, index),
              content: Enum.at(descriptions, index),
              engine: engine["name"],
              source: "Wikipedia",
              score: 100 - index
            }
          end)

        {:ok, results}

      {:ok, %{status: status}} ->
        {:error, "unexpected response status #{status}"}

      {:error, reason} ->
        {:error, Exception.message(reason)}
    end
  end
end
