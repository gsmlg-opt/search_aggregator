defmodule SearchAggregator.Search.Engines.HackerNews do
  @moduledoc false

  @behaviour SearchAggregator.Search.Engine

  alias SearchAggregator.Search.HTTP
  alias SearchAggregator.Search.Result

  @impl true
  def search(query, engine, settings) do
    params = [
      query: query,
      hitsPerPage: settings["search"]["result_limit"],
      tags: "story"
    ]

    case HTTP.get_json(engine["base_url"], params: params, receive_timeout: engine["timeout_ms"]) do
      {:ok, %{status: 200, body: %{"hits" => hits}}} ->
        results =
          hits
          |> Enum.with_index()
          |> Enum.map(fn {hit, index} ->
            %Result{
              title: hit["title"] || hit["story_title"] || "Untitled",
              url: hit["url"] || story_url(hit["objectID"]),
              content: hit["story_text"] || hit["comment_text"] || hit["author"],
              engine: engine["name"],
              source: "Hacker News",
              score: 100 - index,
              published_at: hit["created_at"]
            }
          end)

        {:ok, results}

      {:ok, %{status: status}} ->
        {:error, "unexpected response status #{status}"}

      {:error, reason} ->
        {:error, Exception.message(reason)}
    end
  end

  defp story_url(object_id), do: "https://news.ycombinator.com/item?id=#{object_id}"
end
